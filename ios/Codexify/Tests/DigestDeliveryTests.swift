//
//  DigestDeliveryTests.swift
//  Codexify Tests
//
//  Comprehensive test suite for DigestDelivery system
//  Phase Three: Digest Delivery System Validation
//

import XCTest
@testable import Codexify

// MARK: - Test Suite

class DigestDeliveryTests: XCTestCase {

    var mockNotificationCenter: MockNotificationCenter!
    var mockTaskScheduler: MockBackgroundTaskScheduler!
    var mockStorage: MockDigestStorage!
    var mockGenerator: MockMorningDigestGenerator!
    var manager: DigestDeliveryManager!

    override func setUp() {
        super.setUp()

        mockNotificationCenter = MockNotificationCenter()
        mockTaskScheduler = MockBackgroundTaskScheduler()
        mockStorage = MockDigestStorage()
        mockGenerator = MockMorningDigestGenerator()

        manager = DigestDeliveryManager.makeMock(
            notificationCenter: mockNotificationCenter,
            taskScheduler: mockTaskScheduler,
            storage: mockStorage,
            generator: mockGenerator,
            config: .default
        )
    }

    override func tearDown() {
        mockNotificationCenter = nil
        mockTaskScheduler = nil
        mockStorage = nil
        mockGenerator = nil
        manager = nil

        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDigestDeliveryConfig_Default() {
        let config = DigestDeliveryConfig.default

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.deliveryHour, 8)
        XCTAssertTrue(config.allowOnBattery)
        XCTAssertTrue(config.includeSummary)
        XCTAssertEqual(config.notificationTitle, "☀️ Your Morning Digest")
        XCTAssertEqual(config.notificationCategory, "DIGEST_DELIVERY")
        XCTAssertEqual(config.minimumDeliveryInterval, 3600)
    }

