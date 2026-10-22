import Testing
import Foundation
@testable import AnimeDubCore

@Suite("Dialogue Timing & Subtitle Tests")
struct DialogueTimingAndSubtitleTests {
    @Test("SRT and ASS timestamp formatting")
    func testTimestampFormatting() {
        let srtTime = SubtitleService.formatSRTTime(65.432)
        #expect(srtTime == "00:01:05,432")

        let assTime = SubtitleService.formatASSTime(65.432)
        #expect(assTime == "0:01:05.43")
    }

    @Test("SRT file generation")
    func testSRTGeneration() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).srt")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let segments = [
            DialogueTimelineSegment(
                startTime: 0.0,
                endTime: 2.0,
                audioURL: URL(fileURLWithPath: "/tmp/fake.wav"),
                adaptedHindiText: "तुम क्या कर रहे हो?",
                adaptedHinglishText: "Tum kya kar rahe ho?",
                speakerLabel: "Lead Protagonist"
            )
        ]

        let service = SubtitleService()
        try service.generateSRT(segments: segments, to: tempFile, useHinglish: true)

        let content = try String(contentsOf: tempFile, encoding: .utf8)
        #expect(content.contains("00:00:00,000 --> 00:00:02,000"))
        #expect(content.contains("Tum kya kar rahe ho?"))
    }
}
