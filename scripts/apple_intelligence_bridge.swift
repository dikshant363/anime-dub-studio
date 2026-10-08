import Foundation

#if canImport(FoundationModels)
import FoundationModels

struct StatusResponse: Codable {
    let available: Bool
    let provider: String
    let onDevice: Bool
    let reason: String
}

struct PromptResponse: Codable {
    let status: String
    let content: String
    let error: String?
}

@available(macOS 26.0, *)
class AppleIntelligenceBridge {
    static func getStatus() -> StatusResponse {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return StatusResponse(available: true, provider: "Apple Intelligence (FoundationModels)", onDevice: true, reason: "Ready")
        case .unavailable(let reason):
            return StatusResponse(available: false, provider: "Apple Intelligence", onDevice: true, reason: "\(reason)")
        @unknown default:
            return StatusResponse(available: false, provider: "Apple Intelligence", onDevice: true, reason: "Unknown availability")
        }
    }
    
    static func generate(prompt: String, systemPrompt: String?) async -> PromptResponse {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            return PromptResponse(status: "error", content: "", error: "Apple Intelligence is currently unavailable on this device")
        }
        
        let session: LanguageModelSession
        if let system = systemPrompt, !system.isEmpty {
            session = LanguageModelSession(instructions: system)
        } else {
            session = LanguageModelSession()
        }
        
        do {
            let response = try await session.respond(to: prompt)
            return PromptResponse(status: "success", content: response.content.trimmingCharacters(in: .whitespacesAndNewlines), error: nil)
        } catch {
            return PromptResponse(status: "error", content: "", error: error.localizedDescription)
        }
    }
}

func main() {
    let args = CommandLine.arguments
    
    if args.count < 2 || args.contains("--help") {
        print("Usage: apple_intelligence_bridge [--status | --prompt <text> [--system <text>]]")
        exit(0)
    }
    
    if #available(macOS 26.0, *) {
        if args.contains("--status") {
            let status = AppleIntelligenceBridge.getStatus()
            if let data = try? JSONEncoder().encode(status), let str = String(data: data, encoding: .utf8) {
                print(str)
            }
            exit(0)
        }
        
        if let promptIndex = args.firstIndex(of: "--prompt"), promptIndex + 1 < args.count {
            let prompt = args[promptIndex + 1]
            var systemPrompt: String? = nil
            if let sysIndex = args.firstIndex(of: "--system"), sysIndex + 1 < args.count {
                systemPrompt = args[sysIndex + 1]
            }
            
            Task {
                let res = await AppleIntelligenceBridge.generate(prompt: prompt, systemPrompt: systemPrompt)
                if let data = try? JSONEncoder().encode(res), let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
                exit(0)
            }
            dispatchMain()
        }
    } else {
        let res = PromptResponse(status: "error", content: "", error: "Requires macOS 26.0 or later")
        if let data = try? JSONEncoder().encode(res), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
        exit(1)
    }
}

main()
#else
print("{\"available\": false, \"provider\": \"Apple Intelligence\", \"onDevice\": false, \"reason\": \"FoundationModels framework not present\"}")
#endif
