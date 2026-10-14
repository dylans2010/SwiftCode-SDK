import Foundation
import os
import SwiftCodeCore

private let logger = Logger(subsystem: "com.swiftcode.sdk", category: "OpenRouterClient")

public actor OpenRouterClient {
    public static let shared = OpenRouterClient()
    private var cachedModels: [OpenRouterModel] = []

    private init() {}

    @MainActor
    public static func resolveOpenRouterAPIKey() -> String {
        if let key = KeychainService.shared.get(forKey: KeychainService.openRouterAPIKey),
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let hyphenatedKey = KeychainService.shared.get(forKey: "openrouter-api-key"),
           !hyphenatedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return hyphenatedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"],
           !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    public func fetchModels() async throws -> [OpenRouterModel] {
        if !cachedModels.isEmpty {
            return cachedModels
        }
        logger.log("[fetchModels] Fetching models from OpenRouter.")
        let apiKey = await MainActor.run { OpenRouterClient.resolveOpenRouterAPIKey() }

        var urlRequest = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        if !apiKey.isEmpty {
            urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenRouterClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Response was not HTTPURLResponse."])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenRouterClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models from OpenRouter (Status: \(httpResponse.statusCode))"])
        }

        struct ModelsResponse: Codable {
            let data: [OpenRouterModel]
        }

        let decodedResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        self.cachedModels = decodedResponse.data
        return decodedResponse.data
    }
}
