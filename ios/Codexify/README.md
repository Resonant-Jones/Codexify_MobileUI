# ModelRouter - Codexify LLM Provider Router

🚀 **Phase One: Codexify:Scout**

A modular Swift module for routing LLM requests across multiple providers with secure API key management, automatic fallback, and usage tracking.

## Features

✅ **Multi-Provider Support**
- OpenAI (GPT-4, GPT-3.5, etc.)
- Claude (Sonnet, Opus, Haiku)
- Local models (placeholder for future integration)

✅ **Secure Key Management**
- iOS Keychain integration for API key storage
- No hardcoded credentials
- Thread-safe operations

✅ **Smart Routing**
- Automatic provider selection
- Fallback mechanism when primary provider fails
- Configurable provider preferences

✅ **Usage Analytics**
- Track requests per provider
- In-memory usage statistics
- Thread-safe counter implementation

✅ **Error Handling**
- Comprehensive error types
- Detailed error messages
- Graceful failure handling

## Architecture

```
ModelRouter
├── ProviderConfig          # Provider configuration model
├── UserProviderPreferences # User preference management
├── KeychainManager         # Secure API key storage
├── UsageTracker            # Request tracking & analytics
├── ModelRouter             # Main routing logic
└── Error Handling          # Custom error types
```

## Quick Start

### 1. Installation

Add `ModelRouter.swift` to your Xcode project:

```bash
ios/Codexify/Sources/ModelRouter.swift
```

### 2. Basic Setup

```swift
import Foundation

// Initialize with default configuration (OpenAI primary, Claude fallback)
let router = ModelRouter(preferences: .defaultConfiguration())

// Store API keys securely in Keychain
do {
    try KeychainManager.shared.storeAPIKey("sk-your-openai-key", for: "OpenAI")
    try KeychainManager.shared.storeAPIKey("sk-ant-your-claude-key", for: "Claude")
} catch {
    print("Failed to store API keys: \(error)")
}
```

### 3. Make a Request

```swift
Task {
    do {
        let response = try await router.routeRequest("Explain Swift concurrency")
        print("Response: \(response)")
    } catch {
        print("Error: \(error)")
    }
}
```

## Configuration Options

### Default Configuration (OpenAI + Claude Fallback)

```swift
let router = ModelRouter(preferences: .defaultConfiguration())
```

### Custom Configuration

```swift
// Configure OpenAI with custom endpoint and model
let openAI = ProviderConfig(
    type: .openai,
    name: "OpenAI",
    endpoint: "https://api.openai.com/v1/chat/completions",
    model: "gpt-4-turbo",
    requiresAuth: true
)

// Configure Claude
let claude = ProviderConfig(
    type: .claude,
    name: "Claude",
    endpoint: "https://api.anthropic.com/v1/messages",
    model: "claude-3-5-sonnet-20241022",
    requiresAuth: true
)

// Configure local model
let local = ProviderConfig(
    type: .local,
    name: "LocalModel",
    endpoint: nil,
    model: "custom-model",
    requiresAuth: false
)

// Create preferences with fallback chain
let preferences = UserProviderPreferences(
    defaultProvider: openAI,
    fallbackProviders: [claude, local],
    enableFallback: true
)

let router = ModelRouter(preferences: preferences)
```

### Local-Only Configuration

```swift
let router = ModelRouter(preferences: .localOnlyConfiguration())
```

## API Reference

### ModelRouter

#### `routeRequest(_ input: String) async throws -> String`

Routes a request to the configured default provider with automatic fallback.

**Parameters:**
- `input`: User prompt/input string

**Returns:** Model response as String

**Throws:** `ModelRouterError` if all providers fail

**Example:**
```swift
let response = try await router.routeRequest("What is Swift?")
```

#### `tryFallbackProvider(_ input: String) async throws -> String`

Attempts to use fallback providers when the default provider fails.

**Parameters:**
- `input`: User prompt/input string

**Returns:** Model response from first successful fallback provider

