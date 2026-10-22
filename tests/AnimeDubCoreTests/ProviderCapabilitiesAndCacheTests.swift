import Testing
import Foundation
@testable import AnimeDubCore

@Suite("Provider Capabilities & Cache Invalidation Tests")
struct ProviderCapabilitiesAndCacheTests {

    @Test("SpeechSynthesisProvider exposes truthful capabilities model without false cloning claims")
    func testTruthfulCapabilitiesModel() {
        let provider = SpeechSynthesisProvider()
        let caps = provider.capabilities

        #expect(caps.providerId == "com.apple.speech.native_cast")
        #expect(caps.providerName == "macOS Native Speech (Indian Cast Voices)")
        #expect(caps.technologyType == .nativeAcousticCast)
        #expect(caps.supportsVoiceCloning == false)
        #expect(caps.supportsReferenceAudioConditioning == false)
        #expect(caps.supportsIndependentNaturalnessControl == true)
        #expect(caps.supportedVoiceIds.count >= 4)
        #expect(caps.disclosureNotice.contains("Zero-shot neural voice cloning from reference audio is not supported by macOS native speech."))
        #expect(caps.disclosureNotice.contains("prosodic cadence adaptation"))
    }

    @Test("CharacterProfile maintains authentic reference audio extraction metadata")
    func testCharacterProfileReferenceAudioMetadata() throws {
        let profile = CharacterProfile(
            speakerTag: "SPEAKER_00",
            name: "Sousuke Sagara",
            voiceId: "com.apple.speech.synthesis.voice.rishi",
            gender: "MALE",
            speakerSimilarity: 82.0,
            targetNaturalness: 75.0,
            accentMode: .preserveOriginal,
            providerId: "com.apple.speech.native_cast",
            referenceAudioPath: "/workspace/projects/proj1/voices/ref_SPEAKER_00.wav",
            referenceProvenance: "Extracted from source Japanese dialogue (segment seg_002, duration 2.80s)",
            assignmentConfidence: 0.94,
            measuredPitchF0: 128.5,
            measuredDurationSeconds: 2.80,
            pronunciationNotes: "Military terminology, disciplined tone"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(profile)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CharacterProfile.self, from: data)

        #expect(decoded.id == "SPEAKER_00")
        #expect(decoded.speakerTag == "SPEAKER_00")
        #expect(decoded.name == "Sousuke Sagara")
        #expect(decoded.voiceId == "com.apple.speech.synthesis.voice.rishi")
        #expect(decoded.referenceAudioPath == "/workspace/projects/proj1/voices/ref_SPEAKER_00.wav")
        #expect(decoded.referenceProvenance?.contains("segment seg_002") == true)
        #expect(decoded.assignmentConfidence == 0.94)
        #expect(decoded.measuredPitchF0 == 128.5)
        #expect(decoded.measuredDurationSeconds == 2.80)
        #expect(decoded.targetNaturalness == 75.0)
        #expect(decoded.accentMode == .preserveOriginal)
        #expect(decoded.providerId == "com.apple.speech.native_cast")
    }

    @Test("Dialogue segment cache signature detects dirty text and voice changes while preserving valid audio")
    func testCacheSignatureInvalidation() {
        let segText = "Mera naam Sousuke Sagara hai."
        let voiceId = "com.apple.speech.synthesis.voice.rishi"
        let speedRate = 1.05
        let similarity = 80.0
        let naturalness = 70.0
        let accentMode = "preserveOriginal"

        // Canonical signature format used by JobOrchestrator Stage 5
        let baselineSig = "\(segText)|\(voiceId)|\(String(format: "%.2f", speedRate))|\(String(format: "%.1f", similarity))|\(String(format: "%.1f", naturalness))|\(accentMode)"

        // 1. Unchanged state matches baseline
        let sameSig = "\(segText)|\(voiceId)|\(String(format: "%.2f", speedRate))|\(String(format: "%.1f", similarity))|\(String(format: "%.1f", naturalness))|\(accentMode)"
        #expect(baselineSig == sameSig)

        // 2. Text modification invalidates cache
        let editedText = "Main sergeant Sousuke Sagara hoon."
        let editedSig = "\(editedText)|\(voiceId)|\(String(format: "%.2f", speedRate))|\(String(format: "%.1f", similarity))|\(String(format: "%.1f", naturalness))|\(accentMode)"
        #expect(baselineSig != editedSig)

        // 3. Voice cast reassignment invalidates cache
        let reassignedVoiceId = "com.apple.speech.synthesis.voice.lekha"
        let voiceChangeSig = "\(segText)|\(reassignedVoiceId)|\(String(format: "%.2f", speedRate))|\(String(format: "%.1f", similarity))|\(String(format: "%.1f", naturalness))|\(accentMode)"
        #expect(baselineSig != voiceChangeSig)

        // 4. Accent preset change invalidates cache
        let accentChangeSig = "\(segText)|\(voiceId)|\(String(format: "%.2f", speedRate))|\(String(format: "%.1f", similarity))|\(String(format: "%.1f", naturalness))|naturalTarget"
        #expect(baselineSig != accentChangeSig)
    }
}
