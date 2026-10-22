import Foundation

public struct CharacterProfile: Codable, Identifiable, Sendable {
    public var id: String { speakerTag }
    public var speakerTag: String
    public var name: String
    public var voiceId: String
    public var gender: String
    public var personality: String
    public var speakingStyle: String
    public var speedRate: Double
    public var pitchPercent: Double
    public var originalPitchF0: Double?
    public var spectralCentroid: Double?
    public var speakerSimilarity: Double
    public var targetNaturalness: Double
    public var accentMode: AccentPreservationMode
    public var providerId: String
    public var referenceAudioPath: String?
    public var referenceProvenance: String?
    public var assignmentConfidence: Double?
    public var measuredPitchF0: Double?
    public var measuredDurationSeconds: Double?
    public var pronunciationNotes: String?
    public var createdAt: Date
    public var lastModifiedAt: Date
    public var engineCompatibility: String

    public init(
        speakerTag: String,
        name: String,
        voiceId: String,
        gender: String = "male",
        personality: String = "natural",
        speakingStyle: String = "casual",
        speedRate: Double = 1.0,
        pitchPercent: Double = 0.0,
        originalPitchF0: Double? = nil,
        spectralCentroid: Double? = nil,
        speakerSimilarity: Double = 80.0,
        targetNaturalness: Double = 85.0,
        accentMode: AccentPreservationMode = .balanced,
        providerId: String = "mac_native",
        referenceAudioPath: String? = nil,
        referenceProvenance: String? = nil,
        assignmentConfidence: Double? = nil,
        measuredPitchF0: Double? = nil,
        measuredDurationSeconds: Double? = nil,
        pronunciationNotes: String? = nil,
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date(),
        engineCompatibility: String = "macOS Native Speech 14+"
    ) {
        self.speakerTag = speakerTag
        self.name = name
        self.voiceId = voiceId
        self.gender = gender
        self.personality = personality
        self.speakingStyle = speakingStyle
        self.speedRate = speedRate
        self.pitchPercent = pitchPercent
        self.originalPitchF0 = originalPitchF0
        self.spectralCentroid = spectralCentroid
        self.speakerSimilarity = speakerSimilarity
        self.targetNaturalness = targetNaturalness
        self.accentMode = accentMode
        self.providerId = providerId
        self.referenceAudioPath = referenceAudioPath
        self.referenceProvenance = referenceProvenance
        self.assignmentConfidence = assignmentConfidence
        self.measuredPitchF0 = measuredPitchF0 ?? originalPitchF0
        self.measuredDurationSeconds = measuredDurationSeconds
        self.pronunciationNotes = pronunciationNotes
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.engineCompatibility = engineCompatibility
    }

    public static let defaultCast: [CharacterProfile] = [
        CharacterProfile(
            speakerTag: "SPEAKER_00",
            name: "Lead Protagonist",
            voiceId: "Rishi",
            gender: "male",
            personality: "determined lead protagonist",
            speakingStyle: "natural dramatic dub",
            speedRate: 1.0
        ),
        CharacterProfile(
            speakerTag: "SPEAKER_01",
            name: "Lead Heroine",
            voiceId: "Lekha",
            gender: "female",
            personality: "emotive lead heroine",
            speakingStyle: "expressive natural dub",
            speedRate: 1.0
        ),
        CharacterProfile(
            speakerTag: "SPEAKER_02",
            name: "Supporting Male",
            voiceId: "Aman",
            gender: "male",
            personality: "relaxed charismatic comrade",
            speakingStyle: "casual conversational dub",
            speedRate: 1.0
        ),
        CharacterProfile(
            speakerTag: "SPEAKER_03",
            name: "Supporting Female",
            voiceId: "Tara",
            gender: "female",
            personality: "confident articulate mentor",
            speakingStyle: "sharp confident dub",
            speedRate: 1.0
        )
    ]
}
