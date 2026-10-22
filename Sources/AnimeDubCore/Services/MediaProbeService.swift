import Foundation
import AVFoundation

public final class MediaProbeService: MediaProbeServiceProtocol, @unchecked Sendable {
    public init() {}

    public func inspectMedia(at url: URL) async throws -> MediaMetadata {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            throw AnimeDubError.unsupportedMedia("Path does not exist or is a directory: \(url.path)")
        }

        let ext = url.pathExtension.lowercased()
        let allowed = ["mp4", "mkv", "mov", "webm", "m4v", "avi", "ts"]
        if !ext.isEmpty && !allowed.contains(ext) {
            throw AnimeDubError.unsupportedMedia("Unsupported media container extension: .\(ext)")
        }

        let asset = AVURLAsset(url: url)
        var duration: Double = 0.0
        var fps: Double = 24.0
        var resolution = "1920x1080"
        var videoCodec: String? = nil
        var audioCodec: String? = nil

        do {
            let durationValue = try await asset.load(.duration)
            duration = CMTimeGetSeconds(durationValue)

            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                let naturalSize = try await videoTrack.load(.naturalSize)
                resolution = "\(Int(naturalSize.width))x\(Int(naturalSize.height))"

                let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                if nominalFrameRate > 0 {
                    fps = round(Double(nominalFrameRate) * 100) / 100
                }
            }
        } catch {
            // Fall back to ffprobe inspection
        }

        // Deep stream probe via ffprobe for explicit audio stream mapping & languages
        var audioStreams: [AudioStreamMetadata] = []
        var fileSize: Int64 = 0
        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attr[.size] as? NSNumber {
            fileSize = size.int64Value
        }

        let probeArgs = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            url.path
        ]

        if let res = try? await ProcessRunner.run(executable: "ffprobe", arguments: probeArgs), res.isSuccess {
            if let data = res.stdout.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let format = json["format"] as? [String: Any] {
                    if duration <= 0, let durStr = format["duration"] as? String, let d = Double(durStr) {
                        duration = d
                    }
                }
                if let streams = json["streams"] as? [[String: Any]] {
                    for stream in streams {
                        let codecType = stream["codec_type"] as? String ?? ""
                        if codecType == "video" && videoCodec == nil {
                            videoCodec = stream["codec_name"] as? String
                        } else if codecType == "audio" {
                            let idx = stream["index"] as? Int ?? audioStreams.count
                            let cName = stream["codec_name"] as? String ?? "unknown"
                            let channels = stream["channels"] as? Int ?? 2
                            let sr = Int(stream["sample_rate"] as? String ?? "48000") ?? 48000
                            let tags = stream["tags"] as? [String: Any]
                            let lang = tags?["language"] as? String
                            let title = tags?["title"] as? String
                            let disposition = stream["disposition"] as? [String: Any]
                            let isDef = (disposition?["default"] as? Int ?? 0) == 1

                            audioStreams.append(AudioStreamMetadata(
                                index: idx,
                                codecName: cName,
                                channels: channels,
                                sampleRate: sr,
                                language: lang,
                                title: title,
                                isDefault: isDef
                            ))
                            if audioCodec == nil {
                                audioCodec = cName
                            }
                        }
                    }
                }
            }
        }

        if duration <= 0 {
            duration = 1.0
        }

        return MediaMetadata(
            duration: round(duration * 100) / 100,
            fps: fps,
            resolution: resolution,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            bitrate: 0,
            sizeBytes: fileSize,
            audioStreams: audioStreams
        )
    }
}
