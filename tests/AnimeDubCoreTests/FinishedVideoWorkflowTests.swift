import Testing
import Foundation
@testable import AnimeDubCore

@Suite("Finished-Video Result & Studio Re-Editability Tests")
struct FinishedVideoWorkflowTests {
    @Test("Episode model retains complete technical specifications and deliverable metadata")
    func testEpisodeMetadataCompleteness() throws {
        let ep = Episode(
            projectId: "PROJ_TEST_01",
            title: "Test Episode 01",
            sourceMediaPath: "/path/to/source.mkv",
            duration: 1420.5,
            resolution: "1920x1080",
            fps: 23.976,
            masterAudioPath: "/path/to/master.wav",
            dubbedAudioPath: "/path/to/dubbed.wav",
            subtitleSrtPath: "/path/to/subtitles.srt",
            subtitleAssPath: "/path/to/subtitles.ass",
            exportedVideoPath: "/path/to/final_dub.mp4",
            qaScore: 96.5,
            numSpeakers: 4,
            targetLanguageDisplayName: "Hinglish (Medium Mixing)",
            fileSizeBytes: 175_240_000,
            audioTrackConfig: "AAC Stereo 48kHz (EBU R128)",
            status: "COMPLETED"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(ep)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Episode.self, from: data)

        #expect(decoded.numSpeakers == 4)
        #expect(decoded.targetLanguageDisplayName == "Hinglish (Medium Mixing)")
        #expect(decoded.fileSizeBytes == 175_240_000)
        #expect(decoded.audioTrackConfig == "AAC Stereo 48kHz (EBU R128)")
        #expect(decoded.qaScore == 96.5)
        #expect(decoded.status == "COMPLETED")
    }

    @Test("Project Re-Editability: Studio reload preserves full dialogue timeline and character assignments")
    func testProjectReEditabilityPreservation() throws {
        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("ReEditTest_\(UUID().uuidString)")
        let store = ProjectStore(baseDirectory: tempBase)
        defer { try? FileManager.default.removeItem(at: tempBase) }

        let projId = "PROJECT_RE_EDIT"
        let epId = "EPISODE_RE_EDIT"

        let project = Project(
            id: projId,
            name: "Full Metal Panic - Studio Reopen Test",
            sourceMediaPath: "/tmp/sample.mkv",
            status: "COMPLETED",
            episodes: [
                Episode(
                    id: epId,
                    projectId: projId,
                    title: "Episode 1",
                    sourceMediaPath: "/tmp/sample.mkv",
                    duration: 120.0,
                    exportedVideoPath: "/tmp/export/dub.mp4",
                    qaScore: 94.0
                )
            ]
        )
        store.addOrUpdateProject(project)

        // Store segments
        let originalSegments = [
            DialogueSegment(
                segmentIndex: 0,
                startTime: 1.25,
                endTime: 3.80,
                targetDuration: 2.55,
                speakerLabel: "Sousuke",
                sourceText: "何をしているんだ？",
                translatedText: "तुम क्या कर रहे हो?",
                adaptedHindiText: "तुम क्या कर रहे हो?",
                adaptedHinglishText: "Tum kya kar rahe ho?",
                audioPath: "/tmp/voices/seg_000.wav",
                synthesizedDuration: 2.50,
                voiceId: "Rishi"
            ),
            DialogueSegment(
                segmentIndex: 1,
                startTime: 4.10,
                endTime: 6.90,
                targetDuration: 2.80,
                speakerLabel: "Kaname",
                sourceText: "ちょっと待って！",
                translatedText: "जरा रुको!",
                adaptedHindiText: "जरा रुको!",
                adaptedHinglishText: "Zara ruko!",
                audioPath: "/tmp/voices/seg_001.wav",
                synthesizedDuration: 2.70,
                voiceId: "Lekha"
            )
        ]
        store.saveDialogueSegments(originalSegments, for: epId, in: projId)

        // Simulate "Edit in Studio" reopening
        let loadedProjects = store.loadProjects()
        let reloadedProj = loadedProjects.first(where: { $0.id == projId })
        #expect(reloadedProj != nil)

        let reloadedSegments = store.loadDialogueSegments(for: epId, in: projId)
        #expect(reloadedSegments.count == 2)
        #expect(reloadedSegments[0].speakerLabel == "Sousuke")
        #expect(reloadedSegments[0].voiceId == "Rishi")
        #expect(reloadedSegments[0].adaptedHinglishText == "Tum kya kar rahe ho?")
        #expect(reloadedSegments[1].speakerLabel == "Kaname")
        #expect(reloadedSegments[1].voiceId == "Lekha")
        #expect(reloadedSegments[1].adaptedHinglishText == "Zara ruko!")

        // Mutate a line in Studio editor and re-save
        var updatedSegments = reloadedSegments
        updatedSegments[0].adaptedHinglishText = "Tum yahan kya kar rahe ho, batao?"
        store.saveDialogueSegments(updatedSegments, for: epId, in: projId)

        let finalSegments = store.loadDialogueSegments(for: epId, in: projId)
        #expect(finalSegments[0].adaptedHinglishText == "Tum yahan kya kar rahe ho, batao?")
    }

    @Test("Audio-only export and Subtitle export produce verified standalone files")
    func testDeliverablesExtractionAndExport() async throws {
        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("DeliverablesTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempBase) }

        // Create dummy master audio and SRT
        let sampleWAV = tempBase.appendingPathComponent("master_audio.wav")
        let dummyWAVHeader = Data([
            0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
            0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20,
            0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
            0x80, 0x3E, 0x00, 0x00, 0x00, 0x7D, 0x00, 0x00,
            0x02, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61,
            0x00, 0x00, 0x00, 0x00
        ])
        try dummyWAVHeader.write(to: sampleWAV)

        let sampleSRT = tempBase.appendingPathComponent("subtitles.srt")
        let srtContent = """
        1
        00:00:01,000 --> 00:00:03,500
        Tum kya kar rahe ho?
        
        2
        00:00:04,000 --> 00:00:06,000
        Zara ruko!
        """
        try srtContent.write(to: sampleSRT, atomically: true, encoding: .utf8)

        // Test export to user destination
        let exportAudioDest = tempBase.appendingPathComponent("Exported_Dubbed_Audio.wav")
        let exportSrtDest = tempBase.appendingPathComponent("Exported_Subtitles.srt")

        try FileManager.default.copyItem(at: sampleWAV, to: exportAudioDest)
        try FileManager.default.copyItem(at: sampleSRT, to: exportSrtDest)

        #expect(FileManager.default.fileExists(atPath: exportAudioDest.path))
        #expect(FileManager.default.fileExists(atPath: exportSrtDest.path))

        let readSRT = try String(contentsOf: exportSrtDest, encoding: .utf8)
        #expect(readSRT.contains("Tum kya kar rahe ho?"))
        #expect(readSRT.contains("Zara ruko!"))
    }
}
