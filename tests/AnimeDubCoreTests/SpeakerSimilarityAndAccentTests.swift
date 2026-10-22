import Testing
import Foundation
@testable import AnimeDubCore

@Suite("Speaker Similarity & Accent Preservation Tests")
struct SpeakerSimilarityAndAccentTests {
    @Test("DubOptions encodes and decodes similarity and accent settings correctly")
    func testDubOptionsSerialization() throws {
        let options = DubOptions(
            sourceLanguage: "ja",
            targetLanguage: .hinglish,
            selectedAudioStreamIndex: 2,
            hinglishMixing: .medium,
            translationStyle: .naturalAnime,
            voiceMode: .macNative,
            preserveBackgroundAudio: true,
            normalizeLoudness: true,
            speakerSimilarity: 92.5,
            targetNaturalness: 78.0,
            accentPreservation: .preserveOriginal
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(options)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DubOptions.self, from: data)

        #expect(decoded.speakerSimilarity == 92.5)
        #expect(decoded.targetNaturalness == 78.0)
        #expect(decoded.accentPreservation == .preserveOriginal)
        #expect(decoded.selectedAudioStreamIndex == 2)
    }

    @Test("AccentPreservationMode provides descriptive and distinct metadata")
    func testAccentPreservationPresets() {
        let modes = AccentPreservationMode.allCases
        #expect(modes.count == 3)

        for mode in modes {
            #expect(!mode.displayName.isEmpty)
            #expect(!mode.description.isEmpty)
        }

        #expect(AccentPreservationMode.preserveOriginal.displayName.contains("Preserve Original"))
        #expect(AccentPreservationMode.balanced.displayName.contains("Balanced"))
        #expect(AccentPreservationMode.naturalTarget.displayName.contains("Natural Hindi/Hinglish"))
    }

    @Test("CharacterProfile stores and persists acoustic parameters")
    func testCharacterProfilePersistence() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CastTest_\(UUID().uuidString)")
        let store = ProjectStore(baseDirectory: tempDir)
        let projectId = "PROJ_CAST_TEST"

        let profiles = [
            CharacterProfile(
                speakerTag: "SPEAKER_00",
                name: "Sousuke Sagara",
                voiceId: "Rishi",
                gender: "male",
                originalPitchF0: 125.4,
                spectralCentroid: 2400.0,
                speakerSimilarity: 88.0
            ),
            CharacterProfile(
                speakerTag: "SPEAKER_01",
                name: "Kaname Chidori",
                voiceId: "Lekha",
                gender: "female",
                originalPitchF0: 228.6,
                spectralCentroid: 3850.0,
                speakerSimilarity: 95.0
            )
        ]

        store.saveCharacterProfiles(profiles, for: projectId)

        let loaded = store.loadCharacterProfiles(for: projectId)
        #expect(loaded.count == 2)

        let sousuke = loaded.first(where: { $0.speakerTag == "SPEAKER_00" })
        #expect(sousuke != nil)
        #expect(sousuke?.name == "Sousuke Sagara")
        #expect(sousuke?.originalPitchF0 == 125.4)
        #expect(sousuke?.speakerSimilarity == 88.0)

        let kaname = loaded.first(where: { $0.speakerTag == "SPEAKER_01" })
        #expect(kaname != nil)
        #expect(kaname?.name == "Kaname Chidori")
        #expect(kaname?.spectralCentroid == 3850.0)
        #expect(kaname?.speakerSimilarity == 95.0)

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Voice Preview generates acoustic PCM audio file")
    func testVoicePreviewSynthesis() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let provider = SpeechSynthesisProvider()
        let outURL = tempDir.appendingPathComponent("preview_rishi.wav")

        let result = try await provider.previewVoice(
            voiceId: "Rishi",
            text: "Hum mission ke liye tayyar hain!",
            to: outURL,
            speakerSimilarity: 85.0,
            accentMode: .balanced
        )

        #expect(FileManager.default.fileExists(atPath: result.audioURL.path))
        #expect(result.duration > 0.5)

        // Verify audio format with ffprobe
        let probe = try await ProcessRunner.run(executable: "ffprobe", arguments: [
            "-v", "error",
            "-show_entries", "stream=codec_name,sample_rate,channels",
            "-of", "json",
            result.audioURL.path
        ])
        #expect(probe.isSuccess)
        #expect(probe.stdout.contains("pcm_s16le"))
        #expect(probe.stdout.contains("24000"))
    }
}
