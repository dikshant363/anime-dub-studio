import Foundation
import AVFoundation

public final class DialogueTimingService: DialogueTimingServiceProtocol, Sendable {
    public init() {}

    public func adjustAudioTiming(
        inputURL: URL,
        outputURL: URL,
        targetDuration: Double,
        currentDuration: Double
    ) async throws -> (outputURL: URL, finalDuration: Double, stretchRatio: Double) {
        guard targetDuration > 0, currentDuration > 0 else {
            return (inputURL, currentDuration, 1.0)
        }

        let ratio = currentDuration / targetDuration

        // Within 5% tolerance, leave untouched
        if ratio >= 0.95 && ratio <= 1.05 {
            try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if inputURL.path != outputURL.path {
                try? FileManager.default.removeItem(at: outputURL)
                try? FileManager.default.copyItem(at: inputURL, to: outputURL)
            }
            return (outputURL, currentDuration, 1.0)
        }

        // Clamp stretch factor between 0.75x and 1.30x to avoid unnatural pitch/tempo artifacts
        let clampedRatio = max(0.75, min(1.30, ratio))
        let atempoVal = round(clampedRatio * 1000) / 1000

        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let args = [
            "-y", "-i", inputURL.path,
            "-filter:a", "atempo=\(atempoVal)",
            "-acodec", "pcm_s16le",
            "-ar", "24000",
            "-ac", "1",
            outputURL.path
        ]

        let res = try await ProcessRunner.run(executable: "ffmpeg", arguments: args)
        guard res.isSuccess && FileManager.default.fileExists(atPath: outputURL.path) else {
            return (inputURL, currentDuration, 1.0)
        }

        var finalDuration = currentDuration
        if let audioFile = try? AVAudioFile(forReading: outputURL) {
            let frames = Double(audioFile.length)
            let rate = audioFile.processingFormat.sampleRate
            if rate > 0 {
                finalDuration = round((frames / rate) * 1000) / 1000
            }
        }

        return (outputURL, finalDuration, clampedRatio)
    }
}
