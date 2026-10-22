import Foundation
import SwiftUI
import AVKit
import AnimeDubCore

public struct DubbingEditorView: View {
    @ObservedObject var viewModel: StudioViewModel
    @StateObject private var editorVM: DubbingEditorViewModel
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
                    editorVM.saveChanges()
                } label: {
                    Label("Save Changes", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    viewModel.currentScreen = .exportReport(projectId: projectId, episodeId: episodeId)
                } label: {
                    Label("Export Quality Report", systemImage: "chart.bar.doc.horizontal")
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
                                    onPlay: {
                                        editorVM.playSegmentAudio(at: index)
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
    }
}

struct DialogueSegmentRow: View {
    let segment: DialogueSegment
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
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

                Button(action: onPlay) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Play line audio")
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
