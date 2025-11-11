//
//  ExampleUsage.swift
//  Codexify
//
//  Example usage scenarios for ModelRouter
//

import Foundation
import SwiftUI

// MARK: - Example 1: Basic Setup and Single Request

func example1_BasicUsage() async {
    print("\n========== Example 1: Basic Usage ==========\n")

    // Initialize router with default configuration
    let router = ModelRouter(preferences: .defaultConfiguration())

    // Store API keys (do this once, typically during app setup)
    do {
        // In a real app, get these from user input or secure configuration
        try KeychainManager.shared.storeAPIKey("sk-your-openai-api-key", for: "OpenAI")
        try KeychainManager.shared.storeAPIKey("sk-ant-your-claude-api-key", for: "Claude")
        print("✅ API keys stored successfully\n")
    } catch {
        print("❌ Failed to store API keys: \(error)\n")
        return
    }

    // Make a request
    do {
        print("📤 Sending request...\n")
        let response = try await router.routeRequest("Explain the async/await pattern in Swift in one sentence.")
        print("📥 Response: \(response)\n")
    } catch {
        print("❌ Request failed: \(error)\n")
    }

    // View usage statistics
    UsageTracker.shared.printUsageStats()
}

// MARK: - Example 2: Custom Configuration with Multiple Fallbacks

func example2_CustomConfiguration() async {
    print("\n========== Example 2: Custom Configuration ==========\n")

    // Configure OpenAI with specific model
    let openAI = ProviderConfig(
        type: .openai,
        name: "OpenAI-GPT4",
        endpoint: nil, // Use default
        model: "gpt-4-turbo",
        requiresAuth: true
    )

    // Configure Claude as fallback
    let claude = ProviderConfig(
        type: .claude,
        name: "Claude-Sonnet",
        endpoint: nil, // Use default
        model: "claude-3-5-sonnet-20241022",
        requiresAuth: true
    )

    // Configure local model as final fallback
    let local = ProviderConfig(
        type: .local,
        name: "LocalModel",
        endpoint: nil,
        model: "custom-model-v1",
        requiresAuth: false
    )

    // Create preferences with fallback chain
    let preferences = UserProviderPreferences(
        defaultProvider: openAI,
        fallbackProviders: [claude, local],
        enableFallback: true
    )

    let router = ModelRouter(preferences: preferences)

    // Make request (will try OpenAI, then Claude, then Local if needed)
    do {
        let response = try await router.routeRequest("What are Swift property wrappers?")
        print("Response: \(response)\n")
    } catch {
        print("Error: \(error)\n")
    }

    UsageTracker.shared.printUsageStats()
}

// MARK: - Example 3: Error Handling

func example3_ErrorHandling() async {
    print("\n========== Example 3: Error Handling ==========\n")

    let router = ModelRouter(preferences: .defaultConfiguration())

    do {
        let response = try await router.routeRequest("Explain Swift generics")
        print("Success: \(response)\n")
    } catch ModelRouterError.noAPIKeyFound(let provider) {
        print("⚠️ No API key configured for \(provider)")
        print("Please add your API key in settings.\n")
    } catch ModelRouterError.invalidResponse(let statusCode) {
        print("⚠️ Server returned error code: \(statusCode)")
        print("Please check your API key and quota.\n")
    } catch ModelRouterError.networkError(let error) {
        print("⚠️ Network error: \(error.localizedDescription)")
        print("Please check your internet connection.\n")
    } catch ModelRouterError.allProvidersFailed {
        print("⚠️ All providers failed")
        print("Please try again later.\n")
    } catch {
        print("⚠️ Unexpected error: \(error)\n")
    }
}

