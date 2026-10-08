import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// Data Transfer Objects for JSON IPC
struct ServiceResponse<T: Codable>: Codable {
    let status: String
    let data: T?
    let error: String?
}

struct AvailabilityInfo: Codable {
    let available: Bool
    let provider: String
    let onDevice: Bool
    let reason: String
    let systemModelName: String
}

struct CapabilitiesInfo: Codable {
    let textGeneration: Bool
    let translation: Bool
    let dialogueRewriting: Bool
    let emotionClassification: Bool
    let contextAnalysis: Bool
    let qualityCheck: Bool
    let neuralEngineAccelerated: Bool
}

struct TranslationOutput: Codable {
    let sourceText: String
    let translatedText: String
    let adaptedHindi: String
    let character: String?
    let style: String
    let emotion: String
}

struct EmotionOutput: Codable {
    let primaryEmotion: String
    let intensity: Double
    let suggestedSpeechRate: Double
    let suggestedPitch: Double
}

struct QualityCheckOutput: Codable {
    let score: Double
    let isNaturalDub: Bool
    let hasUntranslatedKanji: Bool
    let critique: String
}

@available(macOS 26.0, *)
class AppleFoundationModelService {
    
    static func checkAvailability() -> AvailabilityInfo {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return AvailabilityInfo(
                available: true,
                provider: "Apple Intelligence (FoundationModels)",
                onDevice: true,
                reason: "Apple Foundation Models are active on-device",
                systemModelName: "Apple SystemLanguageModel"
            )
        case .unavailable(let reason):
            return AvailabilityInfo(
                available: false,
                provider: "Apple Intelligence",
                onDevice: true,
                reason: "Unavailable: \(reason)",
                systemModelName: "None"
            )
        @unknown default:
            return AvailabilityInfo(
                available: false,
                provider: "Apple Intelligence",
                onDevice: true,
                reason: "Unknown availability state",
                systemModelName: "None"
            )
        }
        #else
        return AvailabilityInfo(
            available: false,
            provider: "Apple Intelligence",
            onDevice: false,
            reason: "FoundationModels framework not present in this OS build",
            systemModelName: "None"
        )
        #endif
    }

    static func getCapabilities() -> CapabilitiesInfo {
        let isAvail = checkAvailability().available
        return CapabilitiesInfo(
            textGeneration: isAvail,
            translation: isAvail,
            dialogueRewriting: isAvail,
            emotionClassification: isAvail,
            contextAnalysis: isAvail,
            qualityCheck: isAvail,
            neuralEngineAccelerated: true
        )
    }

    static func getSupportedLanguages() -> [String] {
        return ["ja", "hi", "en", "ko", "zh", "fr", "de", "es", "it", "pt"]
    }

    #if canImport(FoundationModels)
    static func generateText(prompt: String, systemPrompt: String?) async throws -> String {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw NSError(domain: "AppleFoundationModelService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model unavailable"])
        }
        let session = (systemPrompt != nil && !systemPrompt!.isEmpty) ? LanguageModelSession(instructions: systemPrompt!) : LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func translate(text: String, sourceLang: String, targetLang: String, characterName: String?, style: String) async throws -> TranslationOutput {
        let systemPrompt = """
        You are an elite anime dubbing localization director.
        Translate the input \(sourceLang) dialogue line into natural, punchy \(targetLang) dub dialogue in Devanagari script.
        Avoid stiff, bookish, or literal translation. Ensure it sounds like professional Indian anime dubbing.
        Character: \(characterName ?? "Lead Character"). Style: \(style).
        Output ONLY the localized dialogue in Devanagari script. No quotes, no explanations.
        """
        let prompt = "Source Dialogue (\(sourceLang)): \(text)\nTranslate to natural spoken \(targetLang) dub:"
        let result = try await generateText(prompt: prompt, systemPrompt: systemPrompt)

        var clean = result.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["Hindi:", "हिंदी:", "Dub:", "अनुवाद:"] {
            if clean.hasPrefix(prefix) {
                clean = String(clean.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return TranslationOutput(
            sourceText: text,
            translatedText: clean,
            adaptedHindi: clean,
            character: characterName,
            style: style,
            emotion: "neutral"
        )
    }

    static func rewriteDialogue(text: String, currentDuration: Double, targetDuration: Double) async throws -> String {
        let ratio = currentDuration / max(0.1, targetDuration)
        if ratio <= 1.10 {
            return text
        }
        let systemPrompt = """
        You are a dub dialogue timing editor.
        The current Hindi dialogue line takes too long to speak and exceeds the mouth flaps window by \(Int((ratio - 1.0) * 100))%.
        Rewrite the Hindi dialogue in Devanagari using colloquial contractions or concise phrasing while strictly preserving the emotional meaning and intent.
        Output ONLY the shortened Devanagari Hindi text.
        """
        let prompt = "Original Dialogue: \(text)\nShortened Dialogue:"
        let shortened = try await generateText(prompt: prompt, systemPrompt: systemPrompt)
        return shortened.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func classifyEmotion(text: String) async throws -> EmotionOutput {
        let systemPrompt = """
        Classify the primary emotion of this anime dialogue line.
        Choices: neutral, happy, sad, angry, fear, surprise, excited, whisper, shout.
        Respond with: <emotion>,<intensity between 0.1 and 1.0>
        """
        let res = try await generateText(prompt: text, systemPrompt: systemPrompt)
        let parts = res.split(separator: ",")
        let emotion = parts.first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "neutral"
        let intensity = parts.count > 1 ? (Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.7) : 0.7

        var rate = 1.0
        var pitch = 0.0
        if emotion == "excited" || emotion == "angry" || emotion == "shout" {
            rate = 1.05
            pitch = 4.0
        } else if emotion == "sad" || emotion == "whisper" {
            rate = 0.95
            pitch = -3.0
        }

        return EmotionOutput(primaryEmotion: emotion, intensity: intensity, suggestedSpeechRate: rate, suggestedPitch: pitch)
    }

    static func qualityCheck(originalJa: String, translatedHi: String) async throws -> QualityCheckOutput {
        let systemPrompt = """
        Evaluate this Hindi anime dub line for naturalness, cultural fit, and Devanagari accuracy.
        Original Japanese: \(originalJa)
        Translated Hindi: \(translatedHi)
        Respond with: <score 0-100> | <critique>
        """
        let res = try await generateText(prompt: "Review line", systemPrompt: systemPrompt)
        let parts = res.split(separator: "|")
        let score = parts.first.flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 95.0
        let critique = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : "Natural dialogue"

        return QualityCheckOutput(
            score: score,
            isNaturalDub: score >= 80.0,
            hasUntranslatedKanji: false,
            critique: critique
        )
    }
    #endif
}

func printJSON<T: Codable>(_ response: ServiceResponse<T>) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(response), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

func main() {
    let args = CommandLine.arguments
    if args.count < 2 {
        print("Usage: AppleFoundationModelService <action> [options]")
        exit(1)
    }

    let action = args[1]

    if #available(macOS 26.0, *) {
        switch action {
        case "availability":
            let info = AppleFoundationModelService.checkAvailability()
            printJSON(ServiceResponse(status: "success", data: info, error: nil))
            exit(0)

        case "capabilities":
            let caps = AppleFoundationModelService.getCapabilities()
            printJSON(ServiceResponse(status: "success", data: caps, error: nil))
            exit(0)

        case "languages":
            let langs = AppleFoundationModelService.getSupportedLanguages()
            printJSON(ServiceResponse(status: "success", data: langs, error: nil))
            exit(0)

        case "translate":
            var text = ""
            var sourceLang = "ja"
            var targetLang = "hi"
            var character: String? = nil
            var style = "natural_anime"

            var i = 2
            while i < args.count {
                if args[i] == "--text" && i + 1 < args.count { text = args[i+1]; i += 2; continue }
                if args[i] == "--source" && i + 1 < args.count { sourceLang = args[i+1]; i += 2; continue }
                if args[i] == "--target" && i + 1 < args.count { targetLang = args[i+1]; i += 2; continue }
                if args[i] == "--character" && i + 1 < args.count { character = args[i+1]; i += 2; continue }
                if args[i] == "--style" && i + 1 < args.count { style = args[i+1]; i += 2; continue }
                i += 1
            }

            #if canImport(FoundationModels)
            Task {
                do {
                    let out = try await AppleFoundationModelService.translate(
                        text: text,
                        sourceLang: sourceLang,
                        targetLang: targetLang,
                        characterName: character,
                        style: style
                    )
                    printJSON(ServiceResponse(status: "success", data: out, error: nil))
                    exit(0)
                } catch {
                    printJSON(ServiceResponse<TranslationOutput>(status: "error", data: nil, error: error.localizedDescription))
                    exit(1)
                }
            }
            dispatchMain()
            #else
            printJSON(ServiceResponse<TranslationOutput>(status: "error", data: nil, error: "FoundationModels unavailable"))
            exit(1)
            #endif

        case "classify_emotion":
            let text = args.count > 2 ? args[2] : ""
            #if canImport(FoundationModels)
            Task {
                do {
                    let emo = try await AppleFoundationModelService.classifyEmotion(text: text)
                    printJSON(ServiceResponse(status: "success", data: emo, error: nil))
                    exit(0)
                } catch {
                    printJSON(ServiceResponse<EmotionOutput>(status: "error", data: nil, error: error.localizedDescription))
                    exit(1)
                }
            }
            dispatchMain()
            #else
            printJSON(ServiceResponse<EmotionOutput>(status: "error", data: nil, error: "FoundationModels unavailable"))
            exit(1)
            #endif

        case "quality_check":
            let ja = args.count > 2 ? args[2] : ""
            let hi = args.count > 3 ? args[3] : ""
            #if canImport(FoundationModels)
            Task {
                do {
                    let qc = try await AppleFoundationModelService.qualityCheck(originalJa: ja, translatedHi: hi)
                    printJSON(ServiceResponse(status: "success", data: qc, error: nil))
                    exit(0)
                } catch {
                    printJSON(ServiceResponse<QualityCheckOutput>(status: "error", data: nil, error: error.localizedDescription))
                    exit(1)
                }
            }
            dispatchMain()
            #else
            printJSON(ServiceResponse<QualityCheckOutput>(status: "error", data: nil, error: "FoundationModels unavailable"))
            exit(1)
            #endif

        default:
            print("Unknown action: \(action)")
            exit(1)
        }
    } else {
        printJSON(ServiceResponse<String>(status: "error", data: nil, error: "Requires macOS 26.0+"))
        exit(1)
    }
}

main()
