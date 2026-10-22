import Foundation

public final class HinglishLocalizationService: HinglishLocalizationServiceProtocol, Sendable {
    public init() {}

    public static let devToHinglishVocab: [String: String] = [
        "तुम": "tum",
        "आप": "aap",
        "तू": "tu",
        "मैं": "main",
        "हम": "hum",
        "मुझे": "mujhe",
        "मुझको": "mujhko",
        "तुझे": "tujhe",
        "तुम्हें": "tumhe",
        "आपको": "aapko",
        "हमें": "humein",
        "क्या": "kya",
        "कर": "kar",
        "रहे": "rahe",
        "रहा": "raha",
        "रही": "rahi",
        "हो": "ho",
        "है": "hai",
        "हैं": "hain",
        "था": "tha",
        "थी": "thi",
        "थे": "the",
        "जल्दी": "jaldi",
        "चलो": "chalo",
        "चलें": "chalein",
        "जाओ": "jao",
        "जाना": "jaana",
        "रुक": "ruk",
        "रुको": "ruko",
        "सुनो": "suno",
        "देख": "dekh",
        "देखो": "dekho",
        "समझ": "samajh",
        "यकीन": "yakeen",
        "विश्वास": "vishwas",
        "नामुमकिन": "namumkin",
        "मुमकिन": "mumkin",
        "मदद": "madad",
        "सहायता": "sahayata",
        "खत्म": "khatam",
        "मार": "maar",
        "माफ": "maaf",
        "अलविदा": "alvida",
        "शुक्रिया": "shukriya",
        "धन्यवाद": "dhanyawad",
        "नमस्ते": "namaste",
        "हाँ": "haan",
        "नहीं": "nahi",
        "मत": "mat",
        "कभी": "kabhi",
        "हमेशा": "hamesha",
        "कौन": "kaun",
        "कहाँ": "kahan",
        "कैसे": "kaise",
        "क्यों": "kyun",
        "कब": "kab",
        "यहाँ": "yahan",
        "वहाँ": "wahan",
        "यह": "yeh",
        "ये": "ye",
        "वह": "woh",
        "वो": "wo",
        "बात": "baat",
        "चीज": "cheez",
        "दोस्त": "dost",
        "यार": "yaar",
        "भाई": "bhai",
        "ताकतवर": "takatwar",
        "शक्तिशाली": "shaktishali",
        "सावधान": "savdhaan",
        "डर": "dar",
        "हिम्मत": "himmat",
        "सच": "sach",
        "झूठ": "jhooth",
        "सब": "sab",
        "ठीक": "theek",
        "अच्छा": "achha",
        "बुरा": "bura",
        "खतरा": "khatra",
        "आगे": "aage",
        "पीछे": "peeche",
        "ऊपर": "upar",
        "नीचे": "neeche",
        "साथ": "saath",
        "पास": "paas",
        "दूर": "door",
        "बचाओ": "bachao",
        "रोक": "rok",
        "रोको": "roko",
        "छोड़ो": "chhoro",
        "पकड़ो": "pakdo",
        "आ": "aa",
        "आओ": "aao",
        "आया": "aaya",
        "गया": "gaya",
        "गए": "gaye",
        "गई": "gayi",
        "ले": "le",
        "लो": "lo",
        "दे": "de",
        "दो": "do",
        "बोल": "bol",
        "बोलो": "bolo",
        "कह": "kah",
        "कहा": "kaha",
    ]

    private static let phraseMappings: [(pattern: String, replacement: String)] = [
        ("तुम क्या कर रहे हो\\??", "Tum kya kar rahe ho?"),
        ("क्या कर रहे हो\\??", "Kya kar rahe ho?"),
        ("जल्दी चलो!?", "Jaldi chalo!"),
        ("जल्दी जाओ!?", "Jaldi jao!"),
        ("चलो चलें!?", "Chalo chalein!"),
        ("मुझे यकीन नहीं हो रहा!?", "Mujhe yakeen nahi ho raha!"),
        ("मुझे समझ नहीं आ रहा!?", "Mujhe samajh nahi aa raha!"),
        ("कौन हो तुम\\??", "Kaun ho tum?"),
        ("कौन है वहाँ\\??", "Kaun hai wahan?"),
        ("तुझे खत्म कर दूँगा!?", "Tujhe khatam kar doonga!"),
        ("यह नामुमकिन है!?", "Yeh namumkin hai!"),
        ("मेरी मदद करो!?", "Meri madad karo!"),
        ("सब ठीक तो है ना\\??", "Sab theek toh hai na?"),
        ("शुक्रिया!?", "Shukriya!"),
        ("अलविदा!?", "Alvida!"),
        ("रुको जरा!?", "Ruko zara!")
    ]

