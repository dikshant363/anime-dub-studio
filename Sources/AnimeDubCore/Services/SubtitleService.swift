import Foundation

public final class SubtitleService: SubtitleServiceProtocol, Sendable {
    public init() {}

    public static func formatSRTTime(_ seconds: Double) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int(round((seconds - Double(Int(seconds))) * 1000))
        return String(format: "%02d:%02d:%02d,%03d", hrs, mins, secs, millis)
    }

    public static func formatASSTime(_ seconds: Double) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let centis = Int(round((seconds - Double(Int(seconds))) * 100))
        return String(format: "%d:%02d:%02d.%02d", hrs, mins, secs, centis)
    }

    public func generateSRT(
        segments: [DialogueTimelineSegment],
        to outputURL: URL,
        useHinglish: Bool = true
    ) throws {
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var lines: [String] = []
        for (i, seg) in segments.enumerated() {
            let start = Self.formatSRTTime(seg.startTime)
            let end = Self.formatSRTTime(seg.endTime)
            let text = useHinglish ? seg.adaptedHinglishText : seg.adaptedHindiText

            lines.append("\(i + 1)")
            lines.append("\(start) --> \(end)")
            lines.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        let content = lines.joined(separator: "\n")
        try content.write(to: outputURL, atomically: true, encoding: .utf8)
    }

    public func generateASS(
        segments: [DialogueTimelineSegment],
        to outputURL: URL,
        title: String = "Anime Dub Subtitles",
        useHinglish: Bool = true
    ) throws {
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let header = """
        [Script Info]
        Title: \(title)
        ScriptType: v4.00+
        WrapStyle: 0
        ScaledBorderAndShadow: yes
        YCbCr Matrix: None

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,1,0,0,0,100,100,0,0,1,2,1,2,10,10,20,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

        """

        var events: [String] = []
        for seg in segments {
            let start = Self.formatASSTime(seg.startTime)
            let end = Self.formatASSTime(seg.endTime)
            let text = useHinglish ? seg.adaptedHinglishText : seg.adaptedHindiText
            let actor = seg.speakerLabel.isEmpty ? "Character" : seg.speakerLabel

            events.append("Dialogue: 0,\(start),\(end),Default,\(actor),0,0,0,,\(text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        let fullContent = header + events.joined(separator: "\n") + "\n"
        try fullContent.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
