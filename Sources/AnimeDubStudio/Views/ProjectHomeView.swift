import Foundation
import SwiftUI
import AnimeDubCore

public struct ProjectHomeView: View {
    @ObservedObject var viewModel: StudioViewModel
    @State private var showingCreateSheet = false

    public init(viewModel: StudioViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Header Bar
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Anime Dub Studio")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Native Apple Silicon Dubbing Workstation")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Hardware Status Pill
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("\(viewModel.systemCaps.chipName) (\(Int(viewModel.systemCaps.totalMemoryGB)) GB)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(viewModel.systemCaps.foundationModelsAvailable ? "Apple Intelligence" : "Local MLX")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                // Create Button
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("Create a Dub", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero Banner
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.accentColor.opacity(0.15), Color.purple.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                                Text("Japanese Anime → Natural Hindi / Hinglish Dubbing")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }

                            Text("On-device AI anime dubbing with authentic character voices.")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Transcribe dialogue with Apple Silicon MLX Whisper, translate culturally, synthesize distinct character voices locally, and master high-fidelity soundtrack audio without cloud fees.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 640, alignment: .leading)

                            Button {
                                showingCreateSheet = true
                            } label: {
                                Label("Start New Project", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                        }
                        .padding(24)
                    }

                    // Projects Section Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Dubbed Projects")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(viewModel.filteredProjects.count) Projects Available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Search Field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search projects...", text: $viewModel.searchQuery)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(width: 220)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }

                    // Project Cards or Empty State
                    if viewModel.filteredProjects.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "film")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 40)
                            Text("No projects yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Import a Japanese video or anime episode to generate your first natural Hindi dub.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                            Button("Create First Dub") {
                                showingCreateSheet = true
                            }
                            .buttonStyle(.bordered)
                            .padding(.bottom, 40)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)], spacing: 16) {
                            ForEach(viewModel.filteredProjects) { project in
                                ProjectCardView(project: project) {
                                    if let firstEp = project.episodes.first {
                                        viewModel.openEditor(projectId: project.id, episodeId: firstEp.id)
                                    }
                                } onDelete: {
                                    viewModel.deleteProject(project)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateDubSheet(viewModel: viewModel, isPresented: $showingCreateSheet)
        }
    }
}

struct ProjectCardView: View {
    let project: Project
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(URL(fileURLWithPath: project.sourceMediaPath).lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let ep = project.episodes.first, let qa = ep.qaScore {
                    Text("QA \(Int(qa))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(qa >= 80 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundStyle(qa >= 80 ? Color.green : Color.orange)
                        .clipShape(Capsule())
                }
            }

            Divider()

            HStack {
                if let ep = project.episodes.first, ep.duration > 0 {
                    Label(String(format: "%.1fs", ep.duration), systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Delete Project")

                Button(action: onOpen) {
                    Label("Open Editor", systemImage: "play.circle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }
}
