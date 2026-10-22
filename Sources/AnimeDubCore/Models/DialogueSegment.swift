import Foundation

public struct DialogueSegment: Codable, Identifiable, Sendable {
    public var id: Int { segmentIndex }
    public var segmentIndex: Int
    public var startTime: Double
    public var endTime: Double
    public var targetDuration: Double
    public var speakerLabel: String
    public var characterName: String
    public var sourceText: String
    public var translatedText: String
    public var adaptedHindiText: String
    public var adaptedHinglishText: String
    public var ttsPronunciationText: String
    public var confidence: Double
    public var audioPath: String?
    public var synthesizedDuration: Double?
    public var durationRatio: Double?
    public var voiceId: String?
    public var status: String

    public init(
        segmentIndex: Int,
        startTime: Double,
        endTime: Double,
        targetDuration: Double,
        speakerLabel: String = "SPEAKER_00",
        characterName: String = "Character",
        sourceText: String = "",
        translatedText: String = "",
        adaptedHindiText: String = "",
        adaptedHinglishText: String = "",
        ttsPronunciationText: String = "",
        confidence: Double = 0.95,
        audioPath: String? = nil,
        synthesizedDuration: Double? = nil,
        durationRatio: Double? = nil,
        voiceId: String? = nil,
        status: String = "PENDING"
    ) {
        self.segmentIndex = segmentIndex
        self.startTime = startTime
        self.endTime = endTime
        self.targetDuration = targetDuration
        self.speakerLabel = speakerLabel
        self.characterName = characterName
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.adaptedHindiText = adaptedHindiText
        self.adaptedHinglishText = adaptedHinglishText
        self.ttsPronunciationText = ttsPronunciationText
        self.confidence = confidence
        self.audioPath = audioPath
        self.synthesizedDuration = synthesizedDuration
        self.durationRatio = durationRatio
        self.voiceId = voiceId
        self.status = status
    }
}
