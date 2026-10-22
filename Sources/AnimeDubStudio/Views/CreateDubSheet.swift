import Foundation
import SwiftUI
import AppKit
import AnimeDubCore

public struct CreateDubSheet: View {
    @ObservedObject var viewModel: StudioViewModel
    @Binding var isPresented: Bool

    @State private var selectedFileURL: URL?
    @State private var projectName: String = ""
    @State private var targetLanguage: TargetLanguage = .hinglish
    @State private var mixingLevel: HinglishMixingLevel = .medium
    @State private var translationStyle: TranslationStyle = .naturalAnime
    @State private var voiceMode: VoiceEngineMode = .macNative
    @State private var selectedAudioStreamIndex: Int? = nil
    @State private var preserveBGM: Bool = true
    @State private var normalizeLoudness: Bool = true
    @State private var speakerSimilarity: Double = 80.0
    @State private var targetNaturalness: Double = 85.0
    @State private var accentPreservation: AccentPreservationMode = .balanced
    @State private var auditioningVoice: String? = nil

    @State private var isProbing: Bool = false
    @State private var probedMetadata: MediaMetadata?
    @State private var probeError: String?

    private let probeService = MediaProbeService()

    public init(viewModel: StudioViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a New Dub")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Select a video and configure speech, translation, and mixing options.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Video Selection Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Source Video File")
                            .font(.headline)

