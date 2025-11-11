//
//  ModelRouter.swift
//  Codexify
//
//  Created by Codexify:Scout
//  Phase One: LLM Provider Router with Keychain Integration
//

import Foundation
import Security

// MARK: - Provider Types

/// Supported LLM provider types
enum ProviderType: String, Codable {
    case local
    case openai
    case claude
}

// MARK: - Configuration Models

/// Configuration for an LLM provider
struct ProviderConfig: Codable {
    let type: ProviderType
    let name: String
    let endpoint: String?
    let model: String?
    let requiresAuth: Bool

    init(type: ProviderType, name: String, endpoint: String? = nil, model: String? = nil, requiresAuth: Bool = true) {
        self.type = type
        self.name = name
        self.endpoint = endpoint
        self.model = model
        self.requiresAuth = requiresAuth
    }
}

/// User preferences for provider configuration
struct UserProviderPreferences: Codable {
    let defaultProvider: ProviderConfig
    let fallbackProviders: [ProviderConfig]
    let enableFallback: Bool

    init(defaultProvider: ProviderConfig, fallbackProviders: [ProviderConfig] = [], enableFallback: Bool = true) {
        self.defaultProvider = defaultProvider
        self.fallbackProviders = fallbackProviders
        self.enableFallback = enableFallback
    }
}

// MARK: - Error Types

/// Errors that can occur during routing and provider operations
enum ModelRouterError: Error, LocalizedError {
    case noAPIKeyFound(provider: String)
    case invalidConfiguration(message: String)
    case providerUnavailable(provider: String)
    case networkError(Error)
    case invalidResponse(statusCode: Int)
    case decodingError(Error)
    case allProvidersFailed
    case localModelNotImplemented

    var errorDescription: String? {
        switch self {
        case .noAPIKeyFound(let provider):
            return "No API key found for provider: \(provider)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .providerUnavailable(let provider):
            return "Provider unavailable: \(provider)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "Invalid response with status code: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .allProvidersFailed:
            return "All providers failed to respond"
        case .localModelNotImplemented:
            return "Local model functionality not yet implemented"
        }
    }
}

// MARK: - Keychain Manager

