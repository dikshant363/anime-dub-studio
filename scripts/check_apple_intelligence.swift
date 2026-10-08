import Foundation

#if canImport(FoundationModels)
import FoundationModels

print("FoundationModels framework is available on this system.")
if #available(macOS 26.0, *) {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        print("APPLE_INTELLIGENCE_STATUS: AVAILABLE")
    case .unavailable(let reason):
        print("APPLE_INTELLIGENCE_STATUS: UNAVAILABLE - \(reason)")
    @unknown default:
        print("APPLE_INTELLIGENCE_STATUS: UNKNOWN")
    }
} else {
    print("APPLE_INTELLIGENCE_STATUS: REQUIRES_MACOS_26")
}
#else
print("FoundationModels framework is NOT available on this system.")
print("APPLE_INTELLIGENCE_STATUS: NOT_INSTALLED")
#endif