    func testDigestDeliveryConfig_Minimal() {
        let config = DigestDeliveryConfig.minimal

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.deliveryHour, 9)
        XCTAssertFalse(config.includeSummary)
        XCTAssertEqual(config.minimumDeliveryInterval, 7200)
    }

    func testDigestDeliveryConfig_CustomHour() {
        let config = DigestDeliveryConfig(deliveryHour: 15)
        XCTAssertEqual(config.deliveryHour, 15)
    }

    func testDigestDeliveryConfig_HourClamping() {
        let tooEarly = DigestDeliveryConfig(deliveryHour: -1)
        XCTAssertEqual(tooEarly.deliveryHour, 0)

        let tooLate = DigestDeliveryConfig(deliveryHour: 25)
        XCTAssertEqual(tooLate.deliveryHour, 23)
    }

    func testDigestDeliveryConfig_Codable() throws {
        let config = DigestDeliveryConfig.default

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DigestDeliveryConfig.self, from: data)

        XCTAssertEqual(decoded.deliveryHour, config.deliveryHour)
        XCTAssertEqual(decoded.enabled, config.enabled)
        XCTAssertEqual(decoded.notificationTitle, config.notificationTitle)
    }

    // MARK: - Manager Initialization Tests

    func testManagerInitialization() {
        XCTAssertNotNil(manager)
    }

    func testManagerInitialization_WithRealComponents() {
        // Test that real components can be created
        let realGenerator = MorningDigestGenerator()
        let realManager = DigestDeliveryManager.makeReal(
            generator: realGenerator,
            config: .default
        )

        XCTAssertNotNil(realManager)
    }

    // MARK: - Immediate Delivery Tests

    func testDeliverDigestNow_Success() async throws {
        // Setup: Add sample Dreamflow logs
        let logsStorage = DreamflowStorage.shared
        for i in 0..<7 {
            let log = DreamflowLog(
                date: Date().addingTimeInterval(TimeInterval(-86400 * i)),
                summary: "Daily summary \(i)",
                moodSketch: "Focused and productive",
                foresight: "Continue current trajectory",
                anchors: ["productivity", "learning"],
                modelUsed: "gpt-4",
                duration: 5.0
            )
            try await logsStorage.save(log)
        }

        // Execute
        let digest = try await manager.deliverDigestNow()

        // Verify
        XCTAssertEqual(mockGenerator.callCount, 1)
        XCTAssertEqual(mockStorage.savedDigests.count, 1)
        XCTAssertEqual(mockStorage.savedDigests.first?.id, digest.id)
        XCTAssertEqual(mockNotificationCenter.sentNotifications.count, 1)
        XCTAssertTrue(mockNotificationCenter.authorizationRequested)
    }

    func testDeliverDigestNow_SendsNotification() async throws {
        // Setup
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test summary",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Execute
        _ = try await manager.deliverDigestNow()

        // Verify notification was sent
        XCTAssertEqual(mockNotificationCenter.sentNotifications.count, 1)

        let notification = mockNotificationCenter.sentNotifications[0]
        XCTAssertEqual(notification.content.title, "☀️ Your Morning Digest")
        XCTAssertTrue(notification.content.body.contains("Mock"))
        XCTAssertEqual(notification.content.categoryIdentifier, "DIGEST_DELIVERY")
    }

    func testDeliverDigestNow_StoresDigest() async throws {
        // Setup
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Execute
        let digest = try await manager.deliverDigestNow()

        // Verify storage
        XCTAssertTrue(mockStorage.savedDigests.contains { $0.id == digest.id })
        XCTAssertNotNil(mockStorage.lastDelivery)
    }

    func testDeliverDigestNow_NotificationDenied() async throws {
        // Setup: User denies notifications
        mockNotificationCenter.authorizationResult = false

        // Execute & Verify
        do {
            _ = try await manager.deliverDigestNow()
            XCTFail("Expected notificationDenied error")
        } catch let error as DigestDeliveryError {
            switch error {
            case .notificationDenied:
                break // Expected
            default:
                XCTFail("Expected notificationDenied, got \(error)")
            }
        }
    }

    func testDeliverDigestNow_GenerationFailed() async throws {
        // Setup: Generator fails
        mockGenerator.shouldFail = true

        // Execute & Verify
        do {
            _ = try await manager.deliverDigestNow()
            XCTFail("Expected generationFailed error")
        } catch let error as DigestDeliveryError {
            switch error {
            case .generationFailed:
                break // Expected
            default:
                XCTFail("Expected generationFailed, got \(error)")
            }
        }
    }

    func testDeliverDigestNow_DisabledConfig() async throws {
        // Setup: Disabled config
        let disabledConfig = DigestDeliveryConfig(enabled: false)
        let disabledManager = DigestDeliveryManager.makeMock(
            notificationCenter: mockNotificationCenter,
            taskScheduler: mockTaskScheduler,
            storage: mockStorage,
            generator: mockGenerator,
            config: disabledConfig
        )

        // Execute & Verify
        do {
            _ = try await disabledManager.deliverDigestNow()
            XCTFail("Expected deliveryDisabled error")
        } catch let error as DigestDeliveryError {
            switch error {
            case .deliveryDisabled:
                break // Expected
            default:
                XCTFail("Expected deliveryDisabled, got \(error)")
            }
        }
    }

    func testDeliverDigestNow_RateLimiting() async throws {
        // Setup: Previous delivery
        let recentDelivery = Date().addingTimeInterval(-1800) // 30 minutes ago
        try await mockStorage.setLastDeliveryDate(recentDelivery)

        // Execute & Verify
        do {
            _ = try await manager.deliverDigestNow()
            XCTFail("Expected rateLimitExceeded error")
        } catch let error as DigestDeliveryError {
            switch error {
            case .rateLimitExceeded:
                break // Expected
            default:
                XCTFail("Expected rateLimitExceeded, got \(error)")
            }
        }
    }

    func testDeliverDigestNow_RateLimitPassed() async throws {
        // Setup: Old delivery (more than 1 hour ago)
        let oldDelivery = Date().addingTimeInterval(-7200) // 2 hours ago
        try await mockStorage.setLastDeliveryDate(oldDelivery)

        // Add sample log
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Execute - should succeed
        let digest = try await manager.deliverDigestNow()

        XCTAssertNotNil(digest)
        XCTAssertEqual(mockStorage.savedDigests.count, 1)
    }

    // MARK: - Scheduling Tests

    func testScheduleDailyDigest_Success() throws {
        // Execute
        try manager.scheduleDailyDigest()

        // Verify
        XCTAssertEqual(mockTaskScheduler.submittedRequests.count, 1)
        XCTAssertEqual(mockTaskScheduler.submittedRequests[0].identifier, "com.codexify.dailyDigest")
        XCTAssertNotNil(mockTaskScheduler.submittedRequests[0].earliestBeginDate)
    }

    func testScheduleDailyDigest_CalculatesCorrectTime() throws {
        // Execute
        try manager.scheduleDailyDigest()

        // Verify time is in the future and at the configured hour
        let request = mockTaskScheduler.submittedRequests[0]
        guard let scheduledDate = request.earliestBeginDate else {
            XCTFail("No scheduled date")
            return
        }

        XCTAssertGreaterThan(scheduledDate, Date())

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: scheduledDate)
        XCTAssertEqual(components.hour, 8) // Default config hour
    }

    func testScheduleDailyDigest_DisabledConfig() {
        // Setup
        let disabledConfig = DigestDeliveryConfig(enabled: false)
        let disabledManager = DigestDeliveryManager.makeMock(
            notificationCenter: mockNotificationCenter,
            taskScheduler: mockTaskScheduler,
            storage: mockStorage,
            generator: mockGenerator,
            config: disabledConfig
        )

        // Execute & Verify
        XCTAssertThrowsError(try disabledManager.scheduleDailyDigest()) { error in
            guard let deliveryError = error as? DigestDeliveryError else {
                XCTFail("Wrong error type")
                return
            }

            switch deliveryError {
            case .deliveryDisabled:
                break // Expected
            default:
                XCTFail("Expected deliveryDisabled, got \(deliveryError)")
            }
        }
    }

    func testScheduleDailyDigest_SchedulerUnavailable() throws {
        // Setup: No scheduler
        let noSchedulerManager = DigestDeliveryManager(
            notificationCenter: mockNotificationCenter,
            taskScheduler: nil,
            storage: mockStorage,
            generator: mockGenerator,
            config: .default
        )

        // Execute - should not throw, graceful degradation
        XCTAssertNoThrow(try noSchedulerManager.scheduleDailyDigest())
    }

    func testScheduleDailyDigest_SchedulerFails() {
        // Setup: Scheduler fails
        mockTaskScheduler.shouldFailSubmit = true

        // Execute & Verify
        XCTAssertThrowsError(try manager.scheduleDailyDigest()) { error in
            guard let deliveryError = error as? DigestDeliveryError else {
                XCTFail("Wrong error type")
                return
            }

            switch deliveryError {
            case .taskSchedulingFailed:
                break // Expected
            default:
                XCTFail("Expected taskSchedulingFailed, got \(deliveryError)")
            }
        }
    }

    func testCancelScheduledDigest() throws {
        // Setup: Schedule first
        try manager.scheduleDailyDigest()
        XCTAssertEqual(mockTaskScheduler.submittedRequests.count, 1)

        // Execute
        manager.cancelScheduledDigest()

        // Verify
        XCTAssertEqual(mockTaskScheduler.cancelledIdentifiers.count, 1)
        XCTAssertEqual(mockTaskScheduler.cancelledIdentifiers[0], "com.codexify.dailyDigest")
    }

    // MARK: - Background Task Tests

    func testRegisterBackgroundTask_Success() {
        // Execute
        manager.registerBackgroundTask()

        // Verify
        XCTAssertTrue(mockTaskScheduler.registeredTasks.keys.contains("com.codexify.dailyDigest"))
    }

    func testRegisterBackgroundTask_RegistrationFails() {
        // Setup
        mockTaskScheduler.shouldFailRegister = true

        // Execute - should not crash
        XCTAssertNoThrow(manager.registerBackgroundTask())
    }

    func testBackgroundTask_ExecutesDelivery() async throws {
        // Setup: Register task
        manager.registerBackgroundTask()

        // Add sample log
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Background test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Execute: Simulate task execution
        mockTaskScheduler.simulateTaskExecution(identifier: "com.codexify.dailyDigest")

        // Wait for async execution
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Verify: Digest was generated and delivered
        XCTAssertEqual(mockGenerator.callCount, 1)
        XCTAssertEqual(mockNotificationCenter.sentNotifications.count, 1)
    }

    // MARK: - Notification Tests

    func testNotificationContent_WithSummary() async throws {
        // Setup: Config with summary
        let summaryConfig = DigestDeliveryConfig(includeSummary: true)
        let summaryManager = DigestDeliveryManager.makeMock(
            notificationCenter: mockNotificationCenter,
            taskScheduler: mockTaskScheduler,
            storage: mockStorage,
            generator: mockGenerator,
            config: summaryConfig
        )

        // Add log
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Execute
        _ = try await summaryManager.deliverDigestNow()

        // Verify notification contains summary
        let notification = mockNotificationCenter.sentNotifications[0]
        XCTAssertTrue(notification.content.body.contains("Mock"))
    }

    func testNotificationContent_WithoutSummary() async throws {
        // Setup: Config without summary
        let noSummaryConfig = DigestDeliveryConfig(includeSummary: false)
        let noSummaryManager = DigestDeliveryManager.makeMock(
            notificationCenter: mockNotificationCenter,
            taskScheduler: mockTaskScheduler,
            storage: mockStorage,
            generator: mockGenerator,
            config: noSummaryConfig
        )

        // Add log
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Execute
        _ = try await noSummaryManager.deliverDigestNow()

        // Verify notification is generic
        let notification = mockNotificationCenter.sentNotifications[0]
        XCTAssertEqual(notification.content.body, "Your daily digest is ready to view")
    }

    func testNotificationUserInfo() async throws {
        // Setup
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Execute
        let digest = try await manager.deliverDigestNow()

        // Verify user info
        let notification = mockNotificationCenter.sentNotifications[0]
        XCTAssertEqual(notification.content.userInfo["digestId"] as? String, digest.id.uuidString)
        XCTAssertEqual(notification.content.userInfo["type"] as? String, "morning_digest")
        XCTAssertNotNil(notification.content.userInfo["digestDate"])
    }

    // MARK: - Storage Tests

    func testStorage_SavesDigest() async throws {
        // Setup
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Execute
        let digest = try await manager.deliverDigestNow()

        // Verify
        let stored = try await mockStorage.fetch(for: digest.date)
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.id, digest.id)
    }

    func testStorage_UpdatesLastDeliveryDate() async throws {
        // Setup
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        let beforeDelivery = Date()

        // Execute
        _ = try await manager.deliverDigestNow()

        // Verify
        let lastDelivery = try await mockStorage.getLastDeliveryDate()
        XCTAssertNotNil(lastDelivery)
        XCTAssertGreaterThanOrEqual(lastDelivery!, beforeDelivery)
    }

    func testStorage_FetchRecent() async throws {
        // Setup: Save multiple digests
        for i in 0..<5 {
            let digest = SampleDigests.generate(daysAgo: i)
            try await mockStorage.save(digest)
        }

        // Execute
        let recent = try await mockStorage.fetchRecent(limit: 3)

        // Verify
        XCTAssertEqual(recent.count, 3)
        // Should be sorted by date descending
        XCTAssertGreaterThanOrEqual(recent[0].date, recent[1].date)
        XCTAssertGreaterThanOrEqual(recent[1].date, recent[2].date)
    }

    // MARK: - Error Handling Tests

    func testErrorDescription_NotificationDenied() {
        let error = DigestDeliveryError.notificationDenied
        XCTAssertTrue(error.localizedDescription?.contains("permission") == true)
    }

    func testErrorDescription_TaskSchedulingFailed() {
        let underlyingError = NSError(domain: "Test", code: -1)
        let error = DigestDeliveryError.taskSchedulingFailed(underlyingError)
        XCTAssertTrue(error.localizedDescription?.contains("schedule") == true)
    }

    func testErrorDescription_GenerationFailed() {
        let underlyingError = NSError(domain: "Test", code: -1)
        let error = DigestDeliveryError.generationFailed(underlyingError)
        XCTAssertTrue(error.localizedDescription?.contains("generate") == true)
    }

    func testErrorDescription_RateLimitExceeded() {
        let nextAvailable = Date().addingTimeInterval(3600)
        let error = DigestDeliveryError.rateLimitExceeded(nextAvailable: nextAvailable)
        XCTAssertTrue(error.localizedDescription?.contains("Try again") == true)
    }

    // MARK: - Integration Tests

    func testFullDeliveryFlow() async throws {
        // Setup: Multiple logs
        let logsStorage = DreamflowStorage.shared
        for i in 0..<7 {
            let log = DreamflowLog(
                date: Date().addingTimeInterval(TimeInterval(-86400 * i)),
                summary: "Day \(i) summary with interesting content",
                moodSketch: "Productive and focused",
                foresight: "Trends indicate continued progress",
                anchors: ["development", "learning", "productivity"],
                modelUsed: "gpt-4",
                duration: Double(5 + i)
            )
            try await logsStorage.save(log)
        }

        // Execute full flow
        let digest = try await manager.deliverDigestNow()

        // Verify complete flow
        XCTAssertNotNil(digest)
        XCTAssertEqual(mockGenerator.callCount, 1)
        XCTAssertEqual(mockStorage.savedDigests.count, 1)
        XCTAssertEqual(mockNotificationCenter.sentNotifications.count, 1)
        XCTAssertNotNil(mockStorage.lastDelivery)

        // Verify digest content
        XCTAssertFalse(digest.headline.isEmpty)
        XCTAssertGreaterThan(digest.keyInsights.count, 0)
        XCTAssertNotNil(digest.moodTrend)
        XCTAssertGreaterThan(digest.actionableItems.count, 0)
    }

    func testScheduleAndExecuteFlow() async throws {
        // Setup
        manager.registerBackgroundTask()
        try manager.scheduleDailyDigest()

        // Verify scheduled
        XCTAssertEqual(mockTaskScheduler.submittedRequests.count, 1)

        // Add log
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Test",
            modelUsed: "gpt-4",
            duration: 1.0
        )
        try await logsStorage.save(log)

        // Simulate execution
        mockTaskScheduler.simulateTaskExecution(identifier: "com.codexify.dailyDigest")

        // Wait for async
        try await Task.sleep(nanoseconds: 500_000_000)

        // Verify execution
        XCTAssertEqual(mockNotificationCenter.sentNotifications.count, 1)
    }

    // MARK: - Performance Tests

    func testPerformance_MultipleDeliveries() throws {
        // Setup
        let logsStorage = DreamflowStorage.shared
        let log = DreamflowLog(
            date: Date(),
            summary: "Performance test",
            modelUsed: "gpt-4",
            duration: 1.0
        )

        measure {
            let expectation = self.expectation(description: "Multiple deliveries")
            expectation.expectedFulfillmentCount = 10

            Task {
                try await logsStorage.save(log)

                for i in 0..<10 {
                    // Reset rate limit
                    mockStorage.lastDelivery = Date().addingTimeInterval(TimeInterval(-7200 * (i + 1)))

                    _ = try await manager.deliverDigestNow()
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Sample Data Tests

    func testSampleDigests() {
        let single = SampleDigests.single
        XCTAssertFalse(single.headline.isEmpty)
        XCTAssertGreaterThan(single.keyInsights.count, 0)
        XCTAssertNil(single.weeklyPatterns)

        let weekly = SampleDigests.weekly
        XCTAssertGreaterThan(weekly.keyInsights.count, 0)
        XCTAssertNotNil(weekly.weeklyPatterns)

        let minimal = SampleDigests.minimal
        XCTAssertGreaterThan(minimal.keyInsights.count, 0)
        XCTAssertNil(minimal.moodTrend)
    }

    func testSampleDigests_Generate() {
        let digest = SampleDigests.generate(daysAgo: 3, insightCount: 5)

        XCTAssertEqual(digest.keyInsights.count, 5)

        let calendar = Calendar.current
        let expectedDate = calendar.date(byAdding: .day, value: -3, to: Date())!
        XCTAssertTrue(calendar.isDate(digest.date, inSameDayAs: expectedDate))
    }
}
