import Foundation

public enum ProcessingStage: String, Codable, CaseIterable, Sendable {
    case preparing = "PREPARING"
    case extractingAudio = "EXTRACTING_AUDIO"
    case asr = "ASR"
    case diarizing = "DIARIZING"
    case translating = "TRANSLATING"
    case hinglish = "HINGLISH"
    case tts = "TTS"
    case timing = "TIMING"
    case mixing = "MIXING"
    case subtitles = "SUBTITLES"
    case qa = "QA"
    case rendering = "RENDERING"
    case completed = "COMPLETED"
    case failed = "FAILED"

    public var displayName: String {
        switch self {
        case .preparing: return "Preparing Media"
        case .extractingAudio: return "Extracting Japanese Audio Track"
        case .asr: return "Transcribing Dialogue (ASR)"
        case .diarizing: return "Speaker Diarization & Voices"
        case .translating: return "Translating Dialogue to Hindi"
        case .hinglish: return "Colloquial Hinglish Localization"
        case .tts: return "Synthesizing Character Speech"
        case .timing: return "Synchronizing Dialogue Timing"
        case .mixing: return "Mastering Audio & Preserving BGM"
        case .subtitles: return "Formatting Subtitles (SRT/ASS)"
        case .qa: return "Automated Quality Assurance"
        case .rendering: return "Rendering Final Dubbed MP4"
        case .completed: return "Dubbing Complete"
        case .failed: return "Processing Failed"
        }
    }

    public var stageIndex: Int {
        switch self {
        case .preparing: return 0
        case .extractingAudio: return 1
        case .asr: return 2
        case .diarizing: return 3
        case .translating: return 4
        case .hinglish: return 5
        case .tts: return 6
        case .timing: return 7
        case .mixing: return 8
        case .subtitles: return 9
        case .qa: return 10
        case .rendering: return 11
        case .completed: return 12
        case .failed: return -1
        }
    }
}

public enum JobStatus: String, Codable, Sendable {
    case queued = "QUEUED"
    case running = "RUNNING"
    case paused = "PAUSED"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
}

public struct JobLog: Codable, Identifiable, Sendable {
    public var id: String { "\(timestamp.timeIntervalSince1970)-\(stage.rawValue)" }
    public let timestamp: Date
    public let stage: ProcessingStage
    public let progress: Double
    public let message: String
    public let details: String?

    public init(
        timestamp: Date = Date(),
        stage: ProcessingStage,
        progress: Double,
        message: String,
        details: String? = nil
    ) {
        self.timestamp = timestamp
        self.stage = stage
        self.progress = progress
        self.message = message
        self.details = details
    }
}

public struct JobState: Codable, Identifiable, Sendable {
    public let id: String
    public let episodeId: String
    public let projectId: String
    public var status: JobStatus
    public var stage: ProcessingStage
    public var progress: Double
    public var currentItem: Int?
    public var totalItems: Int?
    public var currentCharacter: String?
    public var processedDuration: Double
    public var totalDuration: Double
    public var startedAt: Date
    public var completedAt: Date?
    public var errorMessage: String?
    public var logs: [JobLog]

    public init(
        id: String = UUID().uuidString,
        episodeId: String,
        projectId: String,
        status: JobStatus = .queued,
        stage: ProcessingStage = .preparing,
        progress: Double = 0.0,
        currentItem: Int? = nil,
        totalItems: Int? = nil,
        currentCharacter: String? = nil,
        processedDuration: Double = 0.0,
        totalDuration: Double = 0.0,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        errorMessage: String? = nil,
        logs: [JobLog] = []
    ) {
        self.id = id
        self.episodeId = episodeId
        self.projectId = projectId
        self.status = status
        self.stage = stage
        self.progress = progress
        self.currentItem = currentItem
        self.totalItems = totalItems
        self.currentCharacter = currentCharacter
        self.processedDuration = processedDuration
        self.totalDuration = totalDuration
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.errorMessage = errorMessage
        self.logs = logs
    }
}
