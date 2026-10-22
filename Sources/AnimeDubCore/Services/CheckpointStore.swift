import Foundation

public final class CheckpointStore: Sendable {
    public init() {}

    public func saveCheckpoint<T: Codable>(data: T, to url: URL) throws {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(data)
        try encoded.write(to: url, options: .atomic)
    }

    public func loadCheckpoint<T: Codable>(from url: URL, as type: T.Type) -> T? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return decoded
    }

    public func checkpointExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    public func clearCheckpoints(in directory: URL) {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
