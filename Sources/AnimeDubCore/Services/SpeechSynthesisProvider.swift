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
        pitchPercent: Double = 0.0
    ) async throws -> SynthesisResult {
        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let key = voiceId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let chosenVoice = voiceMap[key] ?? "Rishi"

        // For Lekha (Hindi voice), prefer Devanagari hindiText if provided
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

        // Calculate words per minute (standard 175 wpm)
        let wpm = Int(round(175.0 * max(0.6, min(1.8, speedRate))))

        let tempAIFF = outputURL.deletingPathExtension().appendingPathExtension("temp.aiff")
        defer {
            try? FileManager.default.removeItem(at: tempAIFF)
        }

        // 1. Synthesize via /usr/bin/say
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

        // 2. Convert AIFF to 24kHz 16-bit PCM mono WAV
        let convArgs = [
            "-y", "-i", tempAIFF.path,
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
}
