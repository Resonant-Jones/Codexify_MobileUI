//
//  ContextBroker.swift
//  Codexify
//
//  Created by Codexify:Scout
//  Sovereign Mobile RAG Node - Context Collection & Composition
//

import Foundation
import CoreLocation

// MARK: - Core Data Models

/// A message in a conversation thread
struct ThreadMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let metadata: MessageMetadata?

    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }

    struct MessageMetadata: Codable, Equatable {
        let tokenCount: Int?
        let model: String?
        let processingTime: TimeInterval?
        let tags: [String]?
    }

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// A semantic memory fragment stored in the vector database
struct MemoryFragment: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let embedding: [Float]
    let timestamp: Date
    let source: MemorySource
    let metadata: MemoryMetadata?

    enum MemorySource: String, Codable {
        case conversation
        case document
        case web
        case sensor
        case userInput
        case derived
    }

    struct MemoryMetadata: Codable, Equatable {
        let tags: [String]?
        let location: LocationSnapshot?
        let context: String?
        let importance: Float?
        let accessCount: Int?
        let lastAccessed: Date?
    }

    init(
        id: UUID = UUID(),
        content: String,
        embedding: [Float],
        timestamp: Date = Date(),
        source: MemorySource,
        metadata: MemoryMetadata? = nil
    ) {
        self.id = id
        self.content = content
        self.embedding = embedding
        self.timestamp = timestamp
        self.source = source
        self.metadata = metadata
    }

    /// Compute similarity with another fragment (cosine similarity)
    func similarity(to other: MemoryFragment) -> Float {
        return cosineSimilarity(embedding, other.embedding)
    }
}

// MARK: - Sensor Data Types
// Note: LocationSnapshot, SensorSnapshot, ActivityType, HealthMetrics, and DeviceState
// are defined in Sensors/SensorAggregator.swift and shared across the module

// MARK: - Context Packet

/// Complete context packet for RAG prompting
struct ContextPacket: Codable {
    let threadHistory: [ThreadMessage]
    let semanticMemory: [MemoryFragment]
    let sensorSnapshot: SensorSnapshot
    let timestamp: Date
    let metadata: ContextMetadata?

    struct ContextMetadata: Codable {
        let totalTokens: Int?
        let compressionRatio: Float?
        let salienceWeights: SalienceWeights?
        let buildDuration: TimeInterval?
    }

    struct SalienceWeights: Codable {
        let recentMessagesWeight: Float
        let semanticMemoryWeight: Float
        let sensorDataWeight: Float
    }

    init(
        threadHistory: [ThreadMessage],
        semanticMemory: [MemoryFragment],
        sensorSnapshot: SensorSnapshot,
        timestamp: Date = Date(),
        metadata: ContextMetadata? = nil
    ) {
        self.threadHistory = threadHistory
        self.semanticMemory = semanticMemory
        self.sensorSnapshot = sensorSnapshot
        self.timestamp = timestamp
        self.metadata = metadata
    }

    /// Total number of context elements
    var totalElements: Int {
        return threadHistory.count + semanticMemory.count + 1 // +1 for sensor snapshot
    }

    /// Check if context is empty
    var isEmpty: Bool {
        return threadHistory.isEmpty && semanticMemory.isEmpty && sensorSnapshot.location == nil
    }

    /// Check if context has data
    var hasData: Bool {
        return !isEmpty
    }
}

// MARK: - Error Types

/// Errors that can occur during context building
enum ContextBrokerError: Error, LocalizedError {
    case threadStorageUnavailable
    case vectorStoreUnavailable
    case sensorAggregatorUnavailable
    case insufficientContext
    case embeddingGenerationFailed
    case invalidConfiguration(message: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .threadStorageUnavailable:
            return "Thread storage is not available"
        case .vectorStoreUnavailable:
            return "Vector store is not available"
        case .sensorAggregatorUnavailable:
            return "Sensor aggregator is not available"
        case .insufficientContext:
            return "Insufficient context available for building packet"
        case .embeddingGenerationFailed:
            return "Failed to generate embeddings for query"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .timeout:
            return "Context building timed out"
        }
    }
}

// MARK: - Vector Store Protocol

/// Protocol for vector database operations
protocol VectorStoreProtocol {
    /// Search for similar memory fragments
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results
    ///   - threshold: Minimum similarity threshold (0.0-1.0)
    /// - Returns: Array of memory fragments sorted by similarity
    func search(query: String, limit: Int, threshold: Float) async throws -> [MemoryFragment]

    /// Store a new memory fragment
    /// - Parameter fragment: Memory fragment to store
    func store(_ fragment: MemoryFragment) async throws

