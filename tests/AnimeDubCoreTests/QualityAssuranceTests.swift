import Testing
import Foundation
@testable import AnimeDubCore

@Suite("Quality Assurance Tests")
struct QualityAssuranceTests {
    let qaService = QualityAssuranceService()

    @Test("QA rejects empty dialogue segments")
    func testQAEmptySegments() async {
        let report = await qaService.evaluate(segments: [])
        #expect(report.score == 0.0)
        #expect(report.status == .fail)
        #expect(report.warnings.first?.contains("No dialogue segments detected") == true)
    }

    @Test("QA detects untranslated Japanese characters")
    func testQADetectsUntranslatedJapanese() async {
        let seg = DialogueSegment(
            segmentIndex: 0,
            startTime: 0.0,
            endTime: 2.0,
            targetDuration: 2.0,
            adaptedHindiText: "तुम क्या 何をしているんだ？",
            confidence: 0.95
        )
        let report = await qaService.evaluate(segments: [seg], isHinglish: false)
        #expect(report.warnings.contains { $0.contains("Untranslated Japanese characters found") })
        #expect(report.score < 100.0)
    }

    @Test("QA validates clean Hinglish dialogue")
    func testQAValidatesCleanHinglish() async {
        let seg = DialogueSegment(
            segmentIndex: 0,
            startTime: 0.0,
            endTime: 2.0,
            targetDuration: 2.0,
            adaptedHinglishText: "Tum kya kar rahe ho?",
            confidence: 0.95
        )
        let report = await qaService.evaluate(segments: [seg], isHinglish: true)
        #expect(!report.warnings.contains { $0.contains("Unexpected Devanagari") })
        #expect(report.score >= 90.0)
    }

    @Test("QA detects unexpected Devanagari in Roman Hinglish")
    func testQADetectsDevanagariInHinglish() async {
        let seg = DialogueSegment(
            segmentIndex: 0,
            startTime: 0.0,
            endTime: 2.0,
            targetDuration: 2.0,
            adaptedHinglishText: "Tum kya कर रहे हो?",
            confidence: 0.95
        )
        let report = await qaService.evaluate(segments: [seg], isHinglish: true)
        #expect(report.warnings.contains { $0.contains("Unexpected Devanagari characters in Roman Hinglish") })
        #expect(report.score < 90.0)
    }

    @Test("QA detects excessive English usage in Hinglish")
    func testQADetectsExcessiveEnglish() async {
        let seg = DialogueSegment(
            segmentIndex: 0,
            startTime: 0.0,
            endTime: 2.0,
            targetDuration: 2.0,
            adaptedHinglishText: "what are you doing here right now my friend with that problem",
            confidence: 0.95
        )
        let report = await qaService.evaluate(segments: [seg], isHinglish: true)
        #expect(report.warnings.contains { $0.contains("exceeds expected threshold") })
    }
}