    private static let vowels: [Character: String] = [
        "अ": "a", "आ": "aa", "इ": "i", "ई": "ee", "उ": "u", "ऊ": "oo",
        "ए": "e", "ऐ": "ai", "ओ": "o", "औ": "au", "ऋ": "ri",
        "ऑ": "o", "ॲ": "a",
        "ं": "n", "ँ": "n", "ः": "h"
    ]

    private static let matras: [Character: String] = [
        "ा": "a", "ि": "i", "ी": "ee", "ु": "u", "ू": "oo",
        "े": "e", "ै": "ai", "ो": "o", "ौ": "au", "ृ": "ri",
        "ॉ": "o", "ॅ": "e",
        "ं": "n", "ँ": "n", "्": ""
    ]

    private static let consonants: [Character: String] = [
        "क": "k", "ख": "kh", "ग": "g", "घ": "gh", "ङ": "ng",
        "च": "ch", "छ": "chh", "ज": "j", "झ": "jh", "ञ": "ny",
        "ट": "t", "ठ": "th", "ड": "d", "ढ": "dh", "ण": "n",
        "त": "t", "थ": "th", "द": "d", "ध": "dh", "न": "n",
        "प": "p", "फ": "ph", "ब": "b", "भ": "bh", "म": "m",
        "य": "y", "र": "r", "ल": "l", "व": "v", "श": "sh",
        "ष": "sh", "स": "s", "ह": "h", "ड़": "d", "ढ़": "dh",
        "फ़": "f", "ज़": "z", "क़": "q", "ख़": "kh", "ग़": "gh"
    ]

    public static func romanizeDevanagari(_ text: String) -> String {
        var res = ""
        let chars = Array(text)
        var i = 0
        let n = chars.count

        while i < n {
            let ch = chars[i]
            if let v = vowels[ch] {
                res += v
            } else if let m = matras[ch] {
                res += m
            } else if let c = consonants[ch] {
                if i + 1 < n, let nextM = matras[chars[i + 1]] {
                    res += c + nextM
                    i += 1
                } else if i + 1 < n, chars[i + 1] == "्" {
                    res += c
                    i += 1
                } else {
                    if i + 1 < n, (chars[i + 1].isLetter || consonants[chars[i + 1]] != nil) {
                        res += c + "a"
                    } else {
                        res += c
                    }
                }
            } else if ch == "।" || ch == "|" {
                res += "."
            } else {
                res.append(ch)
            }
            i += 1
        }

        // Clean any stubborn Devanagari codepoints (U+0900 to U+097F)
        if let regex = try? NSRegularExpression(pattern: "[\\u0900-\\u097F]", options: []) {
            let range = NSRange(res.startIndex..<res.endIndex, in: res)
            res = regex.stringByReplacingMatches(in: res, options: [], range: range, withTemplate: "")
        }
        return res
    }

    public func toHinglish(
        hindiText: String,
        characterStyle: String? = nil,
        translationStyle: TranslationStyle = .naturalAnime,
        mixingLevel: HinglishMixingLevel = .medium
    ) -> String {
        var text = hindiText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Match known high-frequency anime phrases
        for (pattern, replacement) in Self.phraseMappings {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
            }
        }

        // 2. Token-level dictionary replacement
        let words = text.split(separator: " ")
        var convertedWords: [String] = []

        let devanagariRegex = try? NSRegularExpression(pattern: "[\\u0900-\\u097F]", options: [])

        for w in words {
            let wordStr = String(w)
            // Strip punctuation for lookup
            let clean = wordStr.components(separatedBy: CharacterSet.punctuationCharacters).joined()
            let punct = wordStr.replacingOccurrences(of: clean, with: "")

            if let roman = Self.devToHinglishVocab[clean] {
                convertedWords.append(roman + punct)
            } else if let regex = devanagariRegex,
                      regex.numberOfMatches(in: clean, options: [], range: NSRange(clean.startIndex..<clean.endIndex, in: clean)) > 0 {
                let roman = Self.romanizeDevanagari(clean)
                convertedWords.append(roman + punct)
            } else {
                convertedWords.append(wordStr)
            }
        }

        var result = convertedWords.joined(separator: " ")

