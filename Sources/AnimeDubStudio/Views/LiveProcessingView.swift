import Foundation
import SwiftUI
import AnimeDubCore

public struct LiveProcessingView: View {
    @ObservedObject var viewModel: StudioViewModel
    @State private var showLogs = true

    public init(viewModel: StudioViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Processing Top Banner
            HStack {
                HStack(spacing: 10) {
                    if let job = viewModel.activeJob, job.status == .running {
                        ProgressView().controlSize(.small)
                    } else if let job = viewModel.activeJob, job.status == .paused {
                        Image(systemName: "pause.circle.fill").foregroundStyle(.orange)
                    } else if let job = viewModel.activeJob, job.status == .completed {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.activeJob?.stage.displayName ?? "Processing Dub")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(viewModel.activeJob?.logs.last?.message ?? "Initializing Apple Silicon pipeline...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Job Controls (Pause, Resume, Cancel)
                HStack(spacing: 8) {
                    if let job = viewModel.activeJob {
                        if job.status == .running {
                            Button {
                                viewModel.pauseActiveJob()
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else if job.status == .paused {
                            Button {
                                viewModel.resumeActiveJob()
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        Button(role: .destructive) {
                            viewModel.cancelActiveJob()
                        } label: {
                            Label("Cancel Job", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. Determinate Main Progress Bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Overall Progress")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.1f%%", viewModel.activeJob?.progress ?? 0.0))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }

                        ProgressView(value: (viewModel.activeJob?.progress ?? 0.0) / 100.0)
                            .progressViewStyle(.linear)
                            .tint(Color.accentColor)
                    }
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 2. 12-Stage Visual Stepper
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pipeline Stages")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        let currentStageIndex = viewModel.activeJob?.stage.stageIndex ?? 0

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 8)], spacing: 8) {
                            ForEach(Array(ProcessingStage.allCases.filter { $0 != .failed }.enumerated()), id: \.offset) { idx, st in
                                HStack(spacing: 6) {
                                    if idx < currentStageIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else if idx == currentStageIndex && (viewModel.activeJob?.status == .running) {
                                        ProgressView().controlSize(.mini)
                                    } else if idx == currentStageIndex && (viewModel.activeJob?.status == .paused) {
                                        Image(systemName: "pause.circle.fill")
                                            .foregroundStyle(.orange)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary.opacity(0.4))
                                    }

                                    Text(st.displayName)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .foregroundStyle(idx <= currentStageIndex ? .primary : .secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(idx == currentStageIndex ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor).opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 3. Telemetry & Metrics Bar
                    HStack(spacing: 12) {
                        // Elapsed time
                        let elapsed = Date().timeIntervalSince(viewModel.activeJob?.startedAt ?? Date())
                        MetricCard(title: "Elapsed Time", value: String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60), systemImage: "stopwatch")

                        // Processed media duration
                        let dur = viewModel.activeJob?.processedDuration ?? 0.0
                        let total = viewModel.activeJob?.totalDuration ?? 0.0
                        let durStr = total > 0 ? String(format: "%.1fs / %.1fs", dur, total) : String(format: "%.1fs", dur)
                        MetricCard(title: "Media Processed", value: durStr, systemImage: "clock")

                        // Dialogue items
                        if let curr = viewModel.activeJob?.currentItem, let totalItems = viewModel.activeJob?.totalItems {
                            MetricCard(title: "Dialogue Segments", value: "\(curr) / \(totalItems)", systemImage: "text.bubble")
                        } else {
                            MetricCard(title: "Dialogue Segments", value: "Analyzing...", systemImage: "text.bubble")
                        }

                        // Memory & System
                        MetricCard(title: "Unified Memory", value: "\(Int(viewModel.systemCaps.totalMemoryGB)) GB (M4)", systemImage: "memorychip")
                    }

                    // 4. Live Diagnostic Console Drawer
                    DisclosureGroup("Diagnostic Execution Logs", isExpanded: $showLogs) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.activeJob?.logs ?? []) { log in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(Self.formatTimestamp(log.timestamp))
                                            .font(.caption2)
                                            .monospaced()
                                            .foregroundStyle(.secondary)
                                        Text("[\(log.stage.rawValue)]")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.tint)
                                        Text(log.message)
                                            .font(.caption2)
                                            .monospaced()
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                        }
                        .frame(height: 160)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                    }
                }
                .padding(20)
            }
        }
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
