import Testing
import Foundation
@testable import AnimeDubCore

final class ProgressBox: @unchecked Sendable {
    var lastProgress: Double = 0.0
}

@Suite("Pipeline Integration Tests")
struct PipelineIntegrationTests {
    @Test("End-to-End Dubbing Pipeline on Sample Media")
    func testEndToEndDubbing() async throws {
        let rootDir: URL
        if #filePath.hasPrefix("/") {
            rootDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        } else {
            rootDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
        let sampleVideoURL = rootDir.appendingPathComponent("tests/test_data/sample.mp4")
        guard FileManager.default.fileExists(atPath: sampleVideoURL.path) else {
            return
        }

        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProjectStore(baseDirectory: tempBase)
        let orchestrator = JobOrchestrator(projectStore: store)

        let project = Project(
            name: "Integration Test Project",
            sourceMediaPath: sampleVideoURL.path
        )
        let episode = Episode(
            projectId: project.id,
            title: "Test Sample",
            sourceMediaPath: sampleVideoURL.path
        )

        let options = DubOptions(
            sourceLanguage: "ja",
            targetLanguage: .hinglish,
            hinglishMixing: .medium,
            translationStyle: .naturalAnime,
            voiceMode: .macNative,
            preserveBackgroundAudio: true,
            normalizeLoudness: true
        )

        let box = ProgressBox()
        let (outputVideoURL, qaReport) = try await orchestrator.run(
            project: project,
            episode: episode,
            options: options
        ) { state in
            box.lastProgress = state.progress
        }

        print("MKV QA Score: \(qaReport.score), Warnings: \(qaReport.warnings)")
        #expect(box.lastProgress == 100.0)
        #expect(FileManager.default.fileExists(atPath: outputVideoURL.path))
        #expect(qaReport.score >= 70.0)

        // Verify output file size > 10KB
        let attr = try? FileManager.default.attributesOfItem(atPath: outputVideoURL.path)
        let size = (attr?[.size] as? NSNumber)?.int64Value ?? 0
        #expect(size > 10_000, "Output video file size too small: \(size)")

        // Clean up
        try? FileManager.default.removeItem(at: tempBase)
    }

    @Test("Real Dual-Audio Anime MKV Dubbing with Explicit Japanese Track")
    func testRealDualAudioMKVDubbing() async throws {
        let rootDir: URL
        if #filePath.hasPrefix("/") {
            rootDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        } else {
            rootDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
        let mkvURL = rootDir.appendingPathComponent("storage/generic_shonen_ep01.mkv")
        guard FileManager.default.fileExists(atPath: mkvURL.path) else {
            return
        }

        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProjectStore(baseDirectory: tempBase)
        let orchestrator = JobOrchestrator(projectStore: store)

        let project = Project(
            name: "Generic Shonen MKV Project",
            sourceMediaPath: mkvURL.path
        )
        let episode = Episode(
            projectId: project.id,
            title: "Episode 01 Shonen",
            sourceMediaPath: mkvURL.path
        )

        // Select the Japanese track (stream index 1 in the dual-audio MKV)
        let options = DubOptions(
            sourceLanguage: "ja",
            targetLanguage: .hinglish,
            selectedAudioStreamIndex: 1,
            hinglishMixing: .medium,
            translationStyle: .naturalAnime,
            voiceMode: .macNative,
            preserveBackgroundAudio: true,
            normalizeLoudness: true
        )

        let box = ProgressBox()
        let (outputVideoURL, qaReport) = try await orchestrator.run(
            project: project,
            episode: episode,
            options: options
        ) { state in
            box.lastProgress = state.progress
        }

        print("MKV QA Score: \(qaReport.score), Warnings: \(qaReport.warnings)")
        #expect(box.lastProgress == 100.0)
        #expect(FileManager.default.fileExists(atPath: outputVideoURL.path))
        #expect(qaReport.score >= 70.0)

        // Inspect output with ffprobe to verify video and audio streams
        let probeRes = try await ProcessRunner.run(executable: "ffprobe", arguments: [
            "-v", "error",
            "-show_entries", "stream=codec_type,codec_name",
            "-of", "csv=p=0",
            outputVideoURL.path
        ])
        #expect(probeRes.isSuccess)
        #expect(probeRes.stdout.contains("video"))
        #expect(probeRes.stdout.contains("audio"))

        // Clean up
        try? FileManager.default.removeItem(at: tempBase)
    }
}
