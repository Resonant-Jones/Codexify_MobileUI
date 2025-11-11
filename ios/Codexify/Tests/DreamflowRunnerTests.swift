//
//  DreamflowRunnerTests.swift
//  Codexify Tests
//
//  Comprehensive test suite for DreamflowRunner
//  Phase Two: Dreamflow Runtime Validation
//

import XCTest
@testable import Codexify

// MARK: - Mock Storage

class MockDreamflowStorage: DreamflowStorageProtocol {
    var mockLogs: [DreamflowLog] = []
    var shouldFail: Bool = false

    func save(_ log: DreamflowLog) async throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1)
        }
        mockLogs.append(log)
    }

    func fetch(for date: Date) async throws -> DreamflowLog? {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1)
        }
        let calendar = Calendar.current
        return mockLogs.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func fetchRecent(limit: Int) async throws -> [DreamflowLog] {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1)
        }
        return Array(mockLogs.suffix(limit))
    }

    func delete(_ id: UUID) async throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1)
        }
        mockLogs.removeAll { $0.id == id }
    }
}

// MARK: - Test Suite

class DreamflowRunnerTests: XCTestCase {

    var mockStorage: MockDreamflowStorage!
    var mockRouter: ModelRouter!
    var dreamflowRunner: DreamflowRunner!

    override func setUp() {
        super.setUp()

        mockStorage = MockDreamflowStorage()

        // Setup mock router
        let config = ProviderConfig(type: .openai, name: "TestProvider")
        let preferences = UserProviderPreferences(
            defaultProvider: config,
            fallbackProviders: [],
            enableFallback: false
        )
        mockRouter = ModelRouter(preferences: preferences)

        dreamflowRunner = DreamflowRunner(
            config: .default,
            modelRouter: mockRouter,
            storage: mockStorage
        )
    }

    override func tearDown() {
        mockStorage = nil
        mockRouter = nil
        dreamflowRunner = nil

        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDreamflowConfig_Default() {
        let config = DreamflowConfig.default

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.preferredHour, 3)
        XCTAssertTrue(config.requiresCharging)
        XCTAssertEqual(config.minimumBatteryLevel, 0.3, accuracy: 0.01)
        XCTAssertTrue(config.includeFields.summary)
        XCTAssertTrue(config.includeFields.moodSketch)
        XCTAssertTrue(config.includeFields.foresight)
        XCTAssertTrue(config.includeFields.anchors)
    }

