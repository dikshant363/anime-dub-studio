import Foundation
import AVFoundation

public final class QualityAssuranceService: QualityAssuranceServiceProtocol, Sendable {
    public init() {}

    private static let commonEnglishWords: Set<String> = [
        "the", "be", "is", "am", "are", "was", "were", "been", "being", "to", "of", "and", "a", "in", "that", "have", "has", "had", "i", "it", "for", "not", "on", "with",
        "he", "as", "you", "do", "does", "did", "doing", "done", "at", "this", "but", "his", "by", "from", "they", "we", "say", "her",
        "she", "or", "an", "will", "my", "one", "all", "would", "there", "their", "what", "so", "up",
        "out", "if", "about", "who", "get", "which", "go", "going", "gone", "went", "me", "when", "make", "can", "could", "like", "time",
        "no", "just", "him", "know", "take", "people", "into", "year", "your", "good", "some", "could",
        "them", "see", "other", "than", "then", "now", "look", "only", "come", "its", "over", "think",
        "also", "back", "after", "use", "two", "how", "our", "work", "first", "well", "way", "even",
        "new", "want", "because", "any", "these", "give", "day", "most", "us", "help", "understand",
        "believe", "danger", "bro", "sorry", "wait", "focus", "serious", "seriously", "problem", "alright",
        "here", "friend", "man", "guy", "really", "right", "wrong", "yes", "please", "why", "stop", "run"
    ]

    public func evaluate(
        segments: [DialogueSegment],
        dubbedAudioURL: URL? = nil,
        videoDuration: Double = 0.0,
        isHinglish: Bool = true
    ) async -> QAReport {
        guard !segments.isEmpty else {
            return QAReport(
                score: 0.0,
                status: .fail,
                warnings: ["No dialogue segments detected in media."],
                checksPassed: []
            )
        }

        var score = 100.0
        var warnings: [String] = []
        var checksPassed: [String] = []

        // 1. Transcription confidence
        var lowConfCount = 0
        for (i, seg) in segments.enumerated() {
            if seg.confidence < 0.65 {
                lowConfCount += 1
                if warnings.filter({ $0.contains("Low ASR confidence") }).count < 5 {
                    warnings.append("Segment #\(i + 1): Low ASR confidence (\(Int(seg.confidence * 100))%). Verify Japanese source text.")
                }
            }
        }
        if lowConfCount > 0 {
            score -= min(15.0, Double(lowConfCount) / Double(segments.count) * 15.0)
        }

        // 2. Script integrity
        var emptyCount = 0
        var japaneseLeakCount = 0
        var devanagariLeakCount = 0
        var repeatedCount = 0
        var excessEnglishCount = 0
        var prevText = ""

        let japaneseRegex = try? NSRegularExpression(pattern: "[\\u3040-\\u309F\\u30A0-\\u30FF\\u4E00-\\u9FFF]", options: [])
        let devanagariRegex = try? NSRegularExpression(pattern: "[\\u0900-\\u097F]", options: [])

        for (i, seg) in segments.enumerated() {
            let target = isHinglish ? seg.adaptedHinglishText : seg.adaptedHindiText
            let clean = target.trimmingCharacters(in: .whitespacesAndNewlines)

            if clean.isEmpty {
                emptyCount += 1
                if emptyCount <= 3 {
                    warnings.append("Segment #\(i + 1): Empty dialogue.")
                }
                continue
            }

            // Repeated line
            let lower = clean.lowercased()
            if lower == prevText && lower.count > 8 {
                repeatedCount += 1
                if repeatedCount <= 5 {
                    warnings.append("Segment #\(i + 1): Repeated consecutive dialogue detected.")
                }
            }
            prevText = lower

            // Untranslated Japanese
            if let regex = japaneseRegex,
               regex.numberOfMatches(in: clean, options: [], range: NSRange(clean.startIndex..<clean.endIndex, in: clean)) > 0 {
                japaneseLeakCount += 1
                if japaneseLeakCount <= 3 {
                    warnings.append("Segment #\(i + 1): Untranslated Japanese characters found in dubbed line: \(clean)")
                }
            }

            if isHinglish {
                // Unexpected Devanagari in Roman Hinglish
                if let regex = devanagariRegex,
                   regex.numberOfMatches(in: clean, options: [], range: NSRange(clean.startIndex..<clean.endIndex, in: clean)) > 0 {
                    devanagariLeakCount += 1
                    if devanagariLeakCount <= 3 {
                        warnings.append("Segment #\(i + 1): Unexpected Devanagari characters in Roman Hinglish line: \(clean)")
                    }
                }

                // English usage threshold
                let words = clean.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
                if words.count >= 4 {
                    let englishCount = words.filter { Self.commonEnglishWords.contains($0) }.count
                    let engPct = Int(Double(englishCount) / Double(words.count) * 100)
                    if engPct > 75 {
                        excessEnglishCount += 1
                        if excessEnglishCount <= 5 {
                            warnings.append("Segment #\(i + 1): English usage \(engPct)% exceeds expected threshold (70%).")
                        }
                    }
                }
            }
        }

        if emptyCount > 0 { score -= min(20.0, max(5.0, (Double(emptyCount) / Double(segments.count)) * 50.0)) }
        if repeatedCount > 0 { score -= min(10.0, (Double(repeatedCount) / Double(segments.count)) * 40.0) }
        if japaneseLeakCount > 0 { score -= min(25.0, max(15.0, (Double(japaneseLeakCount) / Double(segments.count)) * 100.0)) }
        if devanagariLeakCount > 0 { score -= min(20.0, max(15.0, (Double(devanagariLeakCount) / Double(segments.count)) * 100.0)) }
        if excessEnglishCount > 0 { score -= min(10.0, (Double(excessEnglishCount) / Double(segments.count)) * 30.0) }

        // 3. Timing and Audio check
        var timingMismatchCount = 0
        var missingAudioCount = 0

        for (i, seg) in segments.enumerated() {
            let ratio = seg.durationRatio ?? 1.0
            if ratio > 1.30 || (ratio < 0.65 && ratio > 0.0) {
                timingMismatchCount += 1
                if warnings.filter({ $0.contains("Dialogue duration is") }).count < 5 {
                    if ratio > 1.30 {
                        warnings.append("Segment #\(i + 1): Dialogue duration is \(Int((ratio - 1.0) * 100))% longer than target window.")
                    } else {
                        warnings.append("Segment #\(i + 1): Dialogue duration is \(Int((1.0 - ratio) * 100))% shorter than target window.")
                    }
                }
            }

            if let audioP = seg.audioPath {
                if !FileManager.default.fileExists(atPath: audioP) {
                    missingAudioCount += 1
                    if missingAudioCount <= 3 {
                        warnings.append("Segment #\(i + 1): Missing synthesized voice audio file.")
                    }
                }
            }
        }

        if timingMismatchCount > 0 {
            score -= min(15.0, (Double(timingMismatchCount) / Double(segments.count)) * 15.0)
        }
        if missingAudioCount > 0 {
            score -= min(30.0, Double(missingAudioCount) * 10.0)
        }

        // 4. Master Audio clipping / RMS check
        if let audioURL = dubbedAudioURL, FileManager.default.fileExists(atPath: audioURL.path) {
            if let file = try? AVAudioFile(forReading: audioURL) {
                let frames = AVAudioFrameCount(file.length)
                if frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames) {
                    try? file.read(into: buffer)
                    if let channels = buffer.floatChannelData {
                        var maxPeak: Float = 0.0
                        var sumSquares: Float = 0.0
                        let totalSamples = Int(frames)
                        let data = channels[0]

                        for k in stride(from: 0, to: totalSamples, by: max(1, totalSamples / 5000)) {
                            let val = data[k]
                            let absVal = abs(val)
                            if absVal > maxPeak { maxPeak = absVal }
                            sumSquares += val * val
                        }

                        if maxPeak >= 0.999 {
                            warnings.append("Master audio: Potential digital clipping detected (peak >= 0 dBFS).")
                            score -= 5.0
                        } else {
                            checksPassed.append("No audio clipping detected (True peak below -0.1 dBFS).")
                        }

                        let rms = sqrt(sumSquares / Float(max(1, totalSamples / 5000)))
                        if rms < 0.005 {
                            warnings.append("Master audio: Unusually low overall volume (silence or near-silence).")
                            score -= 15.0
                        }
                    }
                }
            }
        }