    /// Delete a memory fragment
    /// - Parameter id: Fragment ID to delete
    func delete(id: UUID) async throws

    /// Get total fragment count
    func count() async throws -> Int
}

/// Stub implementation of VectorStore for development
class VectorStore: VectorStoreProtocol {
    static let shared = VectorStore()

    private var fragments: [MemoryFragment] = []
    private let queue = DispatchQueue(label: "com.codexify.vectorstore", attributes: .concurrent)

    private init() {
        // Initialize with some example fragments for testing
        loadSampleFragments()
    }

    func search(query: String, limit: Int = 5, threshold: Float = 0.5) async throws -> [MemoryFragment] {
        print("🔍 [VectorStore] Searching for: \"\(query)\" (limit: \(limit), threshold: \(threshold))")

        // TODO: Integrate with actual vector database
        // Options:
        // - CoreML for on-device embeddings
        // - SQLite with VSS extension
        // - Custom vector index (HNSW, IVF)
        // - Cloud vector DB with local cache

        return await withCheckedContinuation { continuation in
            queue.async {
                // Generate query embedding
                guard let queryEmbedding = self.generateEmbedding(for: query) else {
                    continuation.resume(returning: [])
                    return
                }

                // Compute similarities and filter
                var results = self.fragments.map { fragment -> (MemoryFragment, Float) in
                    let similarity = cosineSimilarity(queryEmbedding, fragment.embedding)
                    return (fragment, similarity)
                }

                // Filter by threshold and sort by similarity
                results = results.filter { $0.1 >= threshold }
                results.sort { $0.1 > $1.1 }

                // Take top N results
                let topResults = Array(results.prefix(limit)).map { $0.0 }

                print("✅ [VectorStore] Found \(topResults.count) fragments above threshold")
                continuation.resume(returning: topResults)
            }
        }
    }

    func store(_ fragment: MemoryFragment) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.fragments.append(fragment)
                print("💾 [VectorStore] Stored fragment: \(fragment.id)")
                continuation.resume()
            }
        }
    }

    func delete(id: UUID) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.fragments.removeAll { $0.id == id }
                print("🗑️ [VectorStore] Deleted fragment: \(id)")
                continuation.resume()
            }
        }
    }

    func count() async throws -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.fragments.count)
            }
        }
    }

    // MARK: - Private Helpers

    private func generateEmbedding(for text: String) -> [Float]? {
        // TODO: Integrate with actual embedding model
        // Options:
        // - sentence-transformers via CoreML
        // - OpenAI embeddings API
        // - Local BERT-based model
        // - Custom trained embeddings

        // Stub: Generate random embedding for development
        let dimension = 384 // Common embedding dimension
        var embedding = [Float](repeating: 0, count: dimension)

        // Simple hash-based pseudo-embedding (for testing only)
        let hash = text.lowercased().hash
        let seed = UInt64(bitPattern: Int64(hash))
        var random = seed

        for i in 0..<dimension {
            // Linear congruential generator
            random = (random &* 1103515245 &+ 12345) & 0x7fffffff
            embedding[i] = Float(random % 10000) / 10000.0 - 0.5
        }

        // Normalize
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        return embedding.map { $0 / magnitude }
    }

    private func loadSampleFragments() {
        // Sample fragments for testing
        let samples = [
            "Swift is a powerful programming language developed by Apple for iOS, macOS, and other platforms.",
            "Machine learning models can run efficiently on iPhone using CoreML and Neural Engine.",
            "Location services provide GPS coordinates and activity recognition for context-aware applications.",
            "Vector databases enable semantic search by storing and querying high-dimensional embeddings.",
            "Retrieval-augmented generation combines vector search with language models for better responses."
        ]

        for (index, content) in samples.enumerated() {
            if let embedding = generateEmbedding(for: content) {
                let fragment = MemoryFragment(
                    content: content,
                    embedding: embedding,
                    source: .document,
                    metadata: MemoryFragment.MemoryMetadata(
                        tags: ["sample", "documentation"],
                        location: nil,
                        context: "Initial knowledge base",
                        importance: Float(samples.count - index) / Float(samples.count),
                        accessCount: 0,
                        lastAccessed: nil
                    )
                )
                fragments.append(fragment)
            }
        }

        print("📚 [VectorStore] Loaded \(fragments.count) sample fragments")
    }
}

// MARK: - Thread Storage Protocol

/// Protocol for thread message storage
protocol ThreadStorageProtocol {
    /// Fetch recent messages from a thread
    /// - Parameters:
    ///   - threadId: Thread identifier
    ///   - limit: Maximum number of messages to fetch
    /// - Returns: Array of thread messages, most recent first
    func fetchRecentMessages(threadId: UUID, limit: Int) async throws -> [ThreadMessage]

