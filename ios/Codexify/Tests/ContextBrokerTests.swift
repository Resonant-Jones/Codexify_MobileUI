//
//  ContextBrokerTests.swift
//  Codexify Tests
//
//  Comprehensive test suite for ContextBroker
//  Phase One: Production Readiness Validation
//

import XCTest
@testable import Codexify

// MARK: - Mock Vector Store

class MockVectorStore: VectorStoreProtocol {
    var mockFragments: [MemoryFragment] = []
    var searchDelay: TimeInterval = 0
    var shouldFail: Bool = false
    var searchCallCount: Int = 0
    var storeCallCount: Int = 0

    func search(query: String, limit: Int, threshold: Float) async throws -> [MemoryFragment] {
        searchCallCount += 1

        if searchDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(searchDelay * 1_000_000_000))
        }

        if shouldFail {
            throw ContextBrokerError.vectorStoreUnavailable
        }

        // Filter by threshold (simplified)
        return Array(mockFragments.prefix(min(limit, mockFragments.count)))
    }

    func store(_ fragment: MemoryFragment) async throws {
        storeCallCount += 1

        if shouldFail {
            throw ContextBrokerError.vectorStoreUnavailable
        }

        mockFragments.append(fragment)
    }

    func delete(id: UUID) async throws {
        if shouldFail {
            throw ContextBrokerError.vectorStoreUnavailable
        }

        mockFragments.removeAll { $0.id == id }
    }

    func count() async throws -> Int {
        if shouldFail {
            throw ContextBrokerError.vectorStoreUnavailable
        }

        return mockFragments.count
    }
}

// MARK: - Mock Thread Storage

class MockThreadStorage: ThreadStorageProtocol {
    var mockMessages: [UUID: [ThreadMessage]] = [:]
    var fetchDelay: TimeInterval = 0
    var shouldFail: Bool = false
    var fetchCallCount: Int = 0
    var storeCallCount: Int = 0

    func fetchRecentMessages(threadId: UUID, limit: Int) async throws -> [ThreadMessage] {
        fetchCallCount += 1

        if fetchDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(fetchDelay * 1_000_000_000))
        }

        if shouldFail {
            throw ContextBrokerError.threadStorageUnavailable
        }

        let messages = mockMessages[threadId] ?? []
        return Array(messages.suffix(limit))
    }

    func storeMessage(_ message: ThreadMessage, threadId: UUID) async throws {
        storeCallCount += 1

        if shouldFail {
            throw ContextBrokerError.threadStorageUnavailable
        }

        mockMessages[threadId, default: []].append(message)
    }
}

// MARK: - Mock Sensor Aggregator

class MockSensorAggregator: SensorAggregatorProtocol {
    var mockSnapshot: SensorSnapshot?
    var snapshotDelay: TimeInterval = 0
    var shouldFail: Bool = false
    var snapshotCallCount: Int = 0
    var isMonitoring: Bool = false

    func getCurrentSnapshot() async throws -> SensorSnapshot {
        snapshotCallCount += 1

        if snapshotDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(snapshotDelay * 1_000_000_000))
        }

        if shouldFail {
            throw SensorAggregatorError.sensorUnavailable(sensor: "Mock")
        }

        return mockSnapshot ?? SensorSnapshot()
    }

    func startMonitoring() async throws {
        if isMonitoring {
            throw SensorAggregatorError.alreadyMonitoring
        }
        isMonitoring = true
    }

    func stopMonitoring() async {
        isMonitoring = false
    }
}

// MARK: - Test Suite

class ContextBrokerTests: XCTestCase {

    var mockVectorStore: MockVectorStore!
    var mockThreadStorage: MockThreadStorage!
    var mockSensorAggregator: MockSensorAggregator!
    var contextBroker: ContextBroker!
    var testThreadId: UUID!

    override func setUp() {
        super.setUp()

        // Initialize mocks
        mockVectorStore = MockVectorStore()
        mockThreadStorage = MockThreadStorage()
        mockSensorAggregator = MockSensorAggregator()
        testThreadId = UUID()

        // Setup default mock data
        setupDefaultMockData()

        // Create context broker with mocks
        contextBroker = ContextBroker(
            threadId: testThreadId,
            vectorStore: mockVectorStore,
            threadStorage: mockThreadStorage,
            sensorAggregator: mockSensorAggregator
        )
    }