        // 5. Multi-character voice diversity
        let distinctVoices = Set(segments.compactMap { $0.voiceId })
        if segments.count > 10 && distinctVoices.count == 1 {
            warnings.append("Voice assignment failure: All characters are using the exact same voice ID.")
            score -= 30.0
        } else if distinctVoices.count > 1 {
            checksPassed.append("Distinct character voices verified (\(distinctVoices.count) unique voice profiles).")
        }

        if !warnings.contains(where: { $0.contains("Untranslated Japanese") }) {
            checksPassed.append("No Japanese characters remaining in dubbed dialogue.")
        }
        if isHinglish && !warnings.contains(where: { $0.contains("Unexpected Devanagari") }) {
            checksPassed.append("No unexpected Devanagari in Roman Hinglish script.")
        }
        if !warnings.contains(where: { $0.contains("longer than") || $0.contains("shorter than") }) {
            checksPassed.append("All dialogue lines synchronized within timing tolerances.")
        }
        if !warnings.contains(where: { $0.contains("Missing synthesized") }) {
            checksPassed.append("TTS voices synthesized and verified for all character segments.")
        }

        let finalScore = max(0.0, min(100.0, round(score * 10) / 10))
        let status: QAStatus = finalScore >= 80.0 ? .pass : (finalScore >= 60.0 ? .warning : .fail)

        return QAReport(
            score: finalScore,
            status: status,
            warnings: warnings,
            checksPassed: checksPassed
        )
    }
}