    func testDreamflowConfig_Minimal() {
        let config = DreamflowConfig.minimal

        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.includeFields.summary)
        XCTAssertFalse(config.includeFields.moodSketch)
        XCTAssertFalse(config.includeFields.foresight)
        XCTAssertFalse(config.includeFields.anchors)
        XCTAssertEqual(config.maxTokens, 1000)
    }

    // MARK: - DreamflowLog Tests

    func testDreamflowLog_Creation() {
        let log = DreamflowLog(
            date: Date(),
            summary: "Test summary",
            moodSketch: "calm and focused",
            foresight: "trends indicate...",
            anchors: ["productivity", "learning"],
            modelUsed: "gpt-4",
            duration: 5.2
        )

        XCTAssertNotNil(log.id)
        XCTAssertEqual(log.summary, "Test summary")
        XCTAssertEqual(log.moodSketch, "calm and focused")
        XCTAssertEqual(log.anchors.count, 2)
        XCTAssertEqual(log.duration, 5.2, accuracy: 0.01)
    }

    func testDreamflowLog_Codable() throws {
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(log)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DreamflowLog.self, from: data)

        XCTAssertEqual(decoded.id, log.id)
        XCTAssertEqual(decoded.summary, log.summary)
    }

    // MARK: - Storage Tests

    func testStorage_SaveAndFetch() async throws {
        let log = DreamflowLog(
            date: Date(),
            summary: "Test summary",
            modelUsed: "gpt-4",
            duration: 1.0
        )

        try await mockStorage.save(log)

        let fetched = try await mockStorage.fetch(for: log.date)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, log.id)
    }

    func testStorage_FetchRecent() async throws {
        // Create multiple logs
        for i in 0..<5 {
            let log = DreamflowLog(
                date: Date().addingTimeInterval(TimeInterval(-86400 * i)),
                summary: "Summary \(i)",
                modelUsed: "gpt-4",
                duration: 1.0
            )
            try await mockStorage.save(log)
        }

        let recent = try await mockStorage.fetchRecent(limit: 3)
        XCTAssertEqual(recent.count, 3)
    }

    func testStorage_Delete() async throws {
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )

        try await mockStorage.save(log)
        XCTAssertEqual(mockStorage.mockLogs.count, 1)

        try await mockStorage.delete(log.id)
        XCTAssertEqual(mockStorage.mockLogs.count, 0)
    }

    // MARK: - DreamflowBuilder Tests

    func testDreamflowBuilder_BuildPrompts() {
        let context = createMockContext()
        let builder = DreamflowBuilder(config: .default)

        let prompts = builder.buildPrompts(from: context, config: .default)

        XCTAssertFalse(prompts.summary.isEmpty)
        XCTAssertNotNil(prompts.moodSketch)
        XCTAssertNotNil(prompts.foresight)
        XCTAssertNotNil(prompts.anchors)
        XCTAssertFalse(prompts.combined.isEmpty)
    }

    func testDreamflowBuilder_SummaryPrompt() {
        let context = createMockContext()
        let builder = DreamflowBuilder(config: .default)

        let prompts = builder.buildPrompts(from: context, config: .default)

        XCTAssertTrue(prompts.summary.contains("Daily Summary"))
        XCTAssertTrue(prompts.summary.contains("Context"))
    }

    func testDreamflowBuilder_MinimalConfig() {
        let context = createMockContext()
        let builder = DreamflowBuilder(config: .minimal)

        let prompts = builder.buildPrompts(from: context, config: .minimal)

        XCTAssertFalse(prompts.summary.isEmpty)
        XCTAssertNil(prompts.moodSketch)
        XCTAssertNil(prompts.foresight)
        XCTAssertNil(prompts.anchors)
    }

    // MARK: - Error Handling Tests

    func testDreamflowError_NotEnabled() {
        let error = DreamflowError.notEnabled

        XCTAssertEqual(
            error.localizedDescription,
            "Dreamflow is not enabled in configuration"
        )
    }

    func testDreamflowError_LowBattery() {
        let error = DreamflowError.lowBattery(current: 0.15, required: 0.3)

        XCTAssertTrue(error.localizedDescription?.contains("15%") == true)
        XCTAssertTrue(error.localizedDescription?.contains("30%") == true)
    }

    // MARK: - Morning Digest Tests

    func testMorningDigest_Creation() {
        let digest = MorningDigest(
            date: Date(),
            headline: "A productive week",
            keyInsights: ["Insight 1", "Insight 2"],
            moodTrend: "positive",
            actionableItems: ["Action 1"],
            generatedFrom: [UUID()]
        )

        XCTAssertNotNil(digest.id)
        XCTAssertEqual(digest.headline, "A productive week")
        XCTAssertEqual(digest.keyInsights.count, 2)
    }

    // MARK: - Integration Tests

    func testDreamflowRunner_Initialization() {
        XCTAssertNotNil(dreamflowRunner)
        XCTAssertFalse(dreamflowRunner.running)
    }

    func testScheduling_CalculatesNextRunDate() throws {
        // This would test the scheduling logic
        // Currently a placeholder as scheduling is TODO
        XCTAssertNoThrow(try dreamflowRunner.scheduleNextRun())
    }

    func testCancelScheduledRun() {
        XCTAssertNoThrow(dreamflowRunner.cancelScheduledRun())
    }

    // MARK: - Helper Methods

    private func createMockContext() -> DreamflowContext {
        let messages = [
            ThreadMessage(role: .user, content: "Test message 1"),
            ThreadMessage(role: .assistant, content: "Response 1")
        ]

        let fragments = [
            MemoryFragment(
                content: "Test memory",
                embedding: [Float](repeating: 0.5, count: 384),
                source: .document
            )
        ]

        let sensorSummary = DreamflowContext.SensorDaySummary(
            locations: ["Home", "Office"],
            activities: ["walking", "stationary"],
            avgHeartRate: 72.0,
            totalSteps: 8000,
            totalDistance: 5.2
        )

        let dateRange = DateInterval(
            start: Calendar.current.startOfDay(for: Date()),
            end: Date()
        )

        return DreamflowContext(
            threadHistory: messages,
            memoryFragments: fragments,
            sensorSummary: sensorSummary,
            dateRange: dateRange
        )
    }
}
