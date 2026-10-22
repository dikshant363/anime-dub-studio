import Foundation

public protocol MediaProbeServiceProtocol: Sendable {
    func inspectMedia(at url: URL) async throws -> MediaMetadata
}

public protocol AudioExtractionServiceProtocol: Sendable {
    func extractMasterAudio(from mediaURL: URL, to outputURL: URL, audioStreamIndex: Int?, sourceLang: String) async throws
    func extractASRAudio(from mediaURL: URL, to outputURL: URL, audioStreamIndex: Int?, sourceLang: String) async throws
}

public struct ASRSegment: Codable, Sendable {
    public let id: Int
    public let start: Double
    public let end: Double
    public let text: String
    public let confidence: Double
    public let language: String
    public var speaker: String

    public init(
        id: Int,
        start: Double,
        end: Double,
        text: String,
        confidence: Double = 0.95,
        language: String = "ja",
        speaker: String = "SPEAKER_00"
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
        self.confidence = confidence
        self.language = language
        self.speaker = speaker
    }
}

public protocol ASRProviderProtocol: Sendable {
    var name: String { get }
    var isAvailable: Bool { get async }
    func transcribe(audioURL: URL, language: String) async throws -> [ASRSegment]
}

public protocol DiarizationProviderProtocol: Sendable {
    func diarize(audioURL: URL, segments: [ASRSegment]) async throws -> [ASRSegment]
}

public struct TranslationResult: Codable, Sendable {
    public let sourceText: String
    public let translatedText: String
    public let adaptedHindi: String
    public let adaptedHinglish: String
    public let ttsPronunciationText: String
    public let provider: String

    public init(
        sourceText: String,
        translatedText: String,
        adaptedHindi: String,
        adaptedHinglish: String,
        ttsPronunciationText: String,
        provider: String
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.adaptedHindi = adaptedHindi
        self.adaptedHinglish = adaptedHinglish
        self.ttsPronunciationText = ttsPronunciationText
        self.provider = provider
    }
}

public protocol TranslationProviderProtocol: Sendable {
    var name: String { get }
    var isAvailable: Bool { get async }
    func translateLine(
        text: String,
        sourceLang: String,
        targetLang: String,
        characterName: String?,
        personality: String?,
        style: TranslationStyle
    ) async throws -> TranslationResult
}

public protocol HindiAdaptationServiceProtocol: Sendable {
    func polishHindi(_ text: String, characterStyle: String?) -> String
    func compressForDuration(_ text: String, durationRatio: Double) -> String
}

public protocol HinglishLocalizationServiceProtocol: Sendable {
    func toHinglish(
        hindiText: String,
        characterStyle: String?,
        translationStyle: TranslationStyle,
        mixingLevel: HinglishMixingLevel
    ) -> String

    func createTTSPronunciation(hinglishText: String, hindiDevanagari: String) -> String
}

public struct SynthesisResult: Sendable {
    public let audioURL: URL
    public let duration: Double

    public init(audioURL: URL, duration: Double) {
        self.audioURL = audioURL
        self.duration = duration
    }
}

public enum SynthesisTechnologyType: String, Codable, Sendable {
    case nativeAcousticCast = "native_acoustic_cast"
    case neuralSpeakerConditioned = "neural_speaker_conditioned"
    case cloudVoiceCloning = "cloud_voice_cloning"
}

public struct SpeechSynthesisCapabilities: Codable, Sendable {
    public let providerId: String
    public let providerName: String
    public let technologyType: SynthesisTechnologyType
    public let supportsVoiceCloning: Bool
    public let supportsReferenceAudioConditioning: Bool
    public let supportsIndependentNaturalnessControl: Bool
    public let supportedVoiceIds: [String]
    public let disclosureNotice: String

    public init(
        providerId: String,
        providerName: String,
        technologyType: SynthesisTechnologyType,
        supportsVoiceCloning: Bool,
        supportsReferenceAudioConditioning: Bool,
        supportsIndependentNaturalnessControl: Bool,
        supportedVoiceIds: [String],
        disclosureNotice: String
    ) {
        self.providerId = providerId
        self.providerName = providerName
        self.technologyType = technologyType
        self.supportsVoiceCloning = supportsVoiceCloning
        self.supportsReferenceAudioConditioning = supportsReferenceAudioConditioning
        self.supportsIndependentNaturalnessControl = supportsIndependentNaturalnessControl
        self.supportedVoiceIds = supportedVoiceIds
        self.disclosureNotice = disclosureNotice
    }
}

