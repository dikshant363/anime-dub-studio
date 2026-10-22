import Testing
import Foundation
@testable import AnimeDubCore

final class TestTimingTracker: @unchecked Sendable {
    private let lock = NSLock()
    var stageTimings: [(stage: String, timestamp: Date, message: String)] = []

    func add(stage: String, message: String) {
        lock.lock()
        defer { lock.unlock() }
        stageTimings.append((stage: stage, timestamp: Date(), message: message))
    }

    func getTimings() -> [(stage: String, timestamp: Date, message: String)] {
        lock.lock()
        defer { lock.unlock() }
        return stageTimings
    }
}

@Suite("Full Episode Real Video Dubbing Tests")
struct FullMetalPanicDubTests {
    @Test("Test Full Metal Panic S01E01 Dubbing Pipeline End-to-End")
    func testFullMetalPanicDub() async throws {
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Full Metal Panic - S01E01 [1080p x265] [Dual].mkv").path
        let fmpVideoPath = ProcessInfo.processInfo.environment["FMP_TEST_VIDEO_PATH"] ?? defaultPath
        let sourceVideoURL = URL(fileURLWithPath: fmpVideoPath)

        guard FileManager.default.fileExists(atPath: sourceVideoURL.path) else {
            print("Skipping full episode dub test: Media not present at \(fmpVideoPath). Set FMP_TEST_VIDEO_PATH to run.")
            return
        }

        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: sourceVideoURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        print("\n========================================================")
        print(" STARTING REAL VIDEO DUBBING TEST: Full Metal Panic S01E01")
        print(" Video: \(sourceVideoURL.lastPathComponent)")
        print(" Size: \(sizeBytes) bytes (\(String(format: "%.2f", Double(sizeBytes) / 1_000_000)) MB)")
        print("========================================================\n")

        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("FMP_Dub_\(UUID().uuidString)")
        let store = ProjectStore(baseDirectory: tempBase)
        let orchestrator = JobOrchestrator(projectStore: store)

        let project = Project(
            name: "Full Metal Panic Dubbing Project",
            sourceMediaPath: sourceVideoURL.path
        )
        let episode = Episode(
            projectId: project.id,
            title: "Full Metal Panic - S01E01",
            sourceMediaPath: sourceVideoURL.path
        )

        // Select Stream 2 (Japanese Opus track)
        let options = DubOptions(
            sourceLanguage: "ja",
            targetLanguage: .hinglish,
            selectedAudioStreamIndex: 2,
            hinglishMixing: .medium,
            translationStyle: .naturalAnime,
            voiceMode: .macNative,
            preserveBackgroundAudio: true,
            normalizeLoudness: true
        )

        let startTime = Date()
        let tracker = TestTimingTracker()

        let (outputVideoURL, qaReport) = try await orchestrator.run(
            project: project,
            episode: episode,
            options: options
        ) { state in
            let msg = state.logs.last?.message ?? state.stage.displayName
            print(String(format: "[%5.1f%%] Stage %-15@: %@", state.progress, state.stage.rawValue, msg))
            tracker.add(stage: state.stage.rawValue, message: msg)
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        print("\n========================================================")
        print(" DUBBING PIPELINE COMPLETE")
        print(String(format: " Total Pipeline Elapsed Time: %.2f seconds", totalDuration))
        print(" Output Video URL: \(outputVideoURL.path)")
        print(" QA Score: \(qaReport.score)%")
        print(" QA Warnings: \(qaReport.warnings)")
        print("========================================================\n")

        #expect(FileManager.default.fileExists(atPath: outputVideoURL.path))
        #expect(qaReport.score >= 75.0)

        // Check attributes of output file
        let attr = try FileManager.default.attributesOfItem(atPath: outputVideoURL.path)
        let fileSize = (attr[.size] as? NSNumber)?.int64Value ?? 0
        print(" Output File Size: \(fileSize) bytes (\(String(format: "%.2f", Double(fileSize) / 1_000_000)) MB)")
        #expect(fileSize > 50_000_000, "Dubbed video file size should be > 50 MB for full episode")

        // Verify with ffprobe
        let probeResult = try await ProcessRunner.run(executable: "ffprobe", arguments: [
            "-v", "error",
            "-show_entries", "stream=index,codec_type,codec_name:format=duration",
            "-of", "json",
            outputVideoURL.path
        ])
        #expect(probeResult.isSuccess)
        print("FFprobe Verification:\n\(probeResult.stdout)")
        #expect(probeResult.stdout.contains("hevc"))
        #expect(probeResult.stdout.contains("aac"))

        // Also copy deliverables to storage/ directory for convenient access
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let storageDir = repoRoot.appendingPathComponent("storage")
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)

        let destVideoURL = storageDir.appendingPathComponent("Full Metal Panic - S01E01 [Hinglish Dub].mp4")
        try? FileManager.default.removeItem(at: destVideoURL)
        try? FileManager.default.copyItem(at: outputVideoURL, to: destVideoURL)
        print(" Deliverable saved to: \(destVideoURL.path)")

        // Verify subtitles exist
        let srtURL = tempBase.appendingPathComponent("Projects/\(project.id)/Episodes/\(episode.id)/subtitles/episode_hinglish.srt")
        if FileManager.default.fileExists(atPath: srtURL.path) {
            let destSrt = storageDir.appendingPathComponent("Full Metal Panic - S01E01 [Hinglish].srt")
            try? FileManager.default.removeItem(at: destSrt)
            try? FileManager.default.copyItem(at: srtURL, to: destSrt)
            print(" Subtitles saved to: \(destSrt.path)")
        }

        // Clean up temporary workspace
        try? FileManager.default.removeItem(at: tempBase)
    }
}
