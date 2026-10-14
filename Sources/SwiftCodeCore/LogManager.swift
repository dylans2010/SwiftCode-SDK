import Foundation
import Combine

public struct DeploymentLogLine: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let message: String
    public let isError: Bool

    public init(id: UUID = UUID(), timestamp: Date = Date(), message: String, isError: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.isError = isError
    }
}

@MainActor
final class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var deploymentLogs: [DeploymentLogLine] = []

    private init() {}

    func logDeployment(_ message: String, isError: Bool = false) {
        deploymentLogs.append(DeploymentLogLine(timestamp: Date(), message: message, isError: isError))
    }

    func clearDeploymentLogs() {
        deploymentLogs = []
    }
}