    override func tearDown() {
        mockVectorStore = nil
        mockThreadStorage = nil
        mockSensorAggregator = nil
        contextBroker = nil
        testThreadId = nil

        super.tearDown()
    }

    func setupDefaultMockData() {
        // Setup mock thread messages
        let messages = [
            ThreadMessage(role: .user, content: "What is Swift?", timestamp: Date().addingTimeInterval(-300)),
            ThreadMessage(role: .assistant, content: "Swift is a programming language.", timestamp: Date().addingTimeInterval(-280)),
            ThreadMessage(role: .user, content: "How do I use async/await?", timestamp: Date().addingTimeInterval(-60))
        ]
        mockThreadStorage.mockMessages[testThreadId] = messages

        // Setup mock memory fragments
        let fragments = [
            MemoryFragment(
                content: "Swift uses async/await for concurrency",
                embedding: [Float](repeating: 0.5, count: 384),
                source: .document
            ),
            MemoryFragment(
                content: "CoreML enables on-device machine learning",
                embedding: [Float](repeating: 0.6, count: 384),
                source: .document
            ),
            MemoryFragment(
                content: "SwiftUI provides declarative UI",
                embedding: [Float](repeating: 0.4, count: 384),
                source: .web
            )
        ]
        mockVectorStore.mockFragments = fragments

        // Setup mock sensor snapshot
        mockSensorAggregator.mockSnapshot = SensorSnapshot(
            location: LocationSnapshot(
                latitude: 37.7749,
                longitude: -122.4194,
                horizontalAccuracy: 10.0,
                placeName: "San Francisco"
            ),
            activity: .walking,
            healthMetrics: HealthMetrics(heartRate: 72.0, steps: 5000),
            deviceState: DeviceState(batteryLevel: 0.8)
        )
    }

    // MARK: - Unit Tests: Context Compilation

    func testBuildContext_CompletesSuccessfully() async throws {
        // Given: Default mock data setup

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Tell me about Swift")

        // Then: Should contain all components
        XCTAssertFalse(context.threadHistory.isEmpty)
        XCTAssertFalse(context.semanticMemory.isEmpty)
        XCTAssertNotNil(context.sensorSnapshot.location)
        XCTAssertNotNil(context.timestamp)
    }

    func testBuildContext_IncludesThreadHistory() async throws {
        // Given: Messages in thread
        XCTAssertEqual(mockThreadStorage.mockMessages[testThreadId]?.count, 3)

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test query")

        // Then: Should include thread history
        XCTAssertGreaterThan(context.threadHistory.count, 0)
        XCTAssertLessThanOrEqual(context.threadHistory.count, 5) // Default max
        XCTAssertEqual(mockThreadStorage.fetchCallCount, 1)
    }

    func testBuildContext_IncludesSemanticMemory() async throws {
        // Given: Memory fragments available
        XCTAssertEqual(mockVectorStore.mockFragments.count, 3)

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Swift async")

        // Then: Should include semantic memory
        XCTAssertGreaterThan(context.semanticMemory.count, 0)
        XCTAssertLessThanOrEqual(context.semanticMemory.count, 5) // Default max
        XCTAssertEqual(mockVectorStore.searchCallCount, 1)
    }

    func testBuildContext_IncludesSensorSnapshot() async throws {
        // Given: Sensor snapshot available
        XCTAssertNotNil(mockSensorAggregator.mockSnapshot)

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test query")

        // Then: Should include sensor data
        XCTAssertNotNil(context.sensorSnapshot)
        XCTAssertNotNil(context.sensorSnapshot.location)
        XCTAssertEqual(context.sensorSnapshot.location?.placeName, "San Francisco")
        XCTAssertEqual(mockSensorAggregator.snapshotCallCount, 1)
    }

    func testBuildContext_HasMetadata() async throws {
        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        // Then: Should have metadata
        XCTAssertNotNil(context.metadata)
        XCTAssertNotNil(context.metadata?.buildDuration)
        XCTAssertNotNil(context.metadata?.salienceWeights)
        XCTAssertGreaterThan(context.metadata?.buildDuration ?? 0, 0)
    }

    func testBuildContext_ParallelFetching() async throws {
        // Given: Delays on all sources to test parallelism
        mockThreadStorage.fetchDelay = 0.1
        mockVectorStore.searchDelay = 0.1
        mockSensorAggregator.snapshotDelay = 0.1

        let startTime = Date()

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        let duration = Date().timeIntervalSince(startTime)

        // Then: Should complete in parallel (not sequentially)
        // If sequential: 0.3s+, if parallel: ~0.1s
        XCTAssertLessThan(duration, 0.2) // Should be close to max delay, not sum
        XCTAssertNotNil(context)
    }

