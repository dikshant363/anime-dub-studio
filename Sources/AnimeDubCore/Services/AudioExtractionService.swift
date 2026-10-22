import Foundation

public final class AudioExtractionService: AudioExtractionServiceProtocol, Sendable {
    public init() {}

    public func extractMasterAudio(
        from mediaURL: URL,
        to outputURL: URL,
        audioStreamIndex: Int?,
        sourceLang: String = "ja"
    ) async throws {
        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        // 1. Try explicit stream index if provided
        if let streamIdx = audioStreamIndex {
            let args = [
                "-y", "-i", mediaURL.path,
                "-map", "0:\(streamIdx)",
                "-vn", "-acodec", "pcm_s24le", "-ar", "48000", "-ac", "2",
                outputURL.path
            ]
            let res = try await ProcessRunner.run(executable: "ffmpeg", arguments: args)
            if res.isSuccess && FileManager.default.fileExists(atPath: outputURL.path) {
                return
            }
        }

        // 2. Try language mapping (e.g. jpn)
        let langTag = (sourceLang == "ja" || sourceLang == "japanese") ? "jpn" : sourceLang
        let mapArgs = [
            "-y", "-i", mediaURL.path,
            "-map", "0:m:language:\(langTag)",
            "-vn", "-acodec", "pcm_s24le", "-ar", "48000", "-ac", "2",
            outputURL.path
        ]
        let mapRes = try await ProcessRunner.run(executable: "ffmpeg", arguments: mapArgs)
        if mapRes.isSuccess && FileManager.default.fileExists(atPath: outputURL.path) {
            return
        }

        // 3. Fallback to default audio stream
        let fallbackArgs = [
            "-y", "-i", mediaURL.path,
            "-vn", "-acodec", "pcm_s24le", "-ar", "48000", "-ac", "2",
            outputURL.path
        ]
        let fallbackRes = try await ProcessRunner.run(executable: "ffmpeg", arguments: fallbackArgs)
        guard fallbackRes.isSuccess else {
            throw AnimeDubError.audioMixingFailed("Master audio extraction failed: \(fallbackRes.stderr)")
        }
    }

    public func extractASRAudio(
        from mediaURL: URL,
        to outputURL: URL,
        audioStreamIndex: Int?,
        sourceLang: String = "ja"
    ) async throws {
        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        // 1. Try explicit stream index
        if let streamIdx = audioStreamIndex {
            let args = [
                "-y", "-i", mediaURL.path,
                "-map", "0:\(streamIdx)",
                "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
                outputURL.path
            ]
            let res = try await ProcessRunner.run(executable: "ffmpeg", arguments: args)
            if res.isSuccess && FileManager.default.fileExists(atPath: outputURL.path) {
                return
            }
        }

        // 2. Try language mapping
        let langTag = (sourceLang == "ja" || sourceLang == "japanese") ? "jpn" : sourceLang
        let mapArgs = [
            "-y", "-i", mediaURL.path,
            "-map", "0:m:language:\(langTag)",
            "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
            outputURL.path
        ]
        let mapRes = try await ProcessRunner.run(executable: "ffmpeg", arguments: mapArgs)
        if mapRes.isSuccess && FileManager.default.fileExists(atPath: outputURL.path) {
            return
        }

        // 3. Fallback
        let fallbackArgs = [
            "-y", "-i", mediaURL.path,
            "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
            outputURL.path
        ]
        let fallbackRes = try await ProcessRunner.run(executable: "ffmpeg", arguments: fallbackArgs)
        guard fallbackRes.isSuccess else {
            throw AnimeDubError.asrFailed("ASR audio extraction failed: \(fallbackRes.stderr)")
        }
    }
}