**Throws:** `ModelRouterError.allProvidersFailed` if all fallbacks fail

### KeychainManager

#### `storeAPIKey(_ key: String, for provider: String) throws`

Securely stores an API key in iOS Keychain.

**Parameters:**
- `key`: API key string
- `provider`: Provider identifier (e.g., "OpenAI", "Claude")

**Example:**
```swift
try KeychainManager.shared.storeAPIKey("sk-your-key", for: "OpenAI")
```

#### `retrieveAPIKey(for provider: String) throws -> String`

Retrieves an API key from Keychain.

**Parameters:**
- `provider`: Provider identifier

**Returns:** API key string

**Throws:** `ModelRouterError.noAPIKeyFound` if key doesn't exist

#### `deleteAPIKey(for provider: String)`

Deletes a specific API key from Keychain.

#### `deleteAllAPIKeys()`

Deletes all stored API keys.

### UsageTracker

#### `incrementUsage(for provider: String)`

Increments the usage counter for a provider (called automatically by ModelRouter).

#### `getUsage(for provider: String) -> Int`

Gets the usage count for a specific provider.

#### `getAllUsage() -> [String: Int]`

Returns all usage statistics as a dictionary.

#### `printUsageStats()`

Prints formatted usage statistics to console.

**Example:**
```swift
UsageTracker.shared.printUsageStats()

// Output:
// 📊 ===== Provider Usage Statistics =====
// OpenAI: 42 requests
// Claude: 15 requests
// ======================================
```

#### `resetUsage()`

Resets all usage counters to zero.

## Error Handling

The module uses a comprehensive error enum:

```swift
enum ModelRouterError: Error {
    case noAPIKeyFound(provider: String)
    case invalidConfiguration(message: String)
    case providerUnavailable(provider: String)
    case networkError(Error)
    case invalidResponse(statusCode: Int)
    case decodingError(Error)
    case allProvidersFailed
    case localModelNotImplemented
}
```

### Error Handling Example

```swift
do {
    let response = try await router.routeRequest(input)
    print(response)
} catch ModelRouterError.noAPIKeyFound(let provider) {
    print("Please configure API key for \(provider)")
} catch ModelRouterError.allProvidersFailed {
    print("All providers are currently unavailable")
} catch ModelRouterError.localModelNotImplemented {
    print("Local model support coming soon")
} catch {
    print("Unexpected error: \(error)")
}
```

## Integration TODOs

### 1. Local Model Integration

The `runLocalModel` method is currently a placeholder. To integrate a local model:

**Location:** `ModelRouter.swift:437`

```swift
private func runLocalModel(input: String) async throws -> String {
    // TODO: Integrate with your local model engine
    // Options:
    // - CoreML model
    // - ONNX Runtime
    // - MLX framework
    // - llama.cpp Swift wrapper

    // Example:
    // return try await LocalModelEngine.shared.inference(input: input)
}
```

**Recommended Frameworks:**
- **CoreML**: For Apple-optimized models
- **MLX**: For Apple Silicon optimization
- **ONNX Runtime**: Cross-platform inference
- **llama.cpp**: For LLaMA-based models

### 2. UI Integration

Create a settings view for managing providers:

```swift
struct ProviderSettingsView: View {
    @State private var openAIKey = ""
    @State private var claudeKey = ""

    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("OpenAI API Key", text: $openAIKey)
                SecureField("Claude API Key", text: $claudeKey)

                Button("Save Keys") {
                    saveKeys()
                }
            }

            Section("Usage Statistics") {
                UsageStatsView()
            }
        }
    }

    func saveKeys() {
        do {
            try KeychainManager.shared.storeAPIKey(openAIKey, for: "OpenAI")
            try KeychainManager.shared.storeAPIKey(claudeKey, for: "Claude")
        } catch {
            print("Error saving keys: \(error)")
        }
    }
}
```

### 3. Network Layer Enhancements

Consider adding:
- Request retry logic with exponential backoff
- Timeout configuration
- Network reachability checking
- Response caching