    // MARK: - Mock Injection Tests

    func testBuildContext_WithCustomVectorStore() async throws {
        // Given: Custom vector store with specific data
        let customStore = MockVectorStore()
        let fragment = MemoryFragment(
            content: "Custom memory content",
            embedding: [Float](repeating: 0.9, count: 384),
            source: .userInput
        )
        customStore.mockFragments = [fragment]

        let customBroker = ContextBroker(
            threadId: testThreadId,
            vectorStore: customStore,
            threadStorage: mockThreadStorage,
            sensorAggregator: mockSensorAggregator
        )

        // When: Building context
        let context = try await customBroker.buildContext(forPrompt: "Test")

        // Then: Should use custom store
        XCTAssertEqual(context.semanticMemory.first?.content, "Custom memory content")
        XCTAssertEqual(customStore.searchCallCount, 1)
    }

    func testBuildContext_WithCustomThreadStorage() async throws {
        // Given: Custom thread storage
        let customStorage = MockThreadStorage()
        let customMessage = ThreadMessage(role: .user, content: "Custom message")
        customStorage.mockMessages[testThreadId] = [customMessage]

        let customBroker = ContextBroker(
            threadId: testThreadId,
            vectorStore: mockVectorStore,
            threadStorage: customStorage,
            sensorAggregator: mockSensorAggregator
        )

        // When: Building context
        let context = try await customBroker.buildContext(forPrompt: "Test")

        // Then: Should use custom storage
        XCTAssertEqual(context.threadHistory.first?.content, "Custom message")
        XCTAssertEqual(customStorage.fetchCallCount, 1)
    }

    func testBuildContext_WithCustomSensorAggregator() async throws {
        // Given: Custom sensor aggregator
        let customAggregator = MockSensorAggregator()
        customAggregator.mockSnapshot = SensorSnapshot(
            location: LocationSnapshot(
                latitude: 40.7128,
                longitude: -74.0060,
                horizontalAccuracy: 5.0,
                placeName: "New York"
            )
        )

        let customBroker = ContextBroker(
            threadId: testThreadId,
            vectorStore: mockVectorStore,
            threadStorage: mockThreadStorage,
            sensorAggregator: customAggregator
        )

        // When: Building context
        let context = try await customBroker.buildContext(forPrompt: "Test")

        // Then: Should use custom aggregator
        XCTAssertEqual(context.sensorSnapshot.location?.placeName, "New York")
        XCTAssertEqual(customAggregator.snapshotCallCount, 1)
    }

    // MARK: - Failure Tests: Missing Context Fields

    func testBuildContext_WithEmptyThreadHistory() async throws {
        // Given: No messages in thread
        mockThreadStorage.mockMessages[testThreadId] = []

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        // Then: Should still succeed with empty history
        XCTAssertTrue(context.threadHistory.isEmpty)
        XCTAssertFalse(context.semanticMemory.isEmpty) // Other sources still work
        XCTAssertNotNil(context.sensorSnapshot)
    }

    func testBuildContext_WithEmptySemanticMemory() async throws {
        // Given: No memory fragments
        mockVectorStore.mockFragments = []

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        // Then: Should still succeed with empty memory
        XCTAssertTrue(context.semanticMemory.isEmpty)
        XCTAssertFalse(context.threadHistory.isEmpty) // Other sources still work
        XCTAssertNotNil(context.sensorSnapshot)
    }

    func testBuildContext_WithNoSensorData() async throws {
        // Given: Empty sensor snapshot
        mockSensorAggregator.mockSnapshot = SensorSnapshot()

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        // Then: Should still succeed with empty sensors
        XCTAssertNotNil(context.sensorSnapshot)
        XCTAssertFalse(context.hasData) // No sensor data
        XCTAssertFalse(context.threadHistory.isEmpty) // Other sources still work
    }

    func testBuildContext_WithAllSourcesEmpty() async throws {
        // Given: All sources empty
        mockThreadStorage.mockMessages[testThreadId] = []
        mockVectorStore.mockFragments = []
        mockSensorAggregator.mockSnapshot = SensorSnapshot()

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        // Then: Should still succeed but be empty
        XCTAssertTrue(context.threadHistory.isEmpty)
        XCTAssertTrue(context.semanticMemory.isEmpty)
        XCTAssertFalse(context.sensorSnapshot.hasData)
        XCTAssertTrue(context.isEmpty)
    }