/// Secure storage manager for API keys using iOS Keychain
class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.codexify.llm.apikeys"

    private init() {}

    /// Store an API key in the Keychain
    /// - Parameters:
    ///   - key: The API key to store
    ///   - provider: The provider name (used as account identifier)
    /// - Throws: Error if storage fails
    func storeAPIKey(_ key: String, for provider: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw ModelRouterError.invalidConfiguration(message: "Failed to encode API key")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider,
            kSecValueData as String: data
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw ModelRouterError.invalidConfiguration(message: "Failed to store API key: \(status)")
        }
    }

    /// Retrieve an API key from the Keychain
    /// - Parameter provider: The provider name
    /// - Returns: The API key if found
    /// - Throws: Error if retrieval fails or key not found
    func retrieveAPIKey(for provider: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw ModelRouterError.noAPIKeyFound(provider: provider)
        }

        return key
    }

    /// Delete an API key from the Keychain
    /// - Parameter provider: The provider name
    func deleteAPIKey(for provider: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Delete all stored API keys
    func deleteAllAPIKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Usage Statistics

/// Tracks usage statistics for each provider
class UsageTracker {
    static let shared = UsageTracker()

    private var providerUsage: [String: Int] = [:]
    private let queue = DispatchQueue(label: "com.codexify.usagetracker", attributes: .concurrent)

    private init() {}

    /// Increment usage count for a provider
    /// - Parameter provider: Provider name
    func incrementUsage(for provider: String) {
        queue.async(flags: .barrier) {
            self.providerUsage[provider, default: 0] += 1
            print("📊 [UsageTracker] \(provider): \(self.providerUsage[provider]!) requests")
        }
    }

    /// Get usage count for a specific provider
    /// - Parameter provider: Provider name
    /// - Returns: Usage count
    func getUsage(for provider: String) -> Int {
        return queue.sync {
            return providerUsage[provider, default: 0]
        }
    }

    /// Get all usage statistics
    /// - Returns: Dictionary of provider names to usage counts
    func getAllUsage() -> [String: Int] {
        return queue.sync {
            return providerUsage
        }
    }

    /// Reset usage statistics
    func resetUsage() {
        queue.async(flags: .barrier) {
            self.providerUsage.removeAll()
            print("📊 [UsageTracker] Usage statistics reset")
        }
    }

    /// Print usage statistics
    func printUsageStats() {
        let stats = getAllUsage()
        print("\n📊 ===== Provider Usage Statistics =====")
        if stats.isEmpty {
            print("No usage data available")
        } else {
            for (provider, count) in stats.sorted(by: { $0.value > $1.value }) {
                print("\(provider): \(count) requests")
            }
        }
        print("======================================\n")
    }
}

// MARK: - API Response Models

/// Response from OpenAI API
struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

/// Response from Claude API
struct ClaudeResponse: Codable {
    struct Content: Codable {
        let type: String
        let text: String
    }
    let content: [Content]
}

// MARK: - Model Router

/// Main router class for handling LLM provider requests
class ModelRouter {

    private let preferences: UserProviderPreferences
    private let keychainManager = KeychainManager.shared
    private let usageTracker = UsageTracker.shared

    /// Initialize with user preferences
    /// - Parameter preferences: User provider preferences
    init(preferences: UserProviderPreferences) {
        self.preferences = preferences
        print("🚀 [ModelRouter] Initialized with default provider: \(preferences.defaultProvider.name)")
    }

    // MARK: - Public API

    /// Route a request to the appropriate LLM provider
    /// - Parameter input: User input/prompt
    /// - Returns: Model response string
    /// - Throws: ModelRouterError if routing fails
    func routeRequest(_ input: String) async throws -> String {
        print("📨 [ModelRouter] Routing request to \(preferences.defaultProvider.name)")

        do {
            let response = try await sendRequest(input, to: preferences.defaultProvider)
            usageTracker.incrementUsage(for: preferences.defaultProvider.name)
            return response
        } catch {
            print("⚠️ [ModelRouter] Default provider failed: \(error.localizedDescription)")

            if preferences.enableFallback {
                return try await tryFallbackProvider(input)
            } else {
                throw error
            }
        }
    }

    /// Try fallback providers if the default provider fails
    /// - Parameter input: User input/prompt
    /// - Returns: Model response string
    /// - Throws: ModelRouterError.allProvidersFailed if all providers fail
    func tryFallbackProvider(_ input: String) async throws -> String {
        print("🔄 [ModelRouter] Attempting fallback providers...")

        for (index, provider) in preferences.fallbackProviders.enumerated() {
            print("🔄 [ModelRouter] Trying fallback provider \(index + 1)/\(preferences.fallbackProviders.count): \(provider.name)")

            do {
                let response = try await sendRequest(input, to: provider)
                usageTracker.incrementUsage(for: provider.name)
                print("✅ [ModelRouter] Fallback provider \(provider.name) succeeded")
                return response
            } catch {
                print("❌ [ModelRouter] Fallback provider \(provider.name) failed: \(error.localizedDescription)")
                continue
            }
        }

        throw ModelRouterError.allProvidersFailed
    }

    // MARK: - Private Methods

    /// Send request to a specific provider
    /// - Parameters:
    ///   - input: User input/prompt
    ///   - provider: Provider configuration
    /// - Returns: Model response string
    /// - Throws: ModelRouterError if request fails
    private func sendRequest(_ input: String, to provider: ProviderConfig) async throws -> String {
        switch provider.type {
        case .local:
            return try await runLocalModel(input: input)

        case .openai:
            return try await sendOpenAIRequest(input, config: provider)

        case .claude:
            return try await sendClaudeRequest(input, config: provider)
        }
    }

    /// Send request to OpenAI API
    /// - Parameters:
    ///   - input: User input/prompt
    ///   - config: Provider configuration
    /// - Returns: Model response string
    /// - Throws: ModelRouterError if request fails
    private func sendOpenAIRequest(_ input: String, config: ProviderConfig) async throws -> String {
        let endpoint = config.endpoint ?? "https://api.openai.com/v1/chat/completions"
        let model = config.model ?? "gpt-4"

        guard let url = URL(string: endpoint) else {
            throw ModelRouterError.invalidConfiguration(message: "Invalid OpenAI endpoint")
        }

        // Get API key from Keychain
        let apiKey = try keychainManager.retrieveAPIKey(for: config.name)

        // Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": input]
            ],
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelRouterError.invalidResponse(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ModelRouterError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        // Decode response
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let firstChoice = openAIResponse.choices.first else {
                throw ModelRouterError.invalidConfiguration(message: "No choices in OpenAI response")
            }
            return firstChoice.message.content
        } catch {
            throw ModelRouterError.decodingError(error)
        }
    }

    /// Send request to Claude API
    /// - Parameters:
    ///   - input: User input/prompt
    ///   - config: Provider configuration
    /// - Returns: Model response string
    /// - Throws: ModelRouterError if request fails
    private func sendClaudeRequest(_ input: String, config: ProviderConfig) async throws -> String {
        let endpoint = config.endpoint ?? "https://api.anthropic.com/v1/messages"
        let model = config.model ?? "claude-3-5-sonnet-20241022"

        guard let url = URL(string: endpoint) else {
            throw ModelRouterError.invalidConfiguration(message: "Invalid Claude endpoint")
        }

        // Get API key from Keychain
        let apiKey = try keychainManager.retrieveAPIKey(for: config.name)

        // Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": input]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelRouterError.invalidResponse(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ModelRouterError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        // Decode response
        do {
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            guard let firstContent = claudeResponse.content.first else {
                throw ModelRouterError.invalidConfiguration(message: "No content in Claude response")
            }
            return firstContent.text
        } catch {
            throw ModelRouterError.decodingError(error)
        }
    }

    /// Run local model (placeholder for future implementation)
    /// - Parameter input: User input/prompt
    /// - Returns: Model response string
    /// - Throws: ModelRouterError.localModelNotImplemented
    private func runLocalModel(input: String) async throws -> String {
        // TODO: Integrate with local model engine
        // This could be:
        // - CoreML model
        // - ONNX Runtime
        // - MLX framework
        // - Custom inference engine

        print("🤖 [ModelRouter] Local model request received")
        print("📝 [ModelRouter] Input: \(input)")

        // Placeholder response
        throw ModelRouterError.localModelNotImplemented

        // Example implementation structure:
        // return try await LocalModelEngine.shared.inference(input: input)
    }
}

