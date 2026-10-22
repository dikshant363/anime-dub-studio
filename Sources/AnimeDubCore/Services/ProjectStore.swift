import Foundation

public final class ProjectStore: @unchecked Sendable {
    public static let shared = ProjectStore()

    public let baseStorageDirectory: URL

    private let projectsFileURL: URL
    private let queue = DispatchQueue(label: "com.animedubstudio.projectstore", attributes: .concurrent)

    public init(baseDirectory: URL? = nil) {
        if let dir = baseDirectory {
            self.baseStorageDirectory = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseStorageDirectory = appSupport.appendingPathComponent("Anime Dub Studio", isDirectory: true)
        }
        self.projectsFileURL = self.baseStorageDirectory.appendingPathComponent("projects.json")
        try? FileManager.default.createDirectory(at: self.baseStorageDirectory, withIntermediateDirectories: true)
    }

    public func projectDirectory(for projectId: String) -> URL {
        let dir = baseStorageDirectory.appendingPathComponent("projects/\(projectId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func episodeDirectory(for projectId: String, episodeId: String) -> URL {
        let dir = projectDirectory(for: projectId).appendingPathComponent("episodes/\(episodeId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func loadProjects() -> [Project] {
        queue.sync {
            guard FileManager.default.fileExists(atPath: projectsFileURL.path),
                  let data = try? Data(contentsOf: projectsFileURL),
                  let projects = try? JSONDecoder().decode([Project].self, from: data) else {
                return []
            }
            return projects
        }
    }

    public func saveProjects(_ projects: [Project]) {
        queue.sync(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(projects) {
                try? data.write(to: self.projectsFileURL, options: .atomic)
            }
        }
    }

    public func addOrUpdateProject(_ project: Project) {
        var current = loadProjects()
        if let idx = current.firstIndex(where: { $0.id == project.id }) {
            current[idx] = project
        } else {
            current.insert(project, at: 0)
        }
        saveProjects(current)
    }

    public func deleteProject(id: String) {
        var current = loadProjects()
        current.removeAll(where: { $0.id == id })
        saveProjects(current)

        let dir = projectDirectory(for: id)
        try? FileManager.default.removeItem(at: dir)
    }

    public func saveDialogueSegments(_ segments: [DialogueSegment], for episodeId: String, in projectId: String) {
        let file = episodeDirectory(for: projectId, episodeId: episodeId).appendingPathComponent("segments.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(segments) {
            try? data.write(to: file, options: .atomic)
        }
    }

    public func loadDialogueSegments(for episodeId: String, in projectId: String) -> [DialogueSegment] {
        let file = episodeDirectory(for: projectId, episodeId: episodeId).appendingPathComponent("segments.json")
        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let segments = try? JSONDecoder().decode([DialogueSegment].self, from: data) else {
            return []
        }
        return segments
    }

    public func saveCharacterProfiles(_ profiles: [CharacterProfile], for projectId: String) {
        let file = projectDirectory(for: projectId).appendingPathComponent("characters.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: file, options: .atomic)
        }
    }

    public func loadCharacterProfiles(for projectId: String) -> [CharacterProfile] {
        let file = projectDirectory(for: projectId).appendingPathComponent("characters.json")
        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let profiles = try? JSONDecoder().decode([CharacterProfile].self, from: data),
              !profiles.isEmpty else {
            return CharacterProfile.defaultCast
        }
        return profiles
    }
}
