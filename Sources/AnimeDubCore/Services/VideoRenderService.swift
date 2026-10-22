import Foundation

public final class VideoRenderService: VideoRenderServiceProtocol, Sendable {
    public init() {}

    public func renderDubbedVideo(
        sourceVideoURL: URL,
        dubbedAudioURL: URL,
        to outputURL: URL,
        subtitleURL: URL? = nil
    ) async throws -> URL {
        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let args = [
            "-y",
            "-i", sourceVideoURL.path,
            "-i", dubbedAudioURL.path,
            "-c:v", "copy",
            "-c:a", "aac",
            "-b:a", "256k",
            "-map", "0:v:0",
            "-map", "1:a:0",
            "-shortest",
            outputURL.path
        ]

        let res = try await ProcessRunner.run(executable: "ffmpeg", arguments: args)
        guard res.isSuccess && FileManager.default.fileExists(atPath: outputURL.path) else {
            throw AnimeDubError.renderingFailed("Video rendering and remuxing failed: \(res.stderr)")
        }

        return outputURL
    }
}
