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

    public init(
        speakerTag: String,
        name: String,
        voiceId: String,
        gender: String = "male",
        personality: String = "natural",
        speakingStyle: String = "casual",
        speedRate: Double = 1.0,
        pitchPercent: Double = 0.0
    ) {
        self.speakerTag = speakerTag
        self.name = name
        self.voiceId = voiceId
        self.gender = gender
        self.personality = personality
        self.speakingStyle = speakingStyle
        self.speedRate = speedRate
        self.pitchPercent = pitchPercent
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
