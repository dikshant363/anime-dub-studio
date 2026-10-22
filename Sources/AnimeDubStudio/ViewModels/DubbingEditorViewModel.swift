import Foundation
import SwiftUI
import AVKit
import AnimeDubCore

@MainActor
public final class DubbingEditorViewModel: ObservableObject {
    public let projectId: String
    public let episodeId: String

    @Published public var episode: Episode?
    @Published public var segments: [DialogueSegment] = []
    @Published public var selectedSegmentIndex: Int = 0
    @Published public var isPlaying: Bool = false
    @Published public var currentPlaybackTime: Double = 0.0
    @Published public var qaReport: QAReport?
    @Published public var isRegeneratingLine: Bool = false

    private let projectStore = ProjectStore.shared
    private let speechSynthesizer = SpeechSynthesisProvider()
    private let qaService = QualityAssuranceService()
    public var player: AVPlayer?

    public init(projectId: String, episodeId: String) {
        self.projectId = projectId
        self.episodeId = episodeId
        loadData()
    }

    public func loadData() {
        let projects = projectStore.loadProjects()
        if let proj = projects.first(where: { $0.id == projectId }),
           let ep = proj.episodes.first(where: { $0.id == episodeId }) {
            self.episode = ep
            self.segments = projectStore.loadDialogueSegments(for: episodeId, in: projectId)

            let mediaURL = URL(fileURLWithPath: ep.exportedVideoPath ?? ep.sourceMediaPath)
            if FileManager.default.fileExists(atPath: mediaURL.path) {
                self.player = AVPlayer(url: mediaURL)
            }
        }
    }

    public var selectedSegment: DialogueSegment? {
        guard selectedSegmentIndex >= 0 && selectedSegmentIndex < segments.count else { return nil }
        return segments[selectedSegmentIndex]
    }

    public func selectSegment(at index: Int) {
        selectedSegmentIndex = index
        if let seg = selectedSegment {
            seekToTime(seg.startTime)
        }
    }

    public func seekToTime(_ seconds: Double) {
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func updateSegment(
        index: Int,
        hindi: String,
        hinglish: String,
        speaker: String,
        voiceId: String
    ) {
        guard index >= 0 && index < segments.count else { return }
        segments[index].adaptedHindiText = hindi
        segments[index].adaptedHinglishText = hinglish
        segments[index].speakerLabel = speaker
        segments[index].voiceId = voiceId
        saveChanges()
    }

    public func regenerateSelectedLineAudio() async {
        guard let seg = selectedSegment else { return }
        isRegeneratingLine = true
        defer { isRegeneratingLine = false }

        let voicesDir = projectStore.episodeDirectory(for: projectId, episodeId: episodeId).appendingPathComponent("voices", isDirectory: true)
        let audioURL = voicesDir.appendingPathComponent(String(format: "seg_%03d_regen.wav", seg.segmentIndex))

        do {
            let res = try await speechSynthesizer.synthesize(
                text: seg.adaptedHinglishText.isEmpty ? seg.adaptedHindiText : seg.adaptedHinglishText,
                hindiText: seg.adaptedHindiText,
                to: audioURL,
                voiceId: seg.voiceId ?? "Rishi"
            )
            segments[selectedSegmentIndex].audioPath = res.audioURL.path
            segments[selectedSegmentIndex].synthesizedDuration = res.duration
            saveChanges()
        } catch {
            print("Regeneration failed: \(error.localizedDescription)")
        }
    }

    public func playSegmentAudio(at index: Int) {
        guard index >= 0 && index < segments.count,
              let path = segments[index].audioPath,
              FileManager.default.fileExists(atPath: path) else { return }

        let url = URL(fileURLWithPath: path)
        let sound = NSSound(contentsOf: url, byReference: true)
        sound?.play()
    }

    public func playOriginalSegmentAudio(at index: Int) {
        guard index >= 0 && index < segments.count else { return }
        let seg = segments[index]
        let epDir = projectStore.episodeDirectory(for: projectId, episodeId: episodeId)
        let masterWav = epDir.appendingPathComponent("audio/master_audio.wav")
        let sourcePath = FileManager.default.fileExists(atPath: masterWav.path) ? masterWav.path : (episode?.sourceMediaPath ?? "")
        guard FileManager.default.fileExists(atPath: sourcePath) else { return }

        let sliceURL = FileManager.default.temporaryDirectory.appendingPathComponent("orig_seg_\(seg.segmentIndex)_\(UUID().uuidString).wav")
        Task {
            let duration = max(0.1, seg.endTime - seg.startTime)
            let _ = try? await ProcessRunner.run(executable: "ffmpeg", arguments: [
                "-y", "-ss", "\(seg.startTime)",
                "-t", "\(duration)",
                "-i", sourcePath,
                "-acodec", "pcm_s16le",
                "-ar", "24000",
                "-ac", "1",
                sliceURL.path
            ])
            await MainActor.run {
                let sound = NSSound(contentsOf: sliceURL, byReference: true)
                sound?.play()
            }
        }
    }

    public func saveChanges() {
        projectStore.saveDialogueSegments(segments, for: episodeId, in: projectId)
    }
}
