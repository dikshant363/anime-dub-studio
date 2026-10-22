import Foundation

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var isSuccess: Bool {
        return exitCode == 0
    }
}

final class ProcessStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var hasResumed = false
    private var stdoutData = Data()
    private var stderrData = Data()

    func setProcess(_ p: Process) {
        lock.lock()
        defer { lock.unlock() }
        self.process = p
    }

    func appendStdout(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        stdoutData.append(data)
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        stderrData.append(data)
    }

    func terminate() {
        lock.lock()
        let p = self.process
        lock.unlock()
        if let p = p, p.isRunning {
            p.terminate()
        }
    }

    func finishAndResume(
        terminationStatus: Int32,
        continuation: CheckedContinuation<ProcessResult, Error>
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return }
        hasResumed = true

        let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

        continuation.resume(returning: ProcessResult(
            exitCode: terminationStatus,
            stdout: stdoutStr,
            stderr: stderrStr
        ))
    }

    func resumeFailure(
        error: Error,
        continuation: CheckedContinuation<ProcessResult, Error>
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(throwing: error)
    }
}

public enum ProcessRunner: Sendable {
    public static func resolveExecutable(named name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)",
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/tools/\(name)").path,
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/\(name)").path
        ]
        for c in candidates {
            if FileManager.default.isExecutableFile(atPath: c) {
                return c
            }
        }
        return nil
    }

    public static func run(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeoutSeconds: TimeInterval = 300.0
    ) async throws -> ProcessResult {
        guard let resolvedPath = resolveExecutable(named: executable) ?? (FileManager.default.isExecutableFile(atPath: executable) ? executable : nil) else {
            throw AnimeDubError.runtimeDependencyFailed("Could not locate executable: \(executable)")
        }

        let stateBox = ProcessStateBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: resolvedPath)
                process.arguments = arguments

                if let wd = workingDirectory {
                    process.currentDirectoryURL = wd
                }

                var env = ProcessInfo.processInfo.environment
                if let customEnv = environment {
                    for (k, v) in customEnv {
                        env[k] = v
                    }
                }
                // Ensure standard bin paths are accessible
                let currentPath = env["PATH"] ?? ""
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\(currentPath)"
                process.environment = env

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        stateBox.appendStdout(data)
                    }
                }

                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        stateBox.appendStderr(data)
                    }
                }

                stateBox.setProcess(process)

                process.terminationHandler = { proc in
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    if let remainingOut = try? stdoutPipe.fileHandleForReading.readToEnd(), !remainingOut.isEmpty {
                        stateBox.appendStdout(remainingOut)
                    }
                    if let remainingErr = try? stderrPipe.fileHandleForReading.readToEnd(), !remainingErr.isEmpty {
                        stateBox.appendStderr(remainingErr)
                    }

                    stateBox.finishAndResume(
                        terminationStatus: proc.terminationStatus,
                        continuation: continuation
                    )
                }

                do {
                    try process.run()
                } catch {
                    stateBox.resumeFailure(
                        error: AnimeDubError.runtimeDependencyFailed("Failed to spawn process \(executable): \(error.localizedDescription)"),
                        continuation: continuation
                    )
                }
            }
        } onCancel: {
            stateBox.terminate()
        }
    }
}