// MARK: - Example 4: SwiftUI ViewModel Integration

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let router: ModelRouter

    init(router: ModelRouter = ModelRouter(preferences: .defaultConfiguration())) {
        self.router = router
    }

    func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = ChatMessage(id: UUID(), text: text, isUser: true, timestamp: Date())
        messages.append(userMessage)

        isLoading = true
        errorMessage = nil

        do {
            let response = try await router.routeRequest(text)

            // Add AI response
            let aiMessage = ChatMessage(id: UUID(), text: response, isUser: false, timestamp: Date())
            messages.append(aiMessage)

        } catch {
            errorMessage = error.localizedDescription

            // Add error message to chat
            let errorMsg = ChatMessage(
                id: UUID(),
                text: "Error: \(error.localizedDescription)",
                isUser: false,
                timestamp: Date()
            )
            messages.append(errorMsg)
        }

        isLoading = false
    }

    func clearHistory() {
        messages.removeAll()
    }

    func viewUsageStats() {
        UsageTracker.shared.printUsageStats()
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - Example 5: SwiftUI Chat View

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""

    var body: some View {
        VStack {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    // Auto-scroll to bottom
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // Input area
            HStack {
                TextField("Ask anything...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isLoading)

                Button {
                    Task {
                        await viewModel.sendMessage(inputText)
                        inputText = ""
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(inputText.isEmpty || viewModel.isLoading)
            }
            .padding()
        }
        .navigationTitle("Codexify Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Clear History") {
                        viewModel.clearHistory()
                    }
                    Button("View Usage Stats") {
                        viewModel.viewUsageStats()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading) {
                Text(message.text)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Example 6: Settings View for API Keys

struct ProviderSettingsView: View {
    @State private var openAIKey = ""
    @State private var claudeKey = ""
    @State private var showingSaveAlert = false
    @State private var alertMessage = ""

    var body: some View {
        Form {
            Section {
                Text("Securely store your API keys")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("API Keys")
            }

            Section {
                SecureField("OpenAI API Key (sk-...)", text: $openAIKey)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                SecureField("Claude API Key (sk-ant-...)", text: $claudeKey)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                Button("Save Keys") {
                    saveKeys()
                }
                .disabled(openAIKey.isEmpty && claudeKey.isEmpty)
            }

            Section {
                Button("Delete All Keys", role: .destructive) {
                    KeychainManager.shared.deleteAllAPIKeys()
                    openAIKey = ""
                    claudeKey = ""
                    alertMessage = "All API keys deleted"
                    showingSaveAlert = true
                }
            }

            Section {
                UsageStatsView()
            } header: {
                Text("Usage Statistics")
            }
        }
        .navigationTitle("Provider Settings")
        .alert("Settings", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func saveKeys() {
        var savedCount = 0

        do {
            if !openAIKey.isEmpty {
                try KeychainManager.shared.storeAPIKey(openAIKey, for: "OpenAI")
                savedCount += 1
            }

            if !claudeKey.isEmpty {
                try KeychainManager.shared.storeAPIKey(claudeKey, for: "Claude")
                savedCount += 1
            }

            alertMessage = "Successfully saved \(savedCount) API key(s)"
            openAIKey = ""
            claudeKey = ""
        } catch {
            alertMessage = "Failed to save keys: \(error.localizedDescription)"
        }

        showingSaveAlert = true
    }
}

struct UsageStatsView: View {
    @State private var usageStats: [String: Int] = [:]
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if usageStats.isEmpty {
                Text("No usage data yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(usageStats.sorted(by: { $0.value > $1.value }), id: \.key) { provider, count in
                    HStack {
                        Text(provider)
                        Spacer()
                        Text("\(count) requests")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button("Reset Statistics") {
                UsageTracker.shared.resetUsage()
                updateStats()
            }
            .buttonStyle(.borderless)
        }
        .onAppear {
            updateStats()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func updateStats() {
        usageStats = UsageTracker.shared.getAllUsage()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            updateStats()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Example 7: Batch Processing

func example7_BatchProcessing() async {
    print("\n========== Example 7: Batch Processing ==========\n")

    let router = ModelRouter(preferences: .defaultConfiguration())

    let questions = [
        "What is Swift?",
        "Explain closures in Swift",
        "What are protocols?"
    ]

    print("Processing \(questions.count) questions concurrently...\n")

    await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
        for (index, question) in questions.enumerated() {
            group.addTask {
                do {
                    let response = try await router.routeRequest(question)
                    return (index, .success(response))
                } catch {
                    return (index, .failure(error))
                }
            }
        }

        for await (index, result) in group {
            switch result {
            case .success(let response):
                print("✅ Question \(index + 1): \(questions[index])")
                print("   Response: \(response)\n")
            case .failure(let error):
                print("❌ Question \(index + 1) failed: \(error)\n")
            }
        }
    }

    UsageTracker.shared.printUsageStats()
}

// MARK: - Example 8: Provider-Specific Requests

func example8_ProviderSpecificRequests() async {
    print("\n========== Example 8: Provider-Specific Requests ==========\n")

    // OpenAI-only router
    let openAIConfig = ProviderConfig(
        type: .openai,
        name: "OpenAI",
        model: "gpt-4"
    )

    let openAIPreferences = UserProviderPreferences(
        defaultProvider: openAIConfig,
        fallbackProviders: [],
        enableFallback: false
    )

    let openAIRouter = ModelRouter(preferences: openAIPreferences)

    // Claude-only router
    let claudeConfig = ProviderConfig(
        type: .claude,
        name: "Claude",
        model: "claude-3-5-sonnet-20241022"
    )

    let claudePreferences = UserProviderPreferences(
        defaultProvider: claudeConfig,
        fallbackProviders: [],
        enableFallback: false
    )

    let claudeRouter = ModelRouter(preferences: claudePreferences)

    // Compare responses
    let question = "What is functional programming?"

    print("🤖 Asking OpenAI...\n")
    do {
        let openAIResponse = try await openAIRouter.routeRequest(question)
        print("OpenAI: \(openAIResponse)\n")
    } catch {
        print("OpenAI Error: \(error)\n")
    }

    print("🤖 Asking Claude...\n")
    do {
        let claudeResponse = try await claudeRouter.routeRequest(question)
        print("Claude: \(claudeResponse)\n")
    } catch {
        print("Claude Error: \(error)\n")
    }

    UsageTracker.shared.printUsageStats()
}

// MARK: - Example 9: Complete App Example

@main
struct CodexifyApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                MainMenuView()
            }
        }
    }
}

struct MainMenuView: View {
    var body: some View {
        List {
            NavigationLink("Chat") {
                ChatView()
            }

            NavigationLink("Settings") {
                ProviderSettingsView()
            }

            NavigationLink("About") {
                AboutView()
            }
        }
        .navigationTitle("Codexify")
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Codexify")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Multi-Provider LLM Router")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "lock.shield", text: "Secure Keychain storage")
                FeatureRow(icon: "arrow.triangle.branch", text: "Smart fallback routing")
                FeatureRow(icon: "chart.bar", text: "Usage analytics")
                FeatureRow(icon: "server.rack", text: "Multi-provider support")
            }
            .padding()

            Spacer()

            Text("Phase One: Codexify:Scout")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("About")
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
        }
    }
}

// MARK: - Running Examples

/*
 To run these examples:

 1. Configure API keys:
    ```swift
    try? KeychainManager.shared.storeAPIKey("your-key", for: "OpenAI")
    try? KeychainManager.shared.storeAPIKey("your-key", for: "Claude")
    ```

 2. Run individual examples:
    ```swift
    Task {
        await example1_BasicUsage()
        await example2_CustomConfiguration()
        await example3_ErrorHandling()
        await example7_BatchProcessing()
        await example8_ProviderSpecificRequests()
    }
    ```

 3. Or use the SwiftUI app:
    - Run CodexifyApp
    - Configure keys in Settings
    - Start chatting!
 */
