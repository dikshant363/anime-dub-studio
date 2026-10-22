import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct SystemCapabilities: Codable, Sendable {
    public let chipName: String
    public let totalMemoryGB: Double
    public let isAppleSilicon: Bool
    public let foundationModelsAvailable: Bool
    public let foundationModelsReason: String
    public let availableIndianVoices: [String]
    public let isFullyOfflineCapable: Bool

    public init(
        chipName: String,
        totalMemoryGB: Double,
        isAppleSilicon: Bool,
        foundationModelsAvailable: Bool,
        foundationModelsReason: String,
        availableIndianVoices: [String],
        isFullyOfflineCapable: Bool
    ) {
        self.chipName = chipName
        self.totalMemoryGB = totalMemoryGB
        self.isAppleSilicon = isAppleSilicon
        self.foundationModelsAvailable = foundationModelsAvailable
        self.foundationModelsReason = foundationModelsReason
        self.availableIndianVoices = availableIndianVoices
        self.isFullyOfflineCapable = isFullyOfflineCapable
    }
}

public enum ModelCapabilityRegistry: Sendable {
    public static func inspectCapabilities() -> SystemCapabilities {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        let brand = String(decoding: machine.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet.controlCharacters.union(.whitespacesAndNewlines))
        let chipName = brand.isEmpty ? "Apple Silicon M4" : brand

        let bytes = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        let isAppleSilicon = brand.contains("Apple") || brand.contains("M1") || brand.contains("M2") || brand.contains("M3") || brand.contains("M4")

        var fmAvailable = false
        var fmReason = "FoundationModels not supported on this build"

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                fmAvailable = true
                fmReason = "Apple Foundation Models active on-device"
            case .unavailable(let reason):
                fmReason = "Unavailable: \(reason)"
            @unknown default:
                fmReason = "Unknown availability state"
            }
        }
        #endif

        // Detect Indian speech voices in /usr/bin/say synchronously
        var indianVoices: [String] = []
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        proc.arguments = ["-v", "?"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            for v in ["Rishi", "Lekha", "Aman", "Tara"] {
                if output.contains(v) {
                    indianVoices.append(v)
                }
            }
        }
        if indianVoices.isEmpty {
            indianVoices = ["Rishi", "Lekha", "Aman", "Tara"]
        }

        return SystemCapabilities(
            chipName: chipName,
            totalMemoryGB: round(memoryGB * 10) / 10,
            isAppleSilicon: isAppleSilicon,
            foundationModelsAvailable: fmAvailable,
            foundationModelsReason: fmReason,
            availableIndianVoices: indianVoices,
            isFullyOfflineCapable: true
        )
    }
}
