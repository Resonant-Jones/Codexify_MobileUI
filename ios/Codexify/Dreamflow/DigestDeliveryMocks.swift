//
//  DigestDeliveryMocks.swift
//  Codexify:Scout
//
//  Created by Codexify:Scout
//  Phase Three: Digest Delivery System - Mock Implementations
//
//  Provides mock implementations for testing and simulator environments
//

import Foundation
import UserNotifications

// MARK: - Mock Notification Center

/// Mock implementation of notification center for testing
class MockNotificationCenter: NotificationCenterProtocol {

    // MARK: - Tracking Properties

    var sentNotifications: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var authorizationRequested = false
    var authorizationResult: Bool = true
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var shouldFailSend: Bool = false

    // MARK: - NotificationCenterProtocol

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequested = true
        authorizationStatus = authorizationResult ? .authorized : .denied
        print("🔔 [MockNotificationCenter] Authorization requested: \(authorizationResult)")
        return authorizationResult
    }

    func getNotificationSettings() async -> UNNotificationSettings {
        // Create mock settings
        return MockUNNotificationSettings(authorizationStatus: authorizationStatus)
    }

    func add(_ request: UNNotificationRequest) async throws {
        if shouldFailSend {
            throw NSError(domain: "MockNotificationError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Mock notification send failed"
            ])
        }

        sentNotifications.append(request)
        print("🔔 [MockNotificationCenter] Notification sent: \(request.content.title)")
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        sentNotifications.removeAll { identifiers.contains($0.identifier) }
        print("🔔 [MockNotificationCenter] Removed \(identifiers.count) notifications")
    }

    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return sentNotifications
    }

    // MARK: - Helper Methods

    func reset() {
        sentNotifications.removeAll()
        removedIdentifiers.removeAll()
        authorizationRequested = false
        authorizationResult = true
        authorizationStatus = .notDetermined
        shouldFailSend = false
    }
}

/// Mock UNNotificationSettings for testing
class MockUNNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

// MARK: - Mock Background Task Scheduler

/// Mock implementation of background task scheduler for testing
class MockBackgroundTaskScheduler: BackgroundTaskSchedulerProtocol {

    // MARK: - Tracking Properties

    var registeredTasks: [String: (BackgroundTaskProtocol) -> Void] = [:]
    var submittedRequests: [MockBackgroundTaskRequest] = []
    var cancelledIdentifiers: [String] = []
    var shouldFailSubmit: Bool = false
    var shouldFailRegister: Bool = false

    // MARK: - BackgroundTaskSchedulerProtocol

    func register(
        forTaskWithIdentifier identifier: String,
        using queue: DispatchQueue?,
        launchHandler: @escaping (BackgroundTaskProtocol) -> Void
    ) -> Bool {
        if shouldFailRegister {
            print("⏰ [MockTaskScheduler] Registration failed for: \(identifier)")
            return false
        }

        registeredTasks[identifier] = launchHandler
        print("⏰ [MockTaskScheduler] Registered task: \(identifier)")
        return true
    }

    func submit(_ taskRequest: BackgroundTaskRequestProtocol) throws {
        if shouldFailSubmit {
            throw NSError(domain: "MockSchedulerError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Mock task submission failed"
            ])
        }

        guard let mockRequest = taskRequest as? MockBackgroundTaskRequest else {
            throw NSError(domain: "MockSchedulerError", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid task request type"
            ])
        }

        submittedRequests.append(mockRequest)
        print("⏰ [MockTaskScheduler] Submitted task: \(mockRequest.identifier) at \(mockRequest.earliestBeginDate?.description ?? "now")")
    }

    func cancel(taskRequestWithIdentifier identifier: String) {
        cancelledIdentifiers.append(identifier)
        submittedRequests.removeAll { $0.identifier == identifier }
        print("⏰ [MockTaskScheduler] Cancelled task: \(identifier)")
    }

    // MARK: - Helper Methods

    /// Simulate task execution
    func simulateTaskExecution(identifier: String) {
        guard let handler = registeredTasks[identifier] else {
            print("⚠️ [MockTaskScheduler] No handler for task: \(identifier)")
            return
        }

        let task = MockBackgroundTask(identifier: identifier)
        print("⏰ [MockTaskScheduler] Simulating task execution: \(identifier)")
        handler(task)
    }

    func reset() {
        registeredTasks.removeAll()
        submittedRequests.removeAll()
        cancelledIdentifiers.removeAll()
        shouldFailSubmit = false
        shouldFailRegister = false
    }
}

