import Foundation

public final class HindiAdaptationService: HindiAdaptationServiceProtocol, Sendable {
    public init() {}

    private static let colloquialReplacements: [(pattern: String, replacement: String)] = [
        ("तुम किस चीज़ को कर रहे हो\\??", "तुम क्या कर रहे हो?"),
        ("आप क्या कर रहे हैं\\??", "तुम क्या कर रहे हो?"),
        ("मैं तुम्हें समाप्त कर दूंगा", "तुझे खत्म कर दूँगा मैं!"),
        ("यह असंभव प्रतीत होता है", "यह नामुमकिन है!"),
        ("कृपया मेरी सहायता करें", "मेरी मदद करो!"),
        ("मुझे इस पर विश्वास नहीं है", "मुझे यकीन नहीं हो रहा!"),
        ("हमको प्रस्थान करना चाहिए", "अब चलना चाहिए!"),
        ("वह बहुत शक्तिशाली प्राणी है", "वो बहुत ताकतवर है!"),
        ("क्या आप ठीक हैं\\??", "सब ठीक तो है ना?"),
    ]

    private static let compactReplacements: [(pattern: String, replacement: String)] = [
        ("तुम क्या कर रहे हो", "क्या कर रहे हो"),
        ("मुझे समझ नहीं आ रहा है", "समझ नहीं आ रहा"),
        ("मुझे यकीन नहीं हो रहा है", "यकीन नहीं हो रहा"),
        ("मैं ऐसा नहीं कर सकता हूँ", "मैं ऐसा नहीं कर सकता"),
        ("हमको आगे बढ़ना होगा", "आगे बढ़ो"),
        ("कृपया शांत हो जाइए", "शांत रहो"),
    ]

    public func polishHindi(_ text: String, characterStyle: String? = nil) -> String {
        var polished = text.trimmingCharacters(in: .whitespacesAndNewlines)

        for (pattern, replacement) in Self.colloquialReplacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(polished.startIndex..<polished.endIndex, in: polished)
                polished = regex.stringByReplacingMatches(in: polished, options: [], range: range, withTemplate: replacement)
            }
        }

        // Strip any residual Japanese characters
        if let regex = try? NSRegularExpression(pattern: "[\\u3040-\\u309F\\u30A0-\\u30FF\\u4E00-\\u9FFF]", options: []) {
            let range = NSRange(polished.startIndex..<polished.endIndex, in: polished)
            polished = regex.stringByReplacingMatches(in: polished, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if polished.isEmpty || polished.count < 2 {
            polished = "तुम क्या कह रहे हो?"
        }

        // Normalize Hindi punctuation (ensure proper danda '।' or question mark '?')
        if !polished.hasSuffix("?") && !polished.hasSuffix("!") && !polished.hasSuffix("।") && !polished.hasSuffix(".") {
            polished += "।"
        }

        return polished
    }

    public func compressForDuration(_ text: String, durationRatio: Double) -> String {
        if durationRatio <= 1.15 {
            return text
        }

        var compressed = text
        for (pattern, replacement) in Self.compactReplacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(compressed.startIndex..<compressed.endIndex, in: compressed)
                compressed = regex.stringByReplacingMatches(in: compressed, options: [], range: range, withTemplate: replacement)
            }
        }
        return compressed
    }
}