### 4. Advanced Features

**Streaming Support:**
```swift
func streamRequest(_ input: String) -> AsyncThrowingStream<String, Error> {
    // TODO: Implement streaming for real-time responses
}
```

**Batch Requests:**
```swift
func batchRequest(_ inputs: [String]) async throws -> [String] {
    // TODO: Implement concurrent batch processing
}
```

**Cost Tracking:**
```swift
class CostTracker {
    // TODO: Track token usage and estimated costs per provider
}
```

## Testing

### Unit Tests Example

```swift
import XCTest
@testable import Codexify

class ModelRouterTests: XCTestCase {

    func testKeychainStorage() throws {
        let manager = KeychainManager.shared
        let testKey = "test-api-key-12345"

        try manager.storeAPIKey(testKey, for: "TestProvider")
        let retrieved = try manager.retrieveAPIKey(for: "TestProvider")

        XCTAssertEqual(testKey, retrieved)

        manager.deleteAPIKey(for: "TestProvider")
    }

    func testUsageTracking() {
        let tracker = UsageTracker.shared
        tracker.resetUsage()

        tracker.incrementUsage(for: "TestProvider")
        tracker.incrementUsage(for: "TestProvider")

        XCTAssertEqual(tracker.getUsage(for: "TestProvider"), 2)
    }

    func testProviderConfiguration() {
        let config = ProviderConfig(
            type: .openai,
            name: "TestOpenAI",
            model: "gpt-4"
        )

        XCTAssertEqual(config.type, .openai)
        XCTAssertEqual(config.name, "TestOpenAI")
        XCTAssertTrue(config.requiresAuth)
    }
}
```

## Performance Considerations

- **Keychain operations**: Thread-safe but should be called from background threads
- **Usage tracking**: Uses concurrent DispatchQueue for thread safety
- **Network requests**: Fully async/await compatible
- **Memory**: Usage stats stored in memory (consider persistence for production)

## Security Best Practices

1. ✅ Never hardcode API keys
2. ✅ Use Keychain for secure storage
3. ✅ Validate SSL certificates (URLSession default behavior)
4. ⚠️ Consider implementing certificate pinning for production
5. ⚠️ Add request signing for custom endpoints
6. ⚠️ Implement rate limiting to prevent abuse

## Logging

The module includes comprehensive logging with emojis for easy identification:

- 🚀 Initialization
- 📨 Request routing
- ✅ Success
- ❌ Failure
- ⚠️ Warning
- 🔄 Fallback attempts
- 📊 Usage statistics
- 🤖 Local model operations

## SwiftUI Integration Example

```swift
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false

    private let router: ModelRouter

    init() {
        self.router = ModelRouter(preferences: .defaultConfiguration())
    }

    func sendMessage(_ text: String) async {
        isLoading = true

        do {
            let response = try await router.routeRequest(text)
            messages.append(Message(text: response, isUser: false))
        } catch {
            messages.append(Message(text: "Error: \(error.localizedDescription)", isUser: false))
        }

        isLoading = false
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(viewModel.messages) { message in
                    MessageRow(message: message)
                }
            }

            HStack {
                TextField("Type a message...", text: $inputText)
                Button("Send") {
                    Task {
                        await viewModel.sendMessage(inputText)
                        inputText = ""
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}
```

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 13.0+

## License

Part of the Codexify project.

## Support

For issues and questions:
- Check the inline code documentation
- Review the example usage in ModelRouter.swift
- Refer to provider API documentation:
  - [OpenAI API Docs](https://platform.openai.com/docs)
  - [Claude API Docs](https://docs.anthropic.com)

## Roadmap

- [ ] Streaming response support
- [ ] CoreML/MLX local model integration
- [ ] Response caching layer
- [ ] Cost tracking and analytics
- [ ] Multi-modal support (images, audio)
- [ ] Batch request processing
- [ ] Custom plugin system for new providers
- [ ] SwiftUI example app

---

**Built with ❤️ by Codexify:Scout**