// MARK: - Mock Background Task

/// Mock implementation of background task
class MockBackgroundTask: BackgroundTaskProtocol {
    let identifier: String
    var expirationHandler: (() -> Void)?
    var completed: Bool = false
    var success: Bool = false

    init(identifier: String) {
        self.identifier = identifier
    }

    func setTaskCompleted(success: Bool) {
        self.completed = true
        self.success = success
        print("⏰ [MockTask] Task completed: \(identifier) (success: \(success))")
    }

    /// Simulate task expiration
    func simulateExpiration() {
        print("⏰ [MockTask] Simulating expiration: \(identifier)")
        expirationHandler?()
    }
}

// MARK: - Mock Background Task Request

/// Mock implementation of background task request
class MockBackgroundTaskRequest: BackgroundTaskRequestProtocol {
    var identifier: String
    var earliestBeginDate: Date?
    var requiresNetworkConnectivity: Bool = false
    var requiresExternalPower: Bool = false

    init(identifier: String) {
        self.identifier = identifier
    }
}

// MARK: - Mock Digest Storage

/// Mock implementation of digest storage for testing
class MockDigestStorage: DigestStorageProtocol {

    // MARK: - Tracking Properties

    var savedDigests: [MorningDigest] = []
    var lastDelivery: Date?
    var shouldFailSave: Bool = false
    var shouldFailFetch: Bool = false

    // MARK: - DigestStorageProtocol

    func save(_ digest: MorningDigest) async throws {
        if shouldFailSave {
            throw NSError(domain: "MockStorageError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Mock storage save failed"
            ])
        }

        savedDigests.append(digest)
        print("💾 [MockStorage] Saved digest: \(digest.headline)")
    }

    func fetch(for date: Date) async throws -> MorningDigest? {
        if shouldFailFetch {
            throw NSError(domain: "MockStorageError", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Mock storage fetch failed"
            ])
        }

        let calendar = Calendar.current
        return savedDigests.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func fetchRecent(limit: Int) async throws -> [MorningDigest] {
        if shouldFailFetch {
            throw NSError(domain: "MockStorageError", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Mock storage fetch failed"
            ])
        }

        let sorted = savedDigests.sorted { $0.date > $1.date }
        return Array(sorted.prefix(limit))
    }

    func getLastDeliveryDate() async throws -> Date? {
        if shouldFailFetch {
            throw NSError(domain: "MockStorageError", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Mock storage fetch failed"
            ])
        }

        return lastDelivery
    }

    func setLastDeliveryDate(_ date: Date) async throws {
        if shouldFailSave {
            throw NSError(domain: "MockStorageError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Mock storage save failed"
            ])
        }

        lastDelivery = date
        print("💾 [MockStorage] Last delivery set to: \(date)")
    }

    // MARK: - Helper Methods

    func reset() {
        savedDigests.removeAll()
        lastDelivery = nil
        shouldFailSave = false
        shouldFailFetch = false
    }
}

// MARK: - Mock Morning Digest Generator

/// Mock implementation for testing digest generation
class MockMorningDigestGenerator: MorningDigestGenerator {
    var shouldFail: Bool = false
    var generatedDigests: [MorningDigest] = []
    var callCount: Int = 0

    override func generateMorningDigest(
        from logs: [DreamflowLog],
        date: Date = Date()
    ) async throws -> MorningDigest {
        callCount += 1

        if shouldFail {
            throw NSError(domain: "MockGeneratorError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Mock generator failed"
            ])
        }

