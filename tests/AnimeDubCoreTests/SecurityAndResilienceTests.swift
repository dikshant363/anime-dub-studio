import Testing
import Foundation
@testable import AnimeDubCore

@Suite("Security & Resilience Tests")
struct SecurityAndResilienceTests {
    @Test("Media probe rejects non-existent files")
    func testProbeNonExistentFile() async {
        let probe = MediaProbeService()
        let fakeURL = URL(fileURLWithPath: "/tmp/non_existent_video_\(UUID().uuidString).mp4")
        await #expect(throws: AnimeDubError.self) {
            _ = try await probe.inspectMedia(at: fakeURL)
        }
    }

    @Test("Media probe rejects directories passed as media files")
    func testProbeDirectoryRejection() async {
        let probe = MediaProbeService()
        let dirURL = FileManager.default.temporaryDirectory
        await #expect(throws: AnimeDubError.self) {
            _ = try await probe.inspectMedia(at: dirURL)
        }
    }

    @Test("Media probe rejects unsupported file formats")
    func testProbeUnsupportedExtension() async throws {
        let probe = MediaProbeService()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("malicious_script_\(UUID().uuidString).exe")
        try "MZ9000".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        await #expect(throws: AnimeDubError.self) {
            _ = try await probe.inspectMedia(at: tempFile)
        }
    }

    @Test("Checkpoint store gracefully handles corrupt JSON without crashing")
    func testCorruptCheckpointRecovery() throws {
        let store = CheckpointStore()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("corrupt_checkpoint_\(UUID().uuidString).json")
        try "{ this is not valid json !! @#$ ".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = store.loadCheckpoint(from: tempFile, as: [ASRSegment].self)
        #expect(result == nil, "Corrupted checkpoint must return nil instead of throwing unhandled error.")
    }

    @Test("Checkpoint store atomic write and load roundtrip")
    func testCheckpointRoundtrip() throws {
        let store = CheckpointStore()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("checkpoint_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let segments = [
            ASRSegment(id: 1, start: 0.0, end: 2.5, text: "テスト", confidence: 0.98, language: "ja", speaker: "SPEAKER_00")
        ]

        try store.saveCheckpoint(data: segments, to: tempFile)
        let loaded = store.loadCheckpoint(from: tempFile, as: [ASRSegment].self)

        #expect(loaded != nil)
        #expect(loaded?.count == 1)
        #expect(loaded?.first?.text == "テスト")
    }

    @Test("ProcessRunner safely handles argument arrays with spaces and quotes")
    func testProcessRunnerArgumentSafety() async throws {
        let testString = "Hello \"World\" with spaces & symbols $PATH"
        let res = try await ProcessRunner.run(executable: "echo", arguments: [testString])
        #expect(res.isSuccess)
        #expect(res.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == testString)
    }

    @Test("ProcessRunner reports error on unknown executable")
    func testProcessRunnerUnknownExecutable() async {
        await #expect(throws: AnimeDubError.self) {
            _ = try await ProcessRunner.run(executable: "completely_fake_executable_xyz_123", arguments: [])
        }
    }
}
