import Testing
import Foundation
@testable import AnimeDubCore

@Suite("Hindi Adaptation Tests")
struct HindiAdaptationTests {
    let service = HindiAdaptationService()

    @Test("Colloquial anime dub conversion")
    func testColloquialConversion() {
        let stiff = "तुम किस चीज़ को कर रहे हो?"
        let natural = service.polishHindi(stiff)
        #expect(natural.contains("तुम क्या कर रहे हो?"))
    }

    @Test("Punctuation normalization with danda")
    func testPunctuationNormalization() {
        let line = "चलो जल्दी करो"
        let polished = service.polishHindi(line)
        #expect(polished.hasSuffix("।"))
    }

    @Test("Duration compression for rapid speech")
    func testDurationCompression() {
        let longLine = "तुम क्या कर रहे हो"
        // When duration ratio exceeds 1.15, compress syllable count
        let compressed = service.compressForDuration(longLine, durationRatio: 1.25)
        #expect(compressed == "क्या कर रहे हो")

        // When ratio is under tolerance, do not compress
        let untouched = service.compressForDuration(longLine, durationRatio: 1.05)
        #expect(untouched == longLine)
    }
}
