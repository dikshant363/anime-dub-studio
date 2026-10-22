import Foundation
import SwiftUI
import Combine
import AnimeDubCore

public enum StudioScreen: Equatable {
    case home
    case createDub
    case processing(jobId: String)
    case editor(projectId: String, episodeId: String)
    case exportReport(projectId: String, episodeId: String)
    case finishedVideo(projectId: String, episodeId: String)
}

@MainActor
public final class StudioViewModel: ObservableObject {
    @Published public var currentScreen: StudioScreen = .home
    @Published public var projects: [Project] = []
    @Published public var searchQuery: String = ""
    @Published public var selectedFilter: String = "All"
    @Published public var activeJob: JobState? = nil
    @Published public var systemCaps: SystemCapabilities
    @Published public var activeQAReport: QAReport? = nil

    private let projectStore = ProjectStore.shared
    private let orchestrator = JobOrchestrator()
    private var activeTask: Task<Void, Never>? = nil

    public init() {
        self.systemCaps = ModelCapabilityRegistry.inspectCapabilities()
        self.projects = projectStore.loadProjects()
    }

    public func refreshProjects() {
        self.projects = projectStore.loadProjects()
    }

    public var filteredProjects: [Project] {
        if searchQuery.isEmpty {
            return projects
        }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.sourceMediaPath.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public func createAndStartDub(
        mediaURL: URL,
        projectName: String,
        options: DubOptions
    ) {
        let projId = UUID().uuidString
        let epId = UUID().uuidString
        let title = projectName.isEmpty ? mediaURL.deletingPathExtension().lastPathComponent : projectName

        let episode = Episode(
            id: epId,
            projectId: projId,
            title: title,
            sourceMediaPath: mediaURL.path
        )

        let project = Project(
            id: projId,
            name: title,
            sourceMediaPath: mediaURL.path,
            status: "RUNNING",
            episodes: [episode]
        )

        projectStore.addOrUpdateProject(project)
        refreshProjects()

        let jobId = UUID().uuidString
        self.activeJob = JobState(
            id: jobId,
            episodeId: epId,
            projectId: projId,
            status: .running,
            stage: .preparing,
            progress: 2.0
        )
        self.currentScreen = .processing(jobId: jobId)

        activeTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let (_, qa) = try await self.orchestrator.run(
                    project: project,
                    episode: episode,
                    options: options
                ) { [weak self] state in
                    Task { @MainActor [weak self] in
                        self?.activeJob = state
                    }
                }

                self.activeQAReport = qa
                self.refreshProjects()
                self.currentScreen = .finishedVideo(projectId: projId, episodeId: epId)
            } catch {
                self.activeJob?.status = .failed
                self.activeJob?.errorMessage = error.localizedDescription
                self.refreshProjects()
            }
        }
    }

    public func pauseActiveJob() {
        orchestrator.pause()
        activeJob?.status = .paused
    }

    public func resumeActiveJob() {
        orchestrator.resume()
        activeJob?.status = .running
    }

    public func cancelActiveJob() {
        orchestrator.cancel()
        activeTask?.cancel()
        activeJob?.status = .cancelled
        currentScreen = .home
        refreshProjects()
    }

    public func openEditor(projectId: String, episodeId: String) {
        currentScreen = .editor(projectId: projectId, episodeId: episodeId)
    }

    public func openFinishedVideo(projectId: String, episodeId: String) {
        currentScreen = .finishedVideo(projectId: projectId, episodeId: episodeId)
    }

    public func deleteProject(_ project: Project) {
        projectStore.deleteProject(id: project.id)
        refreshProjects()
    }
}
