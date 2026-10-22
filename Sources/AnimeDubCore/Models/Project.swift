import Foundation

public enum TargetLanguage: String, Codable, CaseIterable, Sendable {
    case hindi = "hi"
    case hinglish = "hinglish"

    public var displayName: String {
        switch self {
        case .hindi: return "Hindi (Devanagari)"
        case .hinglish: return "Hinglish (Latin/Roman)"
        }
    }
}

public enum HinglishMixingLevel: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    public var displayName: String {
        switch self {
        case .low: return "Low (Colloquial Hindi in Roman Script)"
        case .medium: return "Medium (Natural Spoken Urban Loanwords)"
        case .high: return "High (Modern Anime Dub English Mix)"
        }
    }
}

public enum TranslationStyle: String, Codable, CaseIterable, Sendable {
    case naturalAnime = "natural_anime"
    case casual = "casual"
    case formal = "formal"
    case dramatic = "dramatic"

    public var displayName: String {
        switch self {
        case .naturalAnime: return "Natural Anime Dub"
        case .casual: return "Casual / Street"
        case .formal: return "Formal / Respectful"
        case .dramatic: return "Intense / Shonen Dramatic"
        }
    }
}

public enum VoiceEngineMode: String, Codable, CaseIterable, Sendable {
    case macNative = "mac_native"
    case cloudFallback = "cloud_fallback"

    public var displayName: String {
        switch self {
        case .macNative: return "On-Device macOS Speech (100% Offline)"
        case .cloudFallback: return "Edge-TTS (Online Cloud Fallback • Requires Internet)"
        }
    }
}

public struct AudioStreamMetadata: Codable, Identifiable, Hashable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let codecName: String
    public let channels: Int
    public let sampleRate: Int
    public let language: String?
    public let title: String?
    public let isDefault: Bool

    public init(
        index: Int,
        codecName: String,
        channels: Int,
        sampleRate: Int,
        language: String?,
        title: String?,
        isDefault: Bool = false
    ) {
        self.index = index
        self.codecName = codecName
        self.channels = channels
        self.sampleRate = sampleRate
        self.language = language
        self.title = title
        self.isDefault = isDefault
    }

    public var displayTitle: String {
        let lang = language?.uppercased() ?? "UND"
        let t = title != nil && !title!.isEmpty ? " (\(title!))" : ""
        let ch = channels == 2 ? "Stereo" : (channels == 1 ? "Mono" : "\(channels)ch")
        return "Stream #0:\(index) [\(lang)] \(codecName.uppercased()) \(ch)\(t)"
    }
}

public struct MediaMetadata: Codable, Sendable {
    public let duration: Double
    public let fps: Double
    public let resolution: String
    public let videoCodec: String?
    public let audioCodec: String?
    public let bitrate: Int
    public let sizeBytes: Int64
    public let audioStreams: [AudioStreamMetadata]

    public init(
        duration: Double,
        fps: Double,
        resolution: String,
        videoCodec: String?,
        audioCodec: String?,
        bitrate: Int,
        sizeBytes: Int64,
        audioStreams: [AudioStreamMetadata] = []
    ) {
        self.duration = duration
        self.fps = fps
        self.resolution = resolution
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.bitrate = bitrate
        self.sizeBytes = sizeBytes
        self.audioStreams = audioStreams
    }
}

public struct DubOptions: Codable, Sendable {
    public var sourceLanguage: String
    public var targetLanguage: TargetLanguage
    public var selectedAudioStreamIndex: Int?
    public var hinglishMixing: HinglishMixingLevel
    public var translationStyle: TranslationStyle
    public var voiceMode: VoiceEngineMode
    public var preserveBackgroundAudio: Bool
    public var normalizeLoudness: Bool

    public init(
        sourceLanguage: String = "ja",
        targetLanguage: TargetLanguage = .hinglish,
        selectedAudioStreamIndex: Int? = nil,
        hinglishMixing: HinglishMixingLevel = .medium,
        translationStyle: TranslationStyle = .naturalAnime,
        voiceMode: VoiceEngineMode = .macNative,
        preserveBackgroundAudio: Bool = true,
        normalizeLoudness: Bool = true
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.selectedAudioStreamIndex = selectedAudioStreamIndex
        self.hinglishMixing = hinglishMixing
        self.translationStyle = translationStyle
        self.voiceMode = voiceMode
        self.preserveBackgroundAudio = preserveBackgroundAudio
        self.normalizeLoudness = normalizeLoudness
    }
}

public struct Project: Codable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var sourceMediaPath: String
    public var createdAt: Date
    public var updatedAt: Date
    public var status: String
    public var episodes: [Episode]

    public init(
        id: String = UUID().uuidString,
        name: String,
        sourceMediaPath: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: String = "IDLE",
        episodes: [Episode] = []
    ) {
        self.id = id
        self.name = name
        self.sourceMediaPath = sourceMediaPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.episodes = episodes
    }
}

public struct Episode: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public var title: String
    public var sourceMediaPath: String
    public var duration: Double
    public var resolution: String
    public var fps: Double
    public var masterAudioPath: String?
    public var dubbedAudioPath: String?
    public var subtitleSrtPath: String?
    public var subtitleAssPath: String?
    public var exportedVideoPath: String?
    public var qaScore: Double?
    public var status: String

    public init(
        id: String = UUID().uuidString,
        projectId: String,
        title: String,
        sourceMediaPath: String,
        duration: Double = 0.0,
        resolution: String = "1920x1080",
        fps: Double = 24.0,
        masterAudioPath: String? = nil,
        dubbedAudioPath: String? = nil,
        subtitleSrtPath: String? = nil,
        subtitleAssPath: String? = nil,
        exportedVideoPath: String? = nil,
        qaScore: Double? = nil,
        status: String = "PENDING"
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.sourceMediaPath = sourceMediaPath
        self.duration = duration
        self.resolution = resolution
        self.fps = fps
        self.masterAudioPath = masterAudioPath
        self.dubbedAudioPath = dubbedAudioPath
        self.subtitleSrtPath = subtitleSrtPath
        self.subtitleAssPath = subtitleAssPath
        self.exportedVideoPath = exportedVideoPath
        self.qaScore = qaScore
        self.status = status
    }
}