// MARK: - Convenience Extensions

extension ModelRouter {

    /// Create a default configuration with OpenAI as primary and Claude as fallback
    /// - Returns: UserProviderPreferences with sensible defaults
    static func defaultConfiguration() -> UserProviderPreferences {
        let openAI = ProviderConfig(
            type: .openai,
            name: "OpenAI",
            endpoint: nil, // Uses default
            model: "gpt-4",
            requiresAuth: true
        )

        let claude = ProviderConfig(
            type: .claude,
            name: "Claude",
            endpoint: nil, // Uses default
            model: "claude-3-5-sonnet-20241022",
            requiresAuth: true
        )

        return UserProviderPreferences(
            defaultProvider: openAI,
            fallbackProviders: [claude],
            enableFallback: true
        )
    }

    /// Create a local-only configuration
    /// - Returns: UserProviderPreferences with local provider
    static func localOnlyConfiguration() -> UserProviderPreferences {
        let local = ProviderConfig(
            type: .local,
            name: "Local",
            endpoint: nil,
            model: nil,
            requiresAuth: false
        )

        return UserProviderPreferences(
            defaultProvider: local,
            fallbackProviders: [],
            enableFallback: false
        )
    }
}

// MARK: - Example Usage

/*

 // Example 1: Initialize with default configuration
 let router = ModelRouter(preferences: .defaultConfiguration())

 // Store API keys securely
 try? KeychainManager.shared.storeAPIKey("your-openai-api-key", for: "OpenAI")
 try? KeychainManager.shared.storeAPIKey("your-claude-api-key", for: "Claude")

 // Make a request
 Task {
     do {
         let response = try await router.routeRequest("Explain Swift concurrency")
         print("Response: \(response)")
     } catch {
         print("Error: \(error)")
     }
 }

 // Example 2: Custom configuration
 let customOpenAI = ProviderConfig(
     type: .openai,
     name: "CustomOpenAI",
     endpoint: "https://your-custom-endpoint.com/v1/chat/completions",
     model: "gpt-4-turbo",
     requiresAuth: true
 )

 let customPreferences = UserProviderPreferences(
     defaultProvider: customOpenAI,
     fallbackProviders: [],
     enableFallback: false
 )

 let customRouter = ModelRouter(preferences: customPreferences)

 // Example 3: View usage statistics
 UsageTracker.shared.printUsageStats()

 // Example 4: Fallback handling
 let robustPreferences = UserProviderPreferences(
     defaultProvider: openAI,
     fallbackProviders: [claude],
     enableFallback: true
 )

 let robustRouter = ModelRouter(preferences: robustPreferences)

 */
