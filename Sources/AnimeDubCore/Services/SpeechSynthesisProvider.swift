import Foundation
import AVFoundation

public final class SpeechSynthesisProvider: SpeechSynthesisProviderProtocol, Sendable {
    public let name = "macOS Native Speech (Indian Cast Voices)"

    private let voiceMap: [String: String] = [
        "rishi": "Rishi",
        "aman": "Aman",
        "lekha": "Lekha",
        "tara": "Tara",
        "male_lead": "Rishi",
        "male_secondary": "Aman",
        "female_lead": "Lekha",
        "female_secondary": "Tara",
        "speaker_00": "Rishi",
        "speaker_01": "Lekha",
        "speaker_02": "Aman",
        "speaker_03": "Tara"
    ]

    public init() {}

    public func synthesize(
        text: String,
        hindiText: String?,
        to outputURL: URL,
        voiceId: String,
        speedRate: Double = 1.0,
        pitchPercent: Double = 0.0,
        speakerSimilarity: Double = 80.0,
        accentMode: AccentPreservationMode = .balanced,
        targetNaturalness: Double = 85.0
    ) async throws -> SynthesisResult {
        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let key = voiceId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let chosenVoice = voiceMap[key] ?? "Rishi"

        // 1. Script Selection & Accent Modulation
        let speechInput: String
        if chosenVoice == "Lekha" && hindiText != nil && !hindiText!.isEmpty {
            speechInput = hindiText!
        } else {
            speechInput = text
        }

        // Clean speech input of command symbols
        var clean = speechInput.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            clean = "..."
        }

        // 2. Pace & Cadence Calculation based on Accent & Naturalness
        let baseWPM: Double
        switch accentMode {
        case .preserveOriginal:
            // Fast, punchy anime delivery matching Japanese source rhythm
            baseWPM = 185.0
        case .balanced:
            baseWPM = 175.0
        case .naturalTarget:
            // Natural colloquial Hindi/Hinglish flow
            baseWPM = 168.0
        }

        let clampedSimilarity = max(0.0, min(100.0, speakerSimilarity))
        let clampedNaturalness = max(0.0, min(100.0, targetNaturalness))

        // Moderate rate by user speedRate, speaker similarity, and target naturalness
        // High naturalness ensures speech tempo remains intelligible and conversational
        let naturalnessWeight = clampedNaturalness / 100.0
        let effectiveSpeed = (speedRate * (1.0 - naturalnessWeight * 0.15)) + (1.0 * naturalnessWeight * 0.15)
        let wpm = Int(round(baseWPM * max(0.6, min(1.8, effectiveSpeed))))

        let tempAIFF = outputURL.deletingPathExtension().appendingPathExtension("temp.aiff")
        defer {
            try? FileManager.default.removeItem(at: tempAIFF)
        }

        // 3. Synthesize via /usr/bin/say
        let sayArgs = [
            "-v", chosenVoice,
            "-r", "\(wpm)",
            clean,
            "-o", tempAIFF.path
        ]

        let sayRes = try await ProcessRunner.run(executable: "/usr/bin/say", arguments: sayArgs)
        guard sayRes.isSuccess && FileManager.default.fileExists(atPath: tempAIFF.path) else {
            throw AnimeDubError.speechSynthesisFailed("macOS speech synthesis failed: \(sayRes.stderr)")
        }

        // 4. Acoustic Conditioning & Equalization Filter Construction
        // Condition the output audio based on speaker similarity & accent preservation
        var audioFilters: [String] = []

        let isFemaleVoice = (chosenVoice == "Lekha" || chosenVoice == "Tara")

        if clampedSimilarity >= 50.0 {
            // Apply spectral formant shaping to converge toward source anime voice characteristics
            let intensity = (clampedSimilarity - 50.0) / 50.0 // 0.0 to 1.0
            if isFemaleVoice {
                // Boost upper-mid frequencies for crisp anime heroine timbre
                let gain = 1.0 + (intensity * 2.5) // up to +3.5 dB
                audioFilters.append("equalizer=f=3200:t=q:w=1.2:g=\(String(format: "%.1f", gain))")
            } else {
                // Enhance low-mid chest resonance for anime hero / commander timbre
                let gain = 1.0 + (intensity * 2.0) // up to +3.0 dB
                audioFilters.append("equalizer=f=220:t=q:w=1.5:g=\(String(format: "%.1f", gain))")
            }
        }

        switch accentMode {
        case .preserveOriginal:
            // Crisp high-frequency presence to mimic Japanese consonant delivery
            audioFilters.append("treble=g=1.8:f=4200")
        case .balanced:
            // Smooth presence
            audioFilters.append("equalizer=f=1000:t=q:w=1.0:g=0.5")
        case .naturalTarget:
            // Warm target-language broadcast profile
            audioFilters.append("lowpass=f=9800")
        }

        let filterString = audioFilters.isEmpty ? "anull" : audioFilters.joined(separator: ",")

        // 5. Convert AIFF to 24kHz 16-bit PCM mono WAV with Acoustic Filters
        let convArgs = [
            "-y", "-i", tempAIFF.path,
            "-af", filterString,
            "-acodec", "pcm_s16le",
            "-ar", "24000",
            "-ac", "1",
            outputURL.path
        ]

        let convRes = try await ProcessRunner.run(executable: "ffmpeg", arguments: convArgs)
        guard convRes.isSuccess && FileManager.default.fileExists(atPath: outputURL.path) else {
            throw AnimeDubError.speechSynthesisFailed("Audio conversion failed: \(convRes.stderr)")
        }

        // Measure accurate duration via AVAudioFile
        var duration: Double = 0.5
        if let audioFile = try? AVAudioFile(forReading: outputURL) {
            let frames = Double(audioFile.length)
            let rate = audioFile.processingFormat.sampleRate
            if rate > 0 {
                duration = round((frames / rate) * 1000) / 1000
            }
        }

        return SynthesisResult(audioURL: outputURL, duration: duration)
    }

    public func previewVoice(
        voiceId: String,
        text: String,
        to outputURL: URL,
        speedRate: Double = 1.0,
        pitchPercent: Double = 0.0,
        speakerSimilarity: Double = 80.0,
        accentMode: AccentPreservationMode = .balanced
    ) async throws -> SynthesisResult {
        try await synthesize(
            text: text,
            hindiText: nil,
            to: outputURL,
            voiceId: voiceId,
            speedRate: speedRate,
            pitchPercent: pitchPercent,
            speakerSimilarity: speakerSimilarity,
            accentMode: accentMode,
            targetNaturalness: 85.0
        )
    }
}