        let digest = MorningDigest(
            date: date,
            headline: "Mock digest from \(logs.count) logs",
            keyInsights: [
                "Mock insight 1",
                "Mock insight 2",
                "Mock insight 3"
            ],
            moodTrend: "Mock mood: positive",
            actionableItems: [
                "Mock action 1",
                "Mock action 2"
            ],
            weeklyPatterns: logs.count >= 3 ? ["Mock pattern 1"] : nil,
            generatedFrom: logs.map { $0.id }
        )

        generatedDigests.append(digest)
        return digest
    }

    func reset() {
        shouldFail = false
        generatedDigests.removeAll()
        callCount = 0
    }
}

// MARK: - Test Helpers

/// Convenience factory for creating mock delivery managers
extension DigestDeliveryManager {
    /// Create a fully mocked manager for testing
    static func makeMock(
        notificationCenter: MockNotificationCenter = MockNotificationCenter(),
        taskScheduler: MockBackgroundTaskScheduler = MockBackgroundTaskScheduler(),
        storage: MockDigestStorage = MockDigestStorage(),
        generator: MorningDigestGenerator? = nil,
        config: DigestDeliveryConfig = .default
    ) -> DigestDeliveryManager {
        let mockGenerator = generator ?? MockMorningDigestGenerator()

        return DigestDeliveryManager(
            notificationCenter: notificationCenter,
            taskScheduler: taskScheduler,
            storage: storage,
            generator: mockGenerator,
            config: config
        )
    }
}

// MARK: - Sample Data

/// Sample digests for testing and previews
struct SampleDigests {
    static let single = MorningDigest(
        date: Date(),
        headline: "A productive day of focused work",
        keyInsights: [
            "Completed major milestone in iOS development",
            "Maintained consistent energy throughout the day",
            "Strong focus on learning and implementation"
        ],
        moodTrend: "Energized and positive with clear direction",
        actionableItems: [
            "Continue momentum with next phase implementation",
            "Schedule time for code review and refactoring"
        ],
        weeklyPatterns: nil,
        generatedFrom: []
    )

    static let weekly = MorningDigest(
        date: Date(),
        headline: "A week of steady progress and growth",
        keyInsights: [
            "Consistent daily development practice established",
            "Successfully integrated multiple system components",
            "Balanced technical work with strategic planning",
            "Improved testing coverage across modules"
        ],
        moodTrend: "Steadily positive with growing confidence",
        actionableItems: [
            "Begin Phase Three implementation",
            "Document architectural decisions",
            "Schedule demo and feedback session"
        ],
        weeklyPatterns: [
            "Peak productivity in morning hours",
            "Consistent commit pattern throughout week",
            "Regular breaks maintained for sustainable pace"
        ],
        generatedFrom: []
    )

    static let minimal = MorningDigest(
        date: Date(),
        headline: "Quiet reflection day",
        keyInsights: [
            "Light activity recorded",
            "Focused on planning and design"
        ],
        moodTrend: nil,
        actionableItems: [
            "Resume regular development schedule"
        ],
        weeklyPatterns: nil,
        generatedFrom: []
    )

    /// Generate a sample digest with custom parameters
    static func generate(
        daysAgo: Int = 0,
        headline: String? = nil,
        insightCount: Int = 3
    ) -> MorningDigest {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()

        var insights: [String] = []
        for i in 1...insightCount {
            insights.append("Sample insight \(i) for digest")
        }

        return MorningDigest(
            date: date,
            headline: headline ?? "Sample digest for \(daysAgo) days ago",
            keyInsights: insights,
            moodTrend: "Sample mood trend",
            actionableItems: [
                "Sample action 1",
                "Sample action 2"
            ],
            weeklyPatterns: daysAgo >= 7 ? ["Sample pattern"] : nil,
            generatedFrom: []
        )
    }
}