public protocol SpeechSynthesisProviderProtocol: Sendable {
    var name: String { get }
    var capabilities: SpeechSynthesisCapabilities { get }
    func synthesize(
        text: String,
        hindiText: String?,
        to outputURL: URL,
        voiceId: String,
        speedRate: Double,
        pitchPercent: Double,
        speakerSimilarity: Double,
        accentMode: AccentPreservationMode,
        targetNaturalness: Double
    ) async throws -> SynthesisResult

    func previewVoice(
        voiceId: String,
        text: String,
        to outputURL: URL,
        speedRate: Double,
        pitchPercent: Double,
        speakerSimilarity: Double,
        accentMode: AccentPreservationMode
    ) async throws -> SynthesisResult
}

public extension SpeechSynthesisProviderProtocol {
    func synthesize(
        text: String,
        hindiText: String?,
        to outputURL: URL,
        voiceId: String,
        speedRate: Double = 1.0,
        pitchPercent: Double = 0.0
    ) async throws -> SynthesisResult {
        try await synthesize(
            text: text,
            hindiText: hindiText,
            to: outputURL,
            voiceId: voiceId,
            speedRate: speedRate,
            pitchPercent: pitchPercent,
            speakerSimilarity: 80.0,
            accentMode: .balanced,
            targetNaturalness: 85.0
        )
    }

    func previewVoice(
        voiceId: String,
        text: String,
        to outputURL: URL,
        speedRate: Double = 1.0,
        pitchPercent: Double = 0.0,
        speakerSimilarity: Double = 80.0,
        accentMode: AccentPreservationMode = .balanced
    ) async throws -> SynthesisResult {
        try await synthesize(
            text: text,
            hindiText: nil,
            to: outputURL,
            voiceId: voiceId,
            speedRate: speedRate,
            pitchPercent: pitchPercent,
            speakerSimilarity: speakerSimilarity,
            accentMode: accentMode,
            targetNaturalness: 85.0
        )
    }
}

public protocol DialogueTimingServiceProtocol: Sendable {
    func adjustAudioTiming(
        inputURL: URL,
        outputURL: URL,
        targetDuration: Double,
        currentDuration: Double
    ) async throws -> (outputURL: URL, finalDuration: Double, stretchRatio: Double)
}

public struct DialogueTimelineSegment: Sendable {
    public let startTime: Double
    public let endTime: Double
    public let audioURL: URL
    public let adaptedHindiText: String
    public let adaptedHinglishText: String
    public let speakerLabel: String

    public init(
        startTime: Double,
        endTime: Double,
        audioURL: URL,
        adaptedHindiText: String,
        adaptedHinglishText: String,
        speakerLabel: String
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.audioURL = audioURL
        self.adaptedHindiText = adaptedHindiText
        self.adaptedHinglishText = adaptedHinglishText
        self.speakerLabel = speakerLabel
    }
}

public protocol AudioMixingServiceProtocol: Sendable {
    func assembleDialogueTrack(
        segments: [DialogueTimelineSegment],
        totalDuration: Double,
        to outputURL: URL
    ) async throws -> URL

    func mixMasterSoundtrack(
        dialogueURL: URL,
        backgroundURL: URL?,
        to outputURL: URL,
        preserveBGM: Bool,
        normalizeLoudness: Bool
    ) async throws -> URL
}

public protocol SubtitleServiceProtocol: Sendable {
    func generateSRT(segments: [DialogueTimelineSegment], to outputURL: URL, useHinglish: Bool) throws
    func generateASS(segments: [DialogueTimelineSegment], to outputURL: URL, title: String, useHinglish: Bool) throws
}

public protocol VideoRenderServiceProtocol: Sendable {
    func renderDubbedVideo(
        sourceVideoURL: URL,
        dubbedAudioURL: URL,
        to outputURL: URL,
        subtitleURL: URL?
    ) async throws -> URL
}

public protocol QualityAssuranceServiceProtocol: Sendable {
    func evaluate(
        segments: [DialogueSegment],
        dubbedAudioURL: URL?,
        videoDuration: Double,
        isHinglish: Bool
    ) async -> QAReport
}
