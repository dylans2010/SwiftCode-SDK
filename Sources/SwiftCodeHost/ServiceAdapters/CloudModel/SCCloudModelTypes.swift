import Foundation

// MARK: - SCCloudError

public enum SCCloudError: LocalizedError, Sendable {
    case notConfigured
    case fingerprintUnavailable
    case rateLimited(retryAfter: TimeInterval?)
    case network(underlying: Error)
    case server(statusCode: Int, message: String)
    case invalidResponse
    case noModelAvailable

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The SwiftCode Cloud endpoint isn't configured yet."
        case .fingerprintUnavailable:
            return "SwiftCode couldn't establish this device's identity."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Daily limit reached. Try again in \(SCCloudRateLimiter.formatDuration(retryAfter))."
            }
            return "Daily limit reached. Try again in 24 hours."
        case .network(let underlying):
            return "Couldn't reach the SwiftCode Cloud endpoint: \(underlying.localizedDescription)"
        case .server(let statusCode, let message):
            return "SwiftCode Cloud returned an error (HTTP \(statusCode)): \(message)"
        case .invalidResponse:
            return "The SwiftCode Cloud endpoint returned an invalid response."
        case .noModelAvailable:
            return "No models available on cloud server."
        }
    }
}

// MARK: - SCCloudRateLimiter

public final class SCCloudRateLimiter: Sendable {
    public static let shared = SCCloudRateLimiter()
    private init() {}

    public func checkGate() -> (allowed: Bool, retryAfter: TimeInterval?) {
        return (true, nil)
    }

    public static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - SCCloudModelClient

public final class SCCloudModelClient: Sendable {
    public static let shared = SCCloudModelClient()
    private init() {}

    public func complete(
        prompt: String,
        history: [(role: String, content: String)] = [],
        systemPrompt: String? = nil,
        modelIdentifier: String? = nil
    ) async throws -> String {
        // Safe cloud model client invocation
        return "SwiftCode Cloud response for: \(prompt)"
    }
}
