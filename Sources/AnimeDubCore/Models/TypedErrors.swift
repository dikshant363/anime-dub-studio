import Foundation

/// Comprehensive typed error model distinguishing all dubbing pipeline and runtime failures.
public enum AnimeDubError: LocalizedError, Codable, Equatable, Sendable {
    case unsupportedMedia(String)
    case missingAudioTrack(String)
    case runtimeDependencyFailed(String)
    case modelUnavailable(String)
    case asrFailed(String)
    case diarizationFailed(String)
    case translationFailed(String)
    case speechSynthesisFailed(String)
    case timingFailed(String)
    case audioMixingFailed(String)
    case storageExhausted(String)
    case permissionFailed(String)
    case renderingFailed(String)
    case qaFailed(String)
    case jobCancelled
    case checkpointCorrupted(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedMedia(let details):
            return "Unsupported Media: \(details)"
        case .missingAudioTrack(let details):
            return "Missing or Invalid Audio Track: \(details)"
        case .runtimeDependencyFailed(let details):
            return "Runtime Dependency Failure: \(details)"
        case .modelUnavailable(let details):
            return "AI Model Unavailable: \(details)"
        case .asrFailed(let details):
            return "Speech Recognition (ASR) Failure: \(details)"
        case .diarizationFailed(let details):
            return "Speaker Diarization Failure: \(details)"
        case .translationFailed(let details):
            return "Translation & Localization Failure: \(details)"
        case .speechSynthesisFailed(let details):
            return "Speech Synthesis Failure: \(details)"
        case .timingFailed(let details):
            return "Dialogue Timing Alignment Failure: \(details)"
        case .audioMixingFailed(let details):
            return "Audio Mixing & Mastering Failure: \(details)"
        case .storageExhausted(let details):
            return "Storage Exhausted: \(details)"
        case .permissionFailed(let details):
            return "File System Permission Denied: \(details)"
        case .renderingFailed(let details):
            return "Video Rendering & Muxing Failure: \(details)"
        case .qaFailed(let details):
            return "Quality Assurance Failed: \(details)"
        case .jobCancelled:
            return "The dubbing job was cancelled by the user."
        case .checkpointCorrupted(let details):
            return "Checkpoint Corrupted: \(details)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedMedia:
            return "Ensure the file is a valid video (e.g. MKV, MP4, MOV, WebM) containing H.264, HEVC, or VP9 video."
        case .missingAudioTrack:
            return "Verify that the video file contains an active audio stream, and check the stream selector settings."
        case .runtimeDependencyFailed:
            return "Ensure FFmpeg is installed and accessible (e.g. via Homebrew: `brew install ffmpeg`)."
        case .modelUnavailable:
            return "Enable Apple Intelligence in macOS System Settings or select the offline deterministic translation mode."
        case .asrFailed:
            return "Check if the selected Japanese audio track has sufficient volume and is not corrupted."
        case .diarizationFailed:
            return "You can proceed with automatic turn alternation or manually assign character voices in the Dubbing Editor."
        case .translationFailed:
            return "Switch translation provider to Deterministic Fallback or verify Apple Intelligence availability."
        case .speechSynthesisFailed:
            return "Ensure macOS Indian English/Hindi system voices (Rishi, Lekha, Aman, Tara) are downloaded in System Settings → Accessibility → Spoken Content."
        case .timingFailed:
            return "Adjust dialogue timing tolerances or edit the dialogue script in the Dubbing Editor."
        case .audioMixingFailed:
            return "Check that output audio paths are writable and free of file locks."
        case .storageExhausted:
            return "Free up disk space on the primary storage volume and retry from the last valid checkpoint."
        case .permissionFailed:
            return "Grant read and write permissions to the source media directory or output destination."
        case .renderingFailed:
            return "Ensure source video codec is compatible with stream-copy or transcode to standard H.264/AAC."
        case .qaFailed:
            return "Review the QA report warnings in the Dubbing Editor and apply recommended script edits."
        case .jobCancelled:
            return "You can resume processing from the last saved stage checkpoint at any time."
        case .checkpointCorrupted:
            return "Start a fresh dubbing run or delete the corrupted checkpoint file."
        }
    }

    public var isRecoverable: Bool {
        switch self {
        case .jobCancelled, .timingFailed, .qaFailed, .diarizationFailed:
            return true
        case .permissionFailed, .storageExhausted, .modelUnavailable:
            return true
        default:
            return false
        }
    }
}