    /// Store a new message
    /// - Parameters:
    ///   - message: Message to store
    ///   - threadId: Thread identifier
    func storeMessage(_ message: ThreadMessage, threadId: UUID) async throws
}

/// Stub implementation of ThreadStorage
class ThreadStorage: ThreadStorageProtocol {
    static let shared = ThreadStorage()

    private var messages: [UUID: [ThreadMessage]] = [:]
    private let queue = DispatchQueue(label: "com.codexify.threadstorage", attributes: .concurrent)

    private init() {
        loadSampleMessages()
    }

    func fetchRecentMessages(threadId: UUID, limit: Int = 5) async throws -> [ThreadMessage] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let threadMessages = self.messages[threadId] ?? []
                let recent = Array(threadMessages.suffix(limit))
                print("💬 [ThreadStorage] Fetched \(recent.count) recent messages from thread \(threadId)")
                continuation.resume(returning: recent)
            }
        }
    }

    func storeMessage(_ message: ThreadMessage, threadId: UUID) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.messages[threadId, default: []].append(message)
                print("💾 [ThreadStorage] Stored message in thread \(threadId)")
                continuation.resume()
            }
        }
    }

    private func loadSampleMessages() {
        // Create a default thread for testing
        let defaultThreadId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let sampleMessages = [
            ThreadMessage(role: .user, content: "What is Swift?", timestamp: Date().addingTimeInterval(-300)),
            ThreadMessage(role: .assistant, content: "Swift is a modern programming language developed by Apple.", timestamp: Date().addingTimeInterval(-280)),
            ThreadMessage(role: .user, content: "How do I use async/await?", timestamp: Date().addingTimeInterval(-100)),
            ThreadMessage(role: .assistant, content: "You can use async/await for asynchronous operations in Swift.", timestamp: Date().addingTimeInterval(-80))
        ]

        messages[defaultThreadId] = sampleMessages
        print("💬 [ThreadStorage] Loaded \(sampleMessages.count) sample messages")
    }

    /// Get the default thread ID for testing
    static var defaultThreadId: UUID {
        return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }
}

// MARK: - Sensor Aggregator Protocol

/// Protocol for sensor data aggregation
protocol SensorAggregatorProtocol {
    /// Get current sensor snapshot
    /// - Returns: Latest sensor data snapshot
    func getCurrentSnapshot() async throws -> SensorSnapshot

    /// Start monitoring sensors
    func startMonitoring() async throws

    /// Stop monitoring sensors
    func stopMonitoring() async
}

/// Stub implementation of SensorAggregator
class SensorAggregator: SensorAggregatorProtocol {
    static let shared = SensorAggregator()

    private var isMonitoring = false
    private var lastSnapshot: SensorSnapshot?

    private init() {}

    func getCurrentSnapshot() async throws -> SensorSnapshot {
        print("📡 [SensorAggregator] Fetching current sensor snapshot")

        // TODO: Integrate with actual iOS sensors
        // - CoreLocation for GPS, activity
        // - HealthKit for health metrics
        // - UIDevice for device state
        // - CoreMotion for activity recognition

        // Stub: Return simulated sensor data
        let snapshot = SensorSnapshot(
            timestamp: Date(),
            location: LocationSnapshot(
                from: CLLocation(
                    latitude: 37.7749,
                    longitude: -122.4194
                ),
                placeName: "San Francisco, CA"
            ),
            activity: .walking,
            healthMetrics: HealthMetrics(
                heartRate: 72.0,
                steps: 5432,
                distance: 3.2,
                activeEnergyBurned: 245.5,
                standHours: 8
            ),
            deviceState: DeviceState(
                batteryLevel: 0.75,
                lowPowerMode: false,
                thermalState: .nominal,
                networkType: .wifi
            )
        )

        lastSnapshot = snapshot
        print("✅ [SensorAggregator] Snapshot captured")
        return snapshot
    }

    func startMonitoring() async throws {
        guard !isMonitoring else { return }
        isMonitoring = true
        print("🎯 [SensorAggregator] Started monitoring sensors")

        // TODO: Start actual sensor monitoring
        // - Request location permissions
        // - Request HealthKit permissions
        // - Start CoreMotion updates
    }

    func stopMonitoring() async {
        guard isMonitoring else { return }
        isMonitoring = false
        print("⏸️ [SensorAggregator] Stopped monitoring sensors")

        // TODO: Stop actual sensor monitoring
    }
}

// MARK: - Context Broker

/// Main context broker for collecting and composing RAG context
class ContextBroker {

