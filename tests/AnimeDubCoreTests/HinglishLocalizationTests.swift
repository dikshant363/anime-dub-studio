import Testing
import Foundation
@testable import AnimeDubCore

@Suite("Hinglish Localization Tests")
struct HinglishLocalizationTests {
    let service = HinglishLocalizationService()

    @Test("Canonical phrases localized to Roman Hinglish")
    func testCanonicalPhrases() {
        // Canonical 1: 何をしているんだ？ -> तुम क्या कर रहे हो? -> Tum kya kar rahe ho?
        let hgl1 = service.toHinglish(hindiText: "तुम क्या कर रहे हो?", mixingLevel: .low)
        #expect(hgl1.contains("Tum kya kar rahe ho?"))

        // Canonical 2: 早く行こう！ -> जल्दी चलो! -> Jaldi chalo!
        let hgl2 = service.toHinglish(hindiText: "जल्दी चलो!", mixingLevel: .low)
        #expect(hgl2.contains("Jaldi chalo!"))

        // Canonical 3: 信じられない！ -> मुझे यकीन नहीं हो रहा! -> Mujhe yakeen nahi ho raha!
        let hgl3 = service.toHinglish(hindiText: "मुझे यकीन नहीं हो रहा!", mixingLevel: .low)
        #expect(hgl3.contains("Mujhe yakeen nahi ho raha!"))
    }

    @Test("Roman script guarantee: Zero Devanagari glyphs in output")
    func testRomanScriptGuarantee() {
        let hi = "मुझे यकीन नहीं हो रहा! जल्दी चलो तुम क्या कर रहे हो?"
        let hgl = service.toHinglish(hindiText: hi, mixingLevel: .medium)

        let devanagariRegex = try? NSRegularExpression(pattern: "[\\u0900-\\u097F]", options: [])
        let matchCount = devanagariRegex?.numberOfMatches(in: hgl, options: [], range: NSRange(hgl.startIndex..<hgl.endIndex, in: hgl)) ?? 0
        #expect(matchCount == 0, "Devanagari characters found in Roman Hinglish output: \(hgl)")
    }

    @Test("English mixing levels modulate natural loanwords")
    func testEnglishMixingLevels() {
        let hi = "मुझे यकीन नहीं हो रहा!"

        // Low mixing: Keep native Hindi in Latin characters
        let low = service.toHinglish(hindiText: hi, mixingLevel: .low)
        #expect(low.lowercased().contains("yakeen"))

        // Medium mixing: Natural urban loanword 'believe'
        let medium = service.toHinglish(hindiText: hi, mixingLevel: .medium)
        #expect(medium.lowercased().contains("believe"))

        // High mixing: High intensity loanword 'help'
        let high = service.toHinglish(hindiText: "मेरी मदद करो!", mixingLevel: .high)
        #expect(high.lowercased().contains("help"))
    }

    @Test("TTS pronunciation representation retains Devanagari prosody")
    func testTTSPronunciationRepresentation() {
        let hinglish = "Mujhe believe nahi ho raha!"
        let devanagari = "मुझे यकीन नहीं हो रहा!"
        let pronunciation = service.createTTSPronunciation(hinglishText: hinglish, hindiDevanagari: devanagari)

        #expect(pronunciation.contains("believe"))
        #expect(pronunciation.contains("नहीं हो रहा"))
    }
}
