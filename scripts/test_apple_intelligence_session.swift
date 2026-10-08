import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
func runPrompt() async {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        let session = LanguageModelSession()
        do {
            let response = try await session.respond(to: "Translate to natural Hindi: 何をしているんだ？ Output only the Hindi translation.")
            print("APPLE_INTELLIGENCE_OUTPUT:")
            print(response.content)
        } catch {
            print("ERROR: \(error.localizedDescription)")
        }
    case .unavailable(let reason):
        print("UNAVAILABLE: \(reason)")
    @unknown default:
        print("UNKNOWN")
    }
}

if #available(macOS 26.0, *) {
    Task {
        await runPrompt()
        exit(0)
    }
    dispatchMain()
} else {
    print("Requires macOS 26+")
}
#endif
