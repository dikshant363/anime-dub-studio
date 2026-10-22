import Foundation
import SwiftUI
import AVKit
import AnimeDubCore

public struct DubbingEditorView: View {
    @ObservedObject var viewModel: StudioViewModel
    @StateObject private var editorVM: DubbingEditorViewModel
    @State private var showingCastSheet = false
    let projectId: String
    let episodeId: String

    public init(viewModel: StudioViewModel, projectId: String, episodeId: String) {
        self.viewModel = viewModel
        self.projectId = projectId
        self.episodeId = episodeId
        self._editorVM = StateObject(wrappedValue: DubbingEditorViewModel(projectId: projectId, episodeId: episodeId))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Editor Navigation Toolbar
            HStack(spacing: 16) {
                Button {
                    viewModel.currentScreen = .home
                } label: {
                    Label("Back to Dashboard", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Divider().frame(height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(editorVM.episode?.title ?? "Dubbing Editor")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("\(editorVM.segments.count) Dialogue Lines • Synchronized Timeline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let qa = editorVM.episode?.qaScore {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(qa >= 80 ? .green : .orange)
                        Text("QA Score: \(Int(qa))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())
                }

                Button {
                    showingCastSheet = true
                } label: {
                    Label("Character Cast", systemImage: "person.2.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Inspect reference audio, character provenance, and assign voices")

                Button {
                    editorVM.saveChanges()
                } label: {
                    Label("Save Changes", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    viewModel.openFinishedVideo(projectId: projectId, episodeId: episodeId)
                } label: {
                    Label("View Finished Video", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            // Main Editor Split Layout
            HSplitView {
                // Left Pane: Video Player & Subtitle Preview
                VStack(spacing: 0) {
                    if let player = editorVM.player {
                        VideoPlayer(player: player)
                            .frame(minHeight: 280)
                            .background(Color.black)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "film")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("Video Preview Unavailable")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 280)
                        .background(Color.black)
                    }

                    // Active Subtitle Overlay Bar
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ACTIVE SUBTITLE PREVIEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        if let seg = editorVM.selectedSegment {
                            Text(seg.adaptedHinglishText.isEmpty ? seg.adaptedHindiText : seg.adaptedHinglishText)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(seg.sourceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Select a dialogue line from the list to preview.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    // Line Audio Regeneration Bar
                    HStack {
                        Button {
                            if let idx = editorVM.selectedSegment?.segmentIndex {
                                editorVM.playSegmentAudio(at: idx)
                            }
                        } label: {
                            Label("Play Line Audio", systemImage: "speaker.wave.2.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(editorVM.selectedSegment == nil)

                        Button {
                            Task {
                                await editorVM.regenerateSelectedLineAudio()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if editorVM.isRegeneratingLine {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Regenerate Line Voice")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(editorVM.selectedSegment == nil || editorVM.isRegeneratingLine)

                        Spacer()
                    }
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor))
                }
                .frame(minWidth: 420)

                // Right Pane: Dialogue Segment List & Inspector
                VStack(spacing: 0) {
                    HStack {
                        Text("Dialogue Script (\(editorVM.segments.count) Segments)")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .overlay(Divider(), alignment: .bottom)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(editorVM.segments.enumerated()), id: \.element.id) { index, seg in
                                DialogueSegmentRow(
                                    segment: seg,
                                    isSelected: editorVM.selectedSegmentIndex == index,
                                    onSelect: {
                                        editorVM.selectSegment(at: index)
                                    },
                                    onPlayDubbed: {
                                        editorVM.playSegmentAudio(at: index)
                                    },
                                    onPlayOriginal: {
                                        editorVM.playOriginalSegmentAudio(at: index)
                                    },
                                    onUpdate: { hindi, hinglish, spk, voiceId in
                                        editorVM.updateSegment(index: index, hindi: hindi, hinglish: hinglish, speaker: spk, voiceId: voiceId)
                                    }
                                )
                            }
                        }
                        .padding(12)
                    }
                }
                .frame(minWidth: 440)
            }
        }
        .sheet(isPresented: $showingCastSheet) {
            CharacterCastManagerSheet(
                editorVM: editorVM,
                isPresented: $showingCastSheet
            )
        }
    }
}

struct DialogueSegmentRow: View {
    let segment: DialogueSegment
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlayDubbed: () -> Void
    let onPlayOriginal: () -> Void
    let onUpdate: (String, String, String, String) -> Void

    @State private var hindiText: String = ""
    @State private var hinglishText: String = ""
    @State private var selectedVoice: String = "Rishi"

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Timing & Speaker
            HStack {
                HStack(spacing: 6) {
                    Text(String(format: "#%02d", segment.segmentIndex + 1))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.tint)
                    Text(String(format: "%.2fs --> %.2fs", segment.startTime, segment.endTime))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Voice Picker
                Picker("", selection: $selectedVoice) {
                    Text("Rishi (Lead M)").tag("Rishi")
                    Text("Lekha (Lead F)").tag("Lekha")
                    Text("Aman (Secondary M)").tag("Aman")
                    Text("Tara (Secondary F)").tag("Tara")
                }
                .pickerStyle(.menu)
                .controlSize(.mini)
                .frame(width: 140)
                .onChange(of: selectedVoice) { _, newVoice in
                    onUpdate(hindiText, hinglishText, segment.speakerLabel, newVoice)
                }

                // Dual-Track A/B Auditioning
                HStack(spacing: 4) {
                    Button(action: onPlayOriginal) {
                        Label("JPN", systemImage: "waveform")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Audition original Japanese source line")

                    Button(action: onPlayDubbed) {
                        Label("Dub", systemImage: "speaker.wave.2.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .help("Audition dubbed Hindi/Hinglish line")
                }
            }

            // Japanese Source Text
            Text(segment.sourceText)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Hindi Text Field
            TextField("Hindi Dub Translation", text: $hindiText)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
                .onChange(of: hindiText) { _, val in
                    onUpdate(val, hinglishText, segment.speakerLabel, selectedVoice)
                }

            // Roman Hinglish Field
            TextField("Roman Hinglish Dub Line", text: $hinglishText)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
                .onChange(of: hinglishText) { _, val in
                    onUpdate(hindiText, val, segment.speakerLabel, selectedVoice)
                }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
        )
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            hindiText = segment.adaptedHindiText
            hinglishText = segment.adaptedHinglishText
            selectedVoice = segment.voiceId ?? "Rishi"
        }
    }
}

struct CharacterCastManagerSheet: View {
    @ObservedObject var editorVM: DubbingEditorViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Character Cast & Voice Profiles")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Inspect reference audio provenance, measured acoustic observations, and reassign voices across cast.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(editorVM.characterProfiles) { profile in
                        CharacterProfileEditorRow(profile: profile) { newVoice, newName in
                            editorVM.updateCharacterProfile(speakerTag: profile.speakerTag, newVoiceId: newVoice, newName: newName)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 540, minHeight: 420)
    }
}

struct CharacterProfileEditorRow: View {
    let profile: CharacterProfile
    let onUpdate: (String, String) -> Void

    @State private var name: String = ""
    @State private var selectedVoice: String = "Rishi"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.speakerTag)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())

                TextField("Character Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .onChange(of: name) { _, newName in
                        onUpdate(selectedVoice, newName)
                    }

                Spacer()

                Picker("Voice", selection: $selectedVoice) {
                    Text("Rishi (Lead M)").tag("Rishi")
                    Text("Lekha (Lead F)").tag("Lekha")
                    Text("Aman (Secondary M)").tag("Aman")
                    Text("Tara (Secondary F)").tag("Tara")
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: selectedVoice) { _, newVoice in
                    onUpdate(newVoice, name)
                }
            }

            // Reference audio provenance and observations
            HStack(spacing: 12) {
                if let refPath = profile.referenceAudioPath, FileManager.default.fileExists(atPath: refPath) {
                    Button {
                        let sound = NSSound(contentsOfFile: refPath, byReference: true)
                        sound?.play()
                    } label: {
                        Label("Audition Reference", systemImage: "play.circle")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                if let provenance = profile.referenceProvenance {
                    Text("Provenance: \(provenance)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let dur = profile.measuredDurationSeconds {
                    Text("• \(String(format: "%.1fs", dur))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Engine: \(profile.engineCompatibility)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            name = profile.name
            selectedVoice = profile.voiceId
        }
    }
}
