//
//  ContextBrokerExamples.swift
//  Codexify
//
//  Example usage scenarios for ContextBroker
//  Sovereign Mobile RAG Node Examples
//

import Foundation
import SwiftUI

// MARK: - Example 1: Basic Context Building

func example1_BasicContextBuilding() async {
    print("\n========== Example 1: Basic Context Building ==========\n")

    // Initialize context broker with default thread
    let threadId = ThreadStorage.defaultThreadId
    let broker = ContextBroker(threadId: threadId)

    do {
        // Build context for a user prompt
        let context = try await broker.buildContext(forPrompt: "How do I use async/await in Swift?")

        // Print context summary
        print(context.summary)
        print("\n" + context.formatForPrompt())

    } catch {
        print("❌ Failed to build context: \(error)")
    }
}

// MARK: - Example 2: RAG-Enhanced Chat

func example2_RAGEnhancedChat() async {
    print("\n========== Example 2: RAG-Enhanced Chat ==========\n")

    let threadId = UUID()
    let contextBroker = ContextBroker(threadId: threadId)
    let modelRouter = ModelRouter(preferences: .defaultConfiguration())

    // Store some memory fragments first
    let memoryStore = VectorStore.shared

    let knowledgeItems = [
        "Swift uses value semantics for structs and reference semantics for classes.",
        "The async/await pattern in Swift provides structured concurrency.",
        "CoreML allows you to run machine learning models efficiently on iOS devices."
    ]

    for item in knowledgeItems {
        // In production, generate real embeddings
        let embedding = [Float](repeating: 0.5, count: 384)
        let fragment = MemoryFragment(
            content: item,
            embedding: embedding,
            source: .document
        )
        try? await memoryStore.store(fragment)
    }

    // Now make a RAG-enhanced request
    let userQuestion = "What's the difference between structs and classes in Swift?"

    do {
        // Step 1: Build context
        print("📦 Building context...")
        let context = try await contextBroker.buildContext(forPrompt: userQuestion)

        // Step 2: Create RAG prompt
        let ragPrompt = """
        Context Information:
        \(context.formatForPrompt())

        User Question: \(userQuestion)

        Please answer based on the context provided above. If the context doesn't contain relevant information, say so.
        """

        print("📤 Sending RAG-enhanced prompt to LLM...\n")

        // Step 3: Get LLM response (in real use with API keys configured)
        // let response = try await modelRouter.routeRequest(ragPrompt)
        // print("🤖 Response: \(response)\n")

        print("✅ RAG prompt prepared:")
        print(ragPrompt)

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 3: Custom Configuration

func example3_CustomConfiguration() async {
    print("\n========== Example 3: Custom Configuration ==========\n")

    let threadId = UUID()

    // Create custom configuration
    let customConfig = ContextBroker.Configuration(
        maxRecentMessages: 10,
        maxSemanticMemories: 8,
        semanticSimilarityThreshold: 0.7,
        includeSystemMessages: true,
        includeSensorData: true,
        timeoutSeconds: 5.0
    )

    let broker = ContextBroker(threadId: threadId, config: customConfig)

    do {
        let context = try await broker.buildContext(forPrompt: "Explain Swift protocols")

        print("Context built with custom config:")
        print("- Messages: \(context.threadHistory.count)")
        print("- Memories: \(context.semanticMemory.count)")
        print("- Build time: \(context.metadata?.buildDuration ?? 0)s")

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 4: Memory Management

func example4_MemoryManagement() async {
    print("\n========== Example 4: Memory Management ==========\n")

    let vectorStore = VectorStore.shared

    // Store multiple memory fragments
    let memories = [
        ("Swift concurrency uses structured tasks", MemoryFragment.MemorySource.conversation),
        ("CoreML supports neural networks on iOS", MemoryFragment.MemorySource.document),
        ("SwiftUI provides declarative UI building", MemoryFragment.MemorySource.web),
        ("Combine framework handles async events", MemoryFragment.MemorySource.conversation)
    ]

    print("💾 Storing memory fragments...\n")

    for (content, source) in memories {
        // Generate embedding (stub)
        let embedding = [Float](repeating: Float.random(in: 0...1), count: 384)

        let fragment = MemoryFragment(
            content: content,
            embedding: embedding,
            source: source,
            metadata: MemoryFragment.MemoryMetadata(
                tags: ["swift", "ios"],
                location: nil,
                context: "Learning session",
                importance: 0.8,
                accessCount: 0,
                lastAccessed: nil
            )
        )

        try? await vectorStore.store(fragment)
        print("✅ Stored: \(content)")
    }

    // Search for similar memories
    print("\n🔍 Searching for similar memories...\n")

    do {
        let results = try await vectorStore.search(
            query: "How does Swift handle concurrency?",
            limit: 3,
            threshold: 0.3
        )

        print("Found \(results.count) relevant memories:")
        for (index, fragment) in results.enumerated() {
            print("\(index + 1). \(fragment.content)")
            print("   Source: \(fragment.source.rawValue)")
            print("   Importance: \(fragment.metadata?.importance ?? 0)\n")
        }

    } catch {
        print("❌ Search failed: \(error)")
    }
}

// MARK: - Example 5: SwiftUI Integration - Chat with RAG

@MainActor
class RAGChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var contextInfo: String = ""

    private let threadId: UUID
    private let contextBroker: ContextBroker
    private let modelRouter: ModelRouter
    private let threadStorage: ThreadStorage

    struct ChatMessage: Identifiable {
        let id: UUID
        let content: String
        let role: ThreadMessage.MessageRole
        let timestamp: Date
        let hasContext: Bool

        init(from threadMessage: ThreadMessage, hasContext: Bool = false) {
            self.id = threadMessage.id
            self.content = threadMessage.content
            self.role = threadMessage.role
            self.timestamp = threadMessage.timestamp
            self.hasContext = hasContext
        }
    }

    init() {
        self.threadId = UUID()
        self.contextBroker = ContextBroker(threadId: threadId)
        self.modelRouter = ModelRouter(preferences: .defaultConfiguration())
        self.threadStorage = ThreadStorage.shared
    }

    func sendMessage(_ content: String) async {
        // Add user message
        let userMessage = ThreadMessage(role: .user, content: content)
        try? await threadStorage.storeMessage(userMessage, threadId: threadId)

        messages.append(ChatMessage(from: userMessage))

        isLoading = true
        errorMessage = nil

        do {
            // Build context with RAG
            let context = try await contextBroker.buildContext(forPrompt: content)

            // Update context info for UI
            contextInfo = """
            📊 Context:
            - Messages: \(context.threadHistory.count)
            - Memories: \(context.semanticMemory.count)
            - Location: \(context.sensorSnapshot.location?.placeName ?? "Unknown")
            """

            // Create RAG-enhanced prompt
            let ragPrompt = """
            \(context.formatForPrompt())

            User: \(content)

            Assistant:
            """

            // Get response from LLM
            let response = try await modelRouter.routeRequest(ragPrompt)

            // Store assistant message
            let assistantMessage = ThreadMessage(role: .assistant, content: response)
            try? await threadStorage.storeMessage(assistantMessage, threadId: threadId)

            messages.append(ChatMessage(from: assistantMessage, hasContext: true))

        } catch {
            errorMessage = error.localizedDescription

            let errorMsg = ThreadMessage(
                role: .assistant,
                content: "Error: \(error.localizedDescription)"
            )
            messages.append(ChatMessage(from: errorMsg))
        }

        isLoading = false
    }

    func clearHistory() {
        messages.removeAll()
    }
}

struct RAGChatView: View {
    @StateObject private var viewModel = RAGChatViewModel()
    @State private var inputText = ""
    @State private var showContextInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Context info banner
            if showContextInfo && !viewModel.contextInfo.isEmpty {
                Text(viewModel.contextInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
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
                TextField("Ask with context...", text: $inputText)
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
        .navigationTitle("RAG Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showContextInfo.toggle()
                    } label: {
                        Label(
                            showContextInfo ? "Hide Context Info" : "Show Context Info",
                            systemImage: "info.circle"
                        )
                    }

                    Button("Clear History") {
                        viewModel.clearHistory()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct MessageBubbleView: View {
    let message: RAGChatViewModel.ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(backgroundColor)
                        .foregroundColor(textColor)
                        .cornerRadius(16)

                    if message.hasContext {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private var backgroundColor: Color {
        message.role == .user ? .blue : .gray.opacity(0.2)
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }
}

// MARK: - Example 6: Sensor-Aware Context

func example6_SensorAwareContext() async {
    print("\n========== Example 6: Sensor-Aware Context ==========\n")

    let threadId = UUID()
    let broker = ContextBroker(threadId: threadId)

    do {
        let context = try await broker.buildContext(forPrompt: "What's nearby?")

        print("📡 Sensor Snapshot:")
        if let location = context.sensorSnapshot.location {
            print("📍 Location: \(location.latitude), \(location.longitude)")
            print("   Place: \(location.placeName ?? "Unknown")")
        }

        if let activity = context.sensorSnapshot.activity {
            print("🏃 Activity: \(activity.rawValue)")
        }

        if let health = context.sensorSnapshot.healthMetrics {
            print("❤️ Heart Rate: \(health.heartRate ?? 0) bpm")
            print("👣 Steps: \(health.steps ?? 0)")
        }

        if let device = context.sensorSnapshot.deviceState {
            print("🔋 Battery: \(Int((device.batteryLevel ?? 0) * 100))%")
            print("📶 Network: \(device.networkType ?? "Unknown")")
        }

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 7: Context Persistence

class ContextCache {
    private var cache: [String: ContextPacket] = [:]
    private let maxCacheSize = 50
    private let cacheExpiry: TimeInterval = 300 // 5 minutes

    func store(_ context: ContextPacket, forKey key: String) {
        // Evict old entries if needed
        if cache.count >= maxCacheSize {
            let oldestKey = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key
            if let key = oldestKey {
                cache.removeValue(forKey: key)
            }
        }

        cache[key] = context
        print("💾 Cached context for key: \(key)")
    }

    func retrieve(forKey key: String) -> ContextPacket? {
        guard let context = cache[key] else { return nil }

        // Check if expired
        let age = Date().timeIntervalSince(context.timestamp)
        if age > cacheExpiry {
            cache.removeValue(forKey: key)
            print("🗑️ Removed expired context for key: \(key)")
            return nil
        }

        print("✅ Retrieved cached context for key: \(key)")
        return context
    }

    func clear() {
        cache.removeAll()
        print("🗑️ Cleared all cached contexts")
    }
}

func example7_ContextCaching() async {
    print("\n========== Example 7: Context Caching ==========\n")

    let cache = ContextCache()
    let threadId = UUID()
    let broker = ContextBroker(threadId: threadId)

    let queries = [
        "What is Swift?",
        "How do I use SwiftUI?",
        "What is Swift?" // Duplicate query
    ]

    for query in queries {
        print("🔍 Query: \(query)")

        // Check cache first
        if let cached = cache.retrieve(forKey: query) {
            print("✅ Using cached context\n")
            continue
        }

        // Build fresh context
        do {
            let context = try await broker.buildContext(forPrompt: query)
            cache.store(context, forKey: query)
            print("📦 Built and cached new context\n")
        } catch {
            print("❌ Error: \(error)\n")
        }
    }
}

// MARK: - Example 8: Context Formatting for Different LLMs

extension ContextPacket {
    /// Format for OpenAI ChatGPT
    func formatForOpenAI() -> [[String: String]] {
        var messages: [[String: String]] = []

        // Add system message with context
        var systemContent = "You are a helpful assistant. Here's relevant context:\n\n"

        if !semanticMemory.isEmpty {
            systemContent += "Knowledge Base:\n"
            for fragment in semanticMemory {
                systemContent += "- \(fragment.content)\n"
            }
            systemContent += "\n"
        }

        if let location = sensorSnapshot.location {
            systemContent += "User Location: \(location.placeName ?? "Unknown")\n"
        }

        messages.append(["role": "system", "content": systemContent])

        // Add conversation history
        for message in threadHistory {
            messages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }

        return messages
    }

    /// Format for Claude
    func formatForClaude() -> String {
        var prompt = ""

        // Claude prefers inline context
        if !semanticMemory.isEmpty {
            prompt += "<context>\n"
            for fragment in semanticMemory {
                prompt += "<knowledge>\(fragment.content)</knowledge>\n"
            }
            prompt += "</context>\n\n"
        }

        // Add conversation
        for message in threadHistory {
            prompt += "\(message.role.rawValue.capitalized): \(message.content)\n\n"
        }

        return prompt
    }

    /// Format for local models
    func formatForLocalModel() -> String {
        // Simpler format for smaller models
        var prompt = ""

        if !semanticMemory.isEmpty {
            prompt += "Context: "
            prompt += semanticMemory.map { $0.content }.joined(separator: " | ")
            prompt += "\n\n"
        }

        if let lastMessage = threadHistory.last {
            prompt += "Question: \(lastMessage.content)\nAnswer:"
        }

        return prompt
    }
}

func example8_MultiLLMFormatting() async {
    print("\n========== Example 8: Multi-LLM Formatting ==========\n")

    let threadId = ThreadStorage.defaultThreadId
    let broker = ContextBroker(threadId: threadId)

    do {
        let context = try await broker.buildContext(forPrompt: "Explain protocols")

        print("📤 OpenAI Format:")
        print(context.formatForOpenAI())
        print("\n")

        print("📤 Claude Format:")
        print(context.formatForClaude())
        print("\n")

        print("📤 Local Model Format:")
        print(context.formatForLocalModel())

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 9: Complete RAG Pipeline

class RAGPipeline {
    let contextBroker: ContextBroker
    let modelRouter: ModelRouter
    let threadStorage: ThreadStorage
    let vectorStore: VectorStore

    init(threadId: UUID) {
        self.contextBroker = ContextBroker(threadId: threadId)
        self.modelRouter = ModelRouter(preferences: .defaultConfiguration())
        self.threadStorage = ThreadStorage.shared
        self.vectorStore = VectorStore.shared
    }

    func processQuery(_ query: String) async throws -> String {
        print("🔄 RAG Pipeline: \(query)")

        // Step 1: Build context
        print("📦 Step 1: Building context...")
        let context = try await contextBroker.buildContext(forPrompt: query)

        // Step 2: Format for LLM
        print("📝 Step 2: Formatting prompt...")
        let prompt = context.formatForPrompt() + "\n\nUser Question: \(query)\n\nAnswer:"

        // Step 3: Get LLM response
        print("🤖 Step 3: Querying LLM...")
        let response = try await modelRouter.routeRequest(prompt)

        // Step 4: Store interaction as new memory
        print("💾 Step 4: Storing interaction...")
        let memoryContent = "Q: \(query) A: \(response)"
        let embedding = [Float](repeating: 0.5, count: 384) // TODO: Real embedding

        let memory = MemoryFragment(
            content: memoryContent,
            embedding: embedding,
            source: .conversation,
            metadata: MemoryFragment.MemoryMetadata(
                tags: ["qa", "interaction"],
                location: context.sensorSnapshot.location,
                context: "RAG session",
                importance: 0.7,
                accessCount: 1,
                lastAccessed: Date()
            )
        )

        try await vectorStore.store(memory)

        print("✅ Pipeline complete!\n")
        return response
    }
}

func example9_CompletePipeline() async {
    print("\n========== Example 9: Complete RAG Pipeline ==========\n")

    let threadId = UUID()
    let pipeline = RAGPipeline(threadId: threadId)

    let queries = [
        "What is Swift?",
        "How do I create a struct in Swift?"
    ]

    for query in queries {
        do {
            let response = try await pipeline.processQuery(query)
            print("💬 Response: \(response)\n")
        } catch {
            print("❌ Error: \(error)\n")
        }
    }
}

// MARK: - Running Examples

/*
 To run these examples:

 // Run individual examples
 Task {
     await example1_BasicContextBuilding()
     await example2_RAGEnhancedChat()
     await example3_CustomConfiguration()
     await example4_MemoryManagement()
     await example6_SensorAwareContext()
     await example7_ContextCaching()
     await example8_MultiLLMFormatting()
     await example9_CompletePipeline()
 }

 // Or use the SwiftUI chat interface
 struct ContentView: View {
     var body: some View {
         NavigationView {
             RAGChatView()
         }
     }
 }
 */
