import Foundation

public enum QAStatus: String, Codable, Sendable {
    case pass = "PASS"
    case warning = "WARNING"
    case fail = "FAIL"
}

public struct QAReport: Codable, Sendable {
    public let score: Double
    public let status: QAStatus
    public let warnings: [String]
    public let checksPassed: [String]

    public init(
        score: Double,
        status: QAStatus,
        warnings: [String] = [],
        checksPassed: [String] = []
    ) {
        self.score = score
        self.status = status
        self.warnings = warnings
        self.checksPassed = checksPassed
    }
}