    // MARK: - Configuration

    struct Configuration {
        let maxRecentMessages: Int
        let maxSemanticMemories: Int
        let semanticSimilarityThreshold: Float
        let includeSystemMessages: Bool
        let includeSensorData: Bool
        let timeoutSeconds: TimeInterval

        static let `default` = Configuration(
            maxRecentMessages: 5,
            maxSemanticMemories: 5,
            semanticSimilarityThreshold: 0.5,
            includeSystemMessages: false,
            includeSensorData: true,
            timeoutSeconds: 10.0
        )
    }

    // MARK: - Properties

    private let config: Configuration
    private let vectorStore: VectorStoreProtocol
    private let threadStorage: ThreadStorageProtocol
    private let sensorAggregator: SensorAggregatorProtocol
    private let threadId: UUID

    // MARK: - Initialization

    init(
        threadId: UUID,
        config: Configuration = .default,
        vectorStore: VectorStoreProtocol = VectorStore.shared,
        threadStorage: ThreadStorageProtocol = ThreadStorage.shared,
        sensorAggregator: SensorAggregatorProtocol = SensorAggregator.shared
    ) {
        self.threadId = threadId
        self.config = config
        self.vectorStore = vectorStore
        self.threadStorage = threadStorage
        self.sensorAggregator = sensorAggregator

        print("🚀 [ContextBroker] Initialized for thread: \(threadId)")
    }

    // MARK: - Public API

    /// Build a complete context packet for a given prompt
    /// - Parameter input: User input/prompt string
    /// - Returns: Complete context packet with thread history, semantic memory, and sensor data
    /// - Throws: ContextBrokerError if context building fails
    func buildContext(forPrompt input: String) async throws -> ContextPacket {
        let startTime = Date()
        print("\n📦 [ContextBroker] Building context for prompt: \"\(input)\"")

        // Execute context gathering in parallel for efficiency
        async let threadHistory = fetchThreadHistory()
        async let semanticMemory = fetchSemanticMemory(for: input)
        async let sensorSnapshot = fetchSensorSnapshot()

        // Await all results with timeout
        let packet = try await withThrowingTaskGroup(of: Void.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.config.timeoutSeconds * 1_000_000_000))
                throw ContextBrokerError.timeout
            }

            // Add actual work task
            group.addTask {
                // This will complete when all context is gathered
                _ = try await (threadHistory, semanticMemory, sensorSnapshot)
            }

            // Wait for first to complete (either work or timeout)
            try await group.next()
            group.cancelAll()

            // Build the packet
            let thread = try await threadHistory
            let memory = try await semanticMemory
            let sensors = try await sensorSnapshot

            let duration = Date().timeIntervalSince(startTime)

            // TODO: Implement salience weighting
            // This will prioritize different context sources based on:
            // - Recency (newer = more important)
            // - Semantic similarity (higher = more relevant)
            // - Sensor signal strength (e.g., significant location change)
            // - User preferences and learned patterns
            // - Context type (e.g., code > general chat in coding session)
            let salienceWeights = ContextPacket.SalienceWeights(
                recentMessagesWeight: 1.0,
                semanticMemoryWeight: 0.8,
                sensorDataWeight: 0.3
            )

            let metadata = ContextPacket.ContextMetadata(
                totalTokens: nil, // TODO: Calculate from content
                compressionRatio: nil, // TODO: Implement context compression
                salienceWeights: salienceWeights,
                buildDuration: duration
            )

            let packet = ContextPacket(
                threadHistory: thread,
                semanticMemory: memory,
                sensorSnapshot: sensors,
                timestamp: Date(),
                metadata: metadata
            )

            print("✅ [ContextBroker] Context built in \(String(format: "%.2f", duration))s")
            print("   - Thread messages: \(thread.count)")
            print("   - Memory fragments: \(memory.count)")
            print("   - Sensor data: \(sensors.location != nil ? "available" : "unavailable")")

            return packet
        }

        return packet
    }

    /// Build context with custom salience weights
    /// - Parameters:
    ///   - input: User input/prompt string
    ///   - weights: Custom salience weights for prioritization
    /// - Returns: Context packet with weighted context sources
    func buildContext(forPrompt input: String, weights: ContextPacket.SalienceWeights) async throws -> ContextPacket {
        // TODO: Implement weighted context building
        // For now, call standard buildContext
        return try await buildContext(forPrompt: input)
    }

    // MARK: - Private Methods

    private func fetchThreadHistory() async throws -> [ThreadMessage] {
        do {
            var messages = try await threadStorage.fetchRecentMessages(
                threadId: threadId,
                limit: config.maxRecentMessages
            )

            // Filter out system messages if configured
            if !config.includeSystemMessages {
                messages = messages.filter { $0.role != .system }
            }

            return messages
        } catch {
            print("⚠️ [ContextBroker] Failed to fetch thread history: \(error)")
            throw ContextBrokerError.threadStorageUnavailable
        }
    }

    private func fetchSemanticMemory(for query: String) async throws -> [MemoryFragment] {
        do {
            let fragments = try await vectorStore.search(
                query: query,
                limit: config.maxSemanticMemories,
                threshold: config.semanticSimilarityThreshold
            )

            // TODO: Apply salience-based re-ranking
            // - Consider temporal decay
            // - Boost by access frequency
            // - Factor in user importance ratings
            // - Apply contextual boosting (e.g., same location)

            return fragments
        } catch {
            print("⚠️ [ContextBroker] Failed to fetch semantic memory: \(error)")
            throw ContextBrokerError.vectorStoreUnavailable
        }
    }

    private func fetchSensorSnapshot() async throws -> SensorSnapshot {
        guard config.includeSensorData else {
            // Return empty snapshot if sensors disabled
            return SensorSnapshot()
        }

        do {
            let snapshot = try await sensorAggregator.getCurrentSnapshot()
            return snapshot
        } catch {
            print("⚠️ [ContextBroker] Failed to fetch sensor snapshot: \(error)")
            // Don't throw - sensor data is optional
            return SensorSnapshot()
        }
    }
}