                        if let fileURL = selectedFileURL {
                            HStack(spacing: 12) {
                                Image(systemName: "film")
                                    .font(.title)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fileURL.lastPathComponent)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(fileURL.path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button("Change File...") {
                                    chooseFile()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Probed metadata badge bar
                            if isProbing {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("Probing video codecs & audio streams...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let meta = probedMetadata {
                                HStack(spacing: 16) {
                                    Label(String(format: "%.1fs", meta.duration), systemImage: "clock")
                                    Label(meta.resolution, systemImage: "aspectratio")
                                    Label(String(format: "%.0f fps", meta.fps), systemImage: "speedometer")
                                    Label(meta.videoCodec?.uppercased() ?? "VIDEO", systemImage: "tv")
                                    Label(String(format: "%.1f MB", Double(meta.sizeBytes) / 1_000_000), systemImage: "internaldrive")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            }
                        } else {
                            // Drop zone
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                                Text("Select or Drop Anime Video Clip")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Supports MKV (Dual-Audio), MP4, MOV, and WebM")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Button("Choose Video File...") {
                                    chooseFile()
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    .foregroundStyle(Color.secondary.opacity(0.25))
                            )
                        }

                        if let err = probeError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // 2. Audio Stream Track Selection (Never assume stream 0 is Japanese!)
                    if let meta = probedMetadata, !meta.audioStreams.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dialogue Audio Track")
                                .font(.headline)
                            Text("Select the Japanese dialogue stream for transcription.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("Audio Track", selection: $selectedAudioStreamIndex) {
                                Text("Auto Detect (Prioritize [JPN] stream)").tag(nil as Int?)
                                ForEach(meta.audioStreams) { stream in
                                    Text(stream.displayTitle).tag(stream.index as Int?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Divider()

                    // 3. Target Language & Hinglish Style
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Dubbing Localization Language")
                            .font(.headline)

                        Picker("Target Language", selection: $targetLanguage) {
                            ForEach(TargetLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)

                        if targetLanguage == .hinglish {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Hinglish English Mixing Level")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Picker("Mixing Level", selection: $mixingLevel) {
                                    ForEach(HinglishMixingLevel.allCases, id: \.self) { mix in
                                        Text(mix.displayName).tag(mix)
                                    }
                                }
                                .pickerStyle(.radioGroup)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Divider()

                    // 4. Voice Engine & Speaker Similarity Controls
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Speech Synthesis & Voice Conditioning")
                            .font(.headline)

                        Picker("Voice Engine", selection: $voiceMode) {
                            ForEach(VoiceEngineMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        if voiceMode == .macNative {
                            // Speaker Similarity Slider (0 - 100)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Speaker Similarity")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(Int(speakerSimilarity))%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.tint)
                                }
                                Slider(value: $speakerSimilarity, in: 0...100, step: 1.0)
                                Text("Applies acoustic formant shaping and pitch conditioning to converge toward source vocal timbre.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Target Naturalness Slider (0 - 100)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Target Language Naturalness")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(Int(targetNaturalness))%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.tint)
                                }
                                Slider(value: $targetNaturalness, in: 0...100, step: 1.0)
                                Text("Balances anime delivery pacing against natural spoken Hindi/Hinglish cadence.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Accent Preservation Presets
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Accent Preservation Preset")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Picker("", selection: $accentPreservation) {
                                    ForEach(AccentPreservationMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .pickerStyle(.radioGroup)

                                Text(accentPreservation.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Character Cast Preview & Auditioning
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Cast Audition & Voice Preview")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                VStack(spacing: 8) {
                                    AuditionVoiceRow(
                                        name: "Rishi",
                                        role: "Lead Male Protagonist",
                                        sampleText: "Hum haar nahi maan sakte! Aage badho!",
                                        isAuditioning: auditioningVoice == "Rishi",
                                        onAudition: { auditionVoice(voiceId: "Rishi", sampleText: "Hum haar nahi maan sakte! Aage badho!") }
                                    )
                                    AuditionVoiceRow(
                                        name: "Lekha",
                                        role: "Lead Female Heroine",
                                        sampleText: "Dhyan se suno, abhi sab theek ho jayega.",
                                        isAuditioning: auditioningVoice == "Lekha",
                                        onAudition: { auditionVoice(voiceId: "Lekha", sampleText: "Dhyan se suno, abhi sab theek ho jayega.") }
                                    )
                                    AuditionVoiceRow(
                                        name: "Aman",
                                        role: "Supporting / Commander",
                                        sampleText: "Mission complete karne ke liye ready raho.",
                                        isAuditioning: auditioningVoice == "Aman",
                                        onAudition: { auditionVoice(voiceId: "Aman", sampleText: "Mission complete karne ke liye ready raho.") }
                                    )
                                    AuditionVoiceRow(
                                        name: "Tara",
                                        role: "Supporting Female / Mentor",
                                        sampleText: "Chalo dekhte hain kisme kitna dum hai.",
                                        isAuditioning: auditioningVoice == "Tara",
                                        onAudition: { auditionVoice(voiceId: "Tara", sampleText: "Chalo dekhte hain kisme kitna dum hai.") }
                                    )
                                }
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Divider()

                    // 5. Collapsible Advanced Settings
                    DisclosureGroup("Advanced Settings & Audio Mastering") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Translation Style", selection: $translationStyle) {
                                ForEach(TranslationStyle.allCases, id: \.self) { st in
                                    Text(st.displayName).tag(st)
                                }
                            }

                            Toggle("Preserve Original Background Music & SFX (Sidechain Ducking)", isOn: $preserveBGM)
                                .font(.subheadline)

                            Toggle("EBU R128 Loudness Normalization (-23 LUFS / -1.0 dB True Peak)", isOn: $normalizeLoudness)
                                .font(.subheadline)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }

            // Bottom Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Start Dubbing") {
                    guard let file = selectedFileURL else { return }
                    let options = DubOptions(
                        sourceLanguage: "ja",
                        targetLanguage: targetLanguage,
                        selectedAudioStreamIndex: selectedAudioStreamIndex,
                        hinglishMixing: mixingLevel,
                        translationStyle: translationStyle,
                        voiceMode: voiceMode,
                        preserveBackgroundAudio: preserveBGM,
                        normalizeLoudness: normalizeLoudness,
                        speakerSimilarity: speakerSimilarity,
                        targetNaturalness: targetNaturalness,
                        accentPreservation: accentPreservation
                    )
                    isPresented = false
                    viewModel.createAndStartDub(
                        mediaURL: file,
                        projectName: projectName.isEmpty ? file.deletingPathExtension().lastPathComponent : projectName,
                        options: options
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(selectedFileURL == nil || isProbing)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .top)
        }
        .frame(minWidth: 560, minHeight: 620)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]

        if panel.runModal() == .OK, let url = panel.url {
            selectedFileURL = url
            projectName = url.deletingPathExtension().lastPathComponent
            probeMedia(url: url)
        }
    }

    private func probeMedia(url: URL) {
        isProbing = true
        probeError = nil
        Task {
            do {
                let meta = try await probeService.inspectMedia(at: url)
                await MainActor.run {
                    self.probedMetadata = meta
                    self.isProbing = false
                    // Auto-select jpn track if present
                    if let jpnTrack = meta.audioStreams.first(where: { ($0.language ?? "").lowercased().contains("jp") }) {
                        self.selectedAudioStreamIndex = jpnTrack.index
                    }
                }
            } catch {
                await MainActor.run {
                    self.probeError = error.localizedDescription
                    self.isProbing = false
                }
            }
        }
    }

    private func auditionVoice(voiceId: String, sampleText: String) {
        auditioningVoice = voiceId
        Task {
            let tempDir = FileManager.default.temporaryDirectory
            let outURL = tempDir.appendingPathComponent("audition_\(voiceId)_\(UUID().uuidString).wav")
            let provider = SpeechSynthesisProvider()
            do {
                let res = try await provider.previewVoice(
                    voiceId: voiceId,
                    text: sampleText,
                    to: outURL,
                    speakerSimilarity: speakerSimilarity,
                    accentMode: accentPreservation
                )
                await MainActor.run {
                    self.auditioningVoice = nil
                    let sound = NSSound(contentsOf: res.audioURL, byReference: true)
                    sound?.play()
                }
            } catch {
                await MainActor.run {
                    self.auditioningVoice = nil
                }
            }
        }
    }
}

struct AuditionVoiceRow: View {
    let name: String
    let role: String
    let sampleText: String
    let isAuditioning: Bool
    let onAudition: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.wave.2.fill")
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("• \(role)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\"\(sampleText)\"")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onAudition) {
                HStack(spacing: 4) {
                    if isAuditioning {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    Text("Audition")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isAuditioning)
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