    func testBuildContext_ThreadStorageFailure_ContinuesGracefully() async throws {
        // Given: Thread storage fails
        mockThreadStorage.shouldFail = true

        // When/Then: Should throw error
        do {
            _ = try await contextBroker.buildContext(forPrompt: "Test")
            XCTFail("Should have thrown error")
        } catch ContextBrokerError.threadStorageUnavailable {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testBuildContext_VectorStoreFailure_ContinuesGracefully() async throws {
        // Given: Vector store fails
        mockVectorStore.shouldFail = true

        // When/Then: Should throw error
        do {
            _ = try await contextBroker.buildContext(forPrompt: "Test")
            XCTFail("Should have thrown error")
        } catch ContextBrokerError.vectorStoreUnavailable {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testBuildContext_SensorAggregatorFailure_ContinuesGracefully() async throws {
        // Given: Sensor aggregator fails
        mockSensorAggregator.shouldFail = true

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        // Then: Should succeed with empty sensor data
        // (Sensor failures are non-critical)
        XCTAssertNotNil(context)
        XCTAssertFalse(context.threadHistory.isEmpty)
        XCTAssertFalse(context.semanticMemory.isEmpty)
    }

    // MARK: - Async Edge Cases: Delayed Retrieval

    func testBuildContext_WithSlowThreadStorage() async throws {
        // Given: Slow thread storage
        mockThreadStorage.fetchDelay = 2.0

        // When: Building context with timeout
        let startTime = Date()

        do {
            _ = try await contextBroker.buildContext(forPrompt: "Test")
            let duration = Date().timeIntervalSince(startTime)

            // Then: Should complete (may timeout based on config)
            XCTAssertGreaterThan(duration, 0)
        } catch ContextBrokerError.timeout {
            // Also acceptable if timeout is configured
            print("Context building timed out as expected")
        }
    }

    func testBuildContext_WithSlowVectorStore() async throws {
        // Given: Slow vector store
        mockVectorStore.searchDelay = 2.0

        // When: Building context
        let startTime = Date()

        do {
            _ = try await contextBroker.buildContext(forPrompt: "Test")
            let duration = Date().timeIntervalSince(startTime)

            // Then: Should complete
            XCTAssertGreaterThan(duration, 2.0)
        } catch ContextBrokerError.timeout {
            // Acceptable if timeout is configured < 2s
            print("Context building timed out as expected")
        }
    }

    func testBuildContext_WithSlowSensorAggregator() async throws {
        // Given: Slow sensor aggregator
        mockSensorAggregator.snapshotDelay = 2.0

        // When: Building context
        let startTime = Date()

        do {
            let context = try await contextBroker.buildContext(forPrompt: "Test")
            let duration = Date().timeIntervalSince(startTime)

            // Then: Should complete
            XCTAssertGreaterThan(duration, 0)
            XCTAssertNotNil(context)
        } catch ContextBrokerError.timeout {
            // Acceptable if timeout is configured
            print("Context building timed out as expected")
        }
    }

    func testBuildContext_Timeout() async throws {
        // Given: Very slow sources with short timeout
        mockThreadStorage.fetchDelay = 10.0
        mockVectorStore.searchDelay = 10.0
        mockSensorAggregator.snapshotDelay = 10.0

        let shortTimeoutConfig = ContextBroker.Configuration(
            maxRecentMessages: 5,
            maxSemanticMemories: 5,
            semanticSimilarityThreshold: 0.5,
            includeSystemMessages: false,
            includeSensorData: true,
            timeoutSeconds: 0.5
        )

        let timeoutBroker = ContextBroker(
            threadId: testThreadId,
            config: shortTimeoutConfig,
            vectorStore: mockVectorStore,
            threadStorage: mockThreadStorage,
            sensorAggregator: mockSensorAggregator
        )

        // When/Then: Should timeout
        do {
            _ = try await timeoutBroker.buildContext(forPrompt: "Test")
            XCTFail("Should have timed out")
        } catch ContextBrokerError.timeout {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testBuildContext_ConcurrentRequests() async throws {
        // Given: Multiple concurrent context builds

        // When: Building multiple contexts simultaneously
        async let context1 = contextBroker.buildContext(forPrompt: "Query 1")
        async let context2 = contextBroker.buildContext(forPrompt: "Query 2")
        async let context3 = contextBroker.buildContext(forPrompt: "Query 3")

        let results = try await [context1, context2, context3]

        // Then: All should succeed
        XCTAssertEqual(results.count, 3)
        for context in results {
            XCTAssertNotNil(context)
            XCTAssertFalse(context.isEmpty)
        }
    }

    // MARK: - Configuration Tests

    func testConfiguration_CustomMaxMessages() async throws {
        // Given: Custom configuration with more messages
        let customConfig = ContextBroker.Configuration(
            maxRecentMessages: 10,
            maxSemanticMemories: 5,
            semanticSimilarityThreshold: 0.5,
            includeSystemMessages: false,
            includeSensorData: true,
            timeoutSeconds: 5.0
        )

        let customBroker = ContextBroker(
            threadId: testThreadId,
            config: customConfig,
            vectorStore: mockVectorStore,
            threadStorage: mockThreadStorage,
            sensorAggregator: mockSensorAggregator
        )

        // When: Building context
        let context = try await customBroker.buildContext(forPrompt: "Test")

        // Then: Should respect configuration
        XCTAssertNotNil(context)
        XCTAssertLessThanOrEqual(context.threadHistory.count, 10)
    }

    func testConfiguration_DisabledSensors() async throws {
        // Given: Configuration with sensors disabled
        let noSensorConfig = ContextBroker.Configuration(
            maxRecentMessages: 5,
            maxSemanticMemories: 5,
            semanticSimilarityThreshold: 0.5,
            includeSystemMessages: false,
            includeSensorData: false,
            timeoutSeconds: 5.0
        )

        let noSensorBroker = ContextBroker(
            threadId: testThreadId,
            config: noSensorConfig,
            vectorStore: mockVectorStore,
            threadStorage: mockThreadStorage,
            sensorAggregator: mockSensorAggregator
        )

        // When: Building context
        let context = try await noSensorBroker.buildContext(forPrompt: "Test")

        // Then: Should have empty sensor data
        XCTAssertNotNil(context.sensorSnapshot)
        // Sensor aggregator should not be called when disabled
        // (Implementation detail - may vary)
    }

    func testConfiguration_HighSimilarityThreshold() async throws {
        // Given: Configuration with high similarity threshold
        let highThresholdConfig = ContextBroker.Configuration(
            maxRecentMessages: 5,
            maxSemanticMemories: 5,
            semanticSimilarityThreshold: 0.95,
            includeSystemMessages: false,
            includeSensorData: true,
            timeoutSeconds: 5.0
        )

        let highThresholdBroker = ContextBroker(
            threadId: testThreadId,
            config: highThresholdConfig,
            vectorStore: mockVectorStore,
            threadStorage: mockThreadStorage,
            sensorAggregator: mockSensorAggregator
        )

        // When: Building context
        let context = try await highThresholdBroker.buildContext(forPrompt: "Test")

        // Then: May have fewer or no semantic memories (depends on similarity)
        XCTAssertNotNil(context)
    }

    // MARK: - Context Formatting Tests

    func testContextPacket_FormatForPrompt() async throws {
        // Given: Built context
        let context = try await contextBroker.buildContext(forPrompt: "Test query")

        // When: Formatting for prompt
        let formatted = context.formatForPrompt()

        // Then: Should be readable format
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("Location:") || formatted.contains("Knowledge:") || formatted.contains("Conversation:"))
    }

    func testContextPacket_Summary() async throws {
        // Given: Built context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        // When: Getting summary
        let summary = context.summary

        // Then: Should contain statistics
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.contains("Messages:"))
        XCTAssertTrue(summary.contains("Memories:"))
        XCTAssertTrue(summary.contains("Sensors:"))
    }

    func testContextPacket_TotalElements() async throws {
        // Given: Built context
        let context = try await contextBroker.buildContext(forPrompt: "Test")

        // When: Getting total elements
        let total = context.totalElements

        // Then: Should be sum of all components
        let expected = context.threadHistory.count +
                      context.semanticMemory.count +
                      1 // sensor snapshot
        XCTAssertEqual(total, expected)
    }

    func testContextPacket_IsEmpty() {
        // Given: Empty context
        let emptyContext = ContextPacket(
            threadHistory: [],
            semanticMemory: [],
            sensorSnapshot: SensorSnapshot()
        )

        // Then: Should be marked as empty
        XCTAssertTrue(emptyContext.isEmpty)

        // Given: Non-empty context
        let nonEmptyContext = ContextPacket(
            threadHistory: [ThreadMessage(role: .user, content: "Test")],
            semanticMemory: [],
            sensorSnapshot: SensorSnapshot()
        )

        // Then: Should not be empty
        XCTAssertFalse(nonEmptyContext.isEmpty)
    }

    // MARK: - Performance Tests

    func testPerformance_BuildContext() {
        measure {
            let expectation = XCTestExpectation(description: "Context built")

            Task {
                _ = try? await contextBroker.buildContext(forPrompt: "Performance test")
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testPerformance_ConcurrentContextBuilds() {
        measure {
            let expectation = XCTestExpectation(description: "Concurrent builds")
            expectation.expectedFulfillmentCount = 10

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<10 {
                        group.addTask {
                            _ = try? await self.contextBroker.buildContext(forPrompt: "Query \(i)")
                            expectation.fulfill()
                        }
                    }
                }
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Integration Tests

    func testIntegration_FullContextWorkflow() async throws {
        // Given: Complete setup

        // When: Building context multiple times
        let context1 = try await contextBroker.buildContext(forPrompt: "First query")
        let context2 = try await contextBroker.buildContext(forPrompt: "Second query")

        // Then: Both should succeed
        XCTAssertNotNil(context1)
        XCTAssertNotNil(context2)
        XCTAssertFalse(context1.isEmpty)
        XCTAssertFalse(context2.isEmpty)

        // And: Should have called all mocks
        XCTAssertEqual(mockThreadStorage.fetchCallCount, 2)
        XCTAssertEqual(mockVectorStore.searchCallCount, 2)
        XCTAssertEqual(mockSensorAggregator.snapshotCallCount, 2)
    }

    func testIntegration_ContextWithAllComponents() async throws {
        // Given: Rich context with all components

        // When: Building context
        let context = try await contextBroker.buildContext(forPrompt: "Comprehensive query")

        // Then: Should have all components
        XCTAssertFalse(context.threadHistory.isEmpty, "Should have thread history")
        XCTAssertFalse(context.semanticMemory.isEmpty, "Should have semantic memory")
        XCTAssertNotNil(context.sensorSnapshot.location, "Should have location")
        XCTAssertNotNil(context.sensorSnapshot.activity, "Should have activity")
        XCTAssertNotNil(context.sensorSnapshot.healthMetrics, "Should have health metrics")
        XCTAssertNotNil(context.metadata, "Should have metadata")
        XCTAssertNotNil(context.metadata?.buildDuration, "Should have build duration")
    }

    // MARK: - Data Model Tests

    func testThreadMessage_Creation() {
        // Given: Thread message
        let message = ThreadMessage(
            role: .user,
            content: "Test message",
            timestamp: Date()
        )

        // Then: Should be valid
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Test message")
        XCTAssertNotNil(message.id)
    }

    func testMemoryFragment_SimilarityCalculation() {
        // Given: Two memory fragments
        let fragment1 = MemoryFragment(
            content: "Test 1",
            embedding: [1.0, 0.0, 0.0],
            source: .document
        )

        let fragment2 = MemoryFragment(
            content: "Test 2",
            embedding: [1.0, 0.0, 0.0],
            source: .document
        )

        // When: Calculating similarity
        let similarity = fragment1.similarity(to: fragment2)

        // Then: Identical embeddings should have similarity of 1.0
        XCTAssertEqual(similarity, 1.0, accuracy: 0.01)
    }

    func testCosineSimilarity_OrthogonalVectors() {
        // Given: Orthogonal vectors
        let a: [Float] = [1.0, 0.0, 0.0]
        let b: [Float] = [0.0, 1.0, 0.0]

        // When: Calculating similarity
        let similarity = cosineSimilarity(a, b)

        // Then: Should be 0 (orthogonal)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.01)
    }

    func testCosineSimilarity_IdenticalVectors() {
        // Given: Identical vectors
        let a: [Float] = [1.0, 2.0, 3.0]
        let b: [Float] = [1.0, 2.0, 3.0]

        // When: Calculating similarity
        let similarity = cosineSimilarity(a, b)

        // Then: Should be 1.0 (identical)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.01)
    }
}