        // 3. Final safety sweep: transliterate any lingering Devanagari glyphs
        if let regex = devanagariRegex,
           regex.numberOfMatches(in: result, options: [], range: NSRange(result.startIndex..<result.endIndex, in: result)) > 0 {
            result = Self.romanizeDevanagari(result)
        }

        // 4. Strip any lingering Japanese glyphs (Kanji / Kana)
        if let regex = try? NSRegularExpression(pattern: "[\\u3040-\\u309F\\u30A0-\\u30FF\\u4E00-\\u9FFF]", options: []) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if result.isEmpty || result.count < 2 {
            result = "Tum kya bol rahe ho?"
        }

        // Capitalize first letter of sentences
        result = capitalizeSentences(result)

        // 5. Apply English mixing and character personality
        return applyStyleAndMixing(
            hinglish: result,
            characterStyle: characterStyle,
            translationStyle: translationStyle,
            mixingLevel: mixingLevel
        )
    }

    private func capitalizeSentences(_ text: String) -> String {
        var res = text
        if let first = res.first, first.isLowercase {
            res = String(first.uppercased()) + res.dropFirst()
        }
        return res
    }

    private func applyStyleAndMixing(
        hinglish: String,
        characterStyle: String?,
        translationStyle: TranslationStyle,
        mixingLevel: HinglishMixingLevel
    ) -> String {
        var res = hinglish

        let mediumReplacements: [(pattern: String, replacement: String)] = [
            ("\\bmadad\\b", "help"),
            ("\\byakeen\\b", "believe"),
            ("\\bsamajh nahi\\b", "understand nahi"),
            ("\\bkhatra\\b", "danger"),
            ("\\btheek\\b", "fine")
        ]

        let highReplacements: [(pattern: String, replacement: String)] = [
            ("\\bmadad\\b", "help"),
            ("\\byakeen\\b", "believe"),
            ("\\bsamajh nahi aa raha\\b", "seriously understand nahi kar paa raha"),
            ("\\bkhatra\\b", "danger"),
            ("\\btakatwar\\b", "powerful"),
            ("\\btheek\\b", "alright"),
            ("\\bshukriya\\b", "thank you")
        ]

        if mixingLevel == .medium {
            for (pat, rep) in mediumReplacements {
                if res.count > 15 {
                    if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                        let range = NSRange(res.startIndex..<res.endIndex, in: res)
                        res = regex.stringByReplacingMatches(in: res, options: [], range: range, withTemplate: rep)
                    }
                }
            }
        } else if mixingLevel == .high {
            for (pat, rep) in highReplacements {
                if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                    let range = NSRange(res.startIndex..<res.endIndex, in: res)
                    res = regex.stringByReplacingMatches(in: res, options: [], range: range, withTemplate: rep)
                }
            }
        }

        // Character style touches
        let style = (characterStyle ?? "").lowercased()
        if style == "formal" {
            res = res.replacingOccurrences(of: "\\btum\\b", with: "aap", options: .regularExpression)
            res = res.replacingOccurrences(of: "\\btujhe\\b", with: "aapko", options: .regularExpression)
        } else if style == "aggressive" {
            if !res.hasSuffix("!") {
                res = res.trimmingCharacters(in: CharacterSet(charactersIn: ".")) + "!"
            }
        }

        if !res.hasSuffix(".") && !res.hasSuffix("!") && !res.hasSuffix("?") {
            res += "."
        }

        return res
    }

    public func createTTSPronunciation(hinglishText: String, hindiDevanagari: String) -> String {
        let englishLoanwords: Set<String> = [
            "help", "understand", "believe", "danger", "powerful", "alright", "thank you",
            "bro", "sorry", "wait", "focus", "serious", "seriously", "problem"
        ]

        let words = hinglishText.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let contained = words.map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { englishLoanwords.contains($0) }

        if contained.isEmpty {
            return hindiDevanagari
        }

        var pronunciation = hindiDevanagari
        for loan in contained {
            if loan == "help" {
                pronunciation = pronunciation.replacingOccurrences(of: "मदद", with: "help")
            } else if loan == "understand" {
                pronunciation = pronunciation.replacingOccurrences(of: "समझ", with: "understand")
            } else if loan == "believe" {
                pronunciation = pronunciation.replacingOccurrences(of: "यकीन", with: "believe")
            } else if loan == "danger" {
                pronunciation = pronunciation.replacingOccurrences(of: "खतरा", with: "danger")
            }
        }

        return pronunciation
    }
}