// MARK: - Utility Functions

/// Compute cosine similarity between two vectors
/// - Parameters:
///   - a: First vector
///   - b: Second vector
/// - Returns: Similarity score (0.0 to 1.0)
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count else { return 0.0 }

    var dotProduct: Float = 0.0
    var magnitudeA: Float = 0.0
    var magnitudeB: Float = 0.0

    for i in 0..<a.count {
        dotProduct += a[i] * b[i]
        magnitudeA += a[i] * a[i]
        magnitudeB += b[i] * b[i]
    }

    let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
    guard magnitude > 0 else { return 0.0 }

    return dotProduct / magnitude
}

// MARK: - Context Formatting Extensions

extension ContextPacket {
    /// Format the context packet as a prompt for an LLM
    /// - Returns: Formatted string suitable for LLM input
    func formatForPrompt() -> String {
        var formatted = ""

        // Add sensor context if available
        if let location = sensorSnapshot.location {
            formatted += "📍 Location: \(location.placeName ?? "Unknown")\n"
        }
        if let activity = sensorSnapshot.activity {
            formatted += "🏃 Activity: \(activity.rawValue)\n"
        }
        if !formatted.isEmpty {
            formatted += "\n"
        }

        // Add semantic memory
        if !semanticMemory.isEmpty {
            formatted += "📚 Relevant Knowledge:\n"
            for (index, fragment) in semanticMemory.enumerated() {
                formatted += "\(index + 1). \(fragment.content)\n"
            }
            formatted += "\n"
        }

        // Add conversation history
        if !threadHistory.isEmpty {
            formatted += "💬 Recent Conversation:\n"
            for message in threadHistory {
                let emoji = message.role == .user ? "👤" : "🤖"
                formatted += "\(emoji) \(message.role.rawValue): \(message.content)\n"
            }
        }

        return formatted
    }

    /// Get a summary of the context packet
    var summary: String {
        return """
        Context Summary:
        - Messages: \(threadHistory.count)
        - Memories: \(semanticMemory.count)
        - Sensors: \(sensorSnapshot.location != nil ? "Active" : "Inactive")
        - Built: \(timestamp)
        """
    }
}

// MARK: - Example Usage

/*
 // Initialize context broker for a thread
 let threadId = UUID()
 let broker = ContextBroker(threadId: threadId)

 // Build context for a user prompt
 Task {
     do {
         let context = try await broker.buildContext(forPrompt: "How do I use CoreML?")

         // Use context with your LLM
         let formattedContext = context.formatForPrompt()
         print(formattedContext)

         // Or access individual components
         print("Recent messages: \(context.threadHistory.count)")
         print("Relevant memories: \(context.semanticMemory.count)")

     } catch {
         print("Failed to build context: \(error)")
     }
 }

 // Custom configuration
 let customConfig = ContextBroker.Configuration(
     maxRecentMessages: 10,
     maxSemanticMemories: 8,
     semanticSimilarityThreshold: 0.7,
     includeSystemMessages: true,
     includeSensorData: true,
     timeoutSeconds: 5.0
 )

 let customBroker = ContextBroker(
     threadId: threadId,
     config: customConfig
 )
 */
