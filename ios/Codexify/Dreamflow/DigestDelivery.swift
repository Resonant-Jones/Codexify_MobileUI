//
//  DigestDelivery.swift
//  Codexify:Scout
//
//  Created by Codexify:Scout
//  Phase Three: Digest Delivery System
//
//  Implements automated delivery of MorningDigest objects through:
//  - Local notifications (UNUserNotificationCenter)
//  - Background task scheduling (BGTaskScheduler)
//  - Manual triggers from within the app or dashboard
//

import Foundation
import UserNotifications

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

// MARK: - Configuration

/// Configuration for digest delivery behavior
struct DigestDeliveryConfig: Codable, Equatable {
    /// Hour of day (0-23) to deliver daily digest
    let deliveryHour: Int

    /// Whether to allow delivery when device is on battery power
    let allowOnBattery: Bool

    /// Whether to include full summary in notification body
    let includeSummary: Bool

    /// Title for notification
    let notificationTitle: String

    /// Notification category identifier for actions
    let notificationCategory: String

    /// Enable/disable delivery system
    let enabled: Bool

    /// Minimum interval between manual deliveries (seconds)
    let minimumDeliveryInterval: TimeInterval

    /// Default configuration
    static let `default` = DigestDeliveryConfig(
        deliveryHour: 8,
        allowOnBattery: true,
        includeSummary: true,
        notificationTitle: "☀️ Your Morning Digest",
        notificationCategory: "DIGEST_DELIVERY",
        enabled: true,
        minimumDeliveryInterval: 3600 // 1 hour
    )

    /// Minimal configuration (no battery requirement, short notifications)
    static let minimal = DigestDeliveryConfig(
        deliveryHour: 9,
        allowOnBattery: true,
        includeSummary: false,
        notificationTitle: "Daily Digest Ready",
        notificationCategory: "DIGEST_DELIVERY",
        enabled: true,
        minimumDeliveryInterval: 7200 // 2 hours
    )

    init(
        deliveryHour: Int = 8,
        allowOnBattery: Bool = true,
        includeSummary: Bool = true,
        notificationTitle: String = "☀️ Your Morning Digest",
        notificationCategory: String = "DIGEST_DELIVERY",
        enabled: Bool = true,
        minimumDeliveryInterval: TimeInterval = 3600
    ) {
        self.deliveryHour = min(max(deliveryHour, 0), 23)
        self.allowOnBattery = allowOnBattery
        self.includeSummary = includeSummary
        self.notificationTitle = notificationTitle
        self.notificationCategory = notificationCategory
        self.enabled = enabled
        self.minimumDeliveryInterval = minimumDeliveryInterval
    }
}

// MARK: - Error Types

/// Errors that can occur during digest delivery
enum DigestDeliveryError: Error, LocalizedError {
    case notificationDenied
    case notificationSettingsUnavailable
    case taskSchedulingFailed(Error)
    case generationFailed(Error)
    case storageUnavailable
    case deliveryDisabled
    case rateLimitExceeded(nextAvailable: Date)
    case deviceNotReady
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notificationDenied:
            return "Notification permission denied. Please enable notifications in Settings."
        case .notificationSettingsUnavailable:
            return "Unable to access notification settings."
        case .taskSchedulingFailed(let error):
            return "Failed to schedule background task: \(error.localizedDescription)"
        case .generationFailed(let error):
            return "Failed to generate digest: \(error.localizedDescription)"
        case .storageUnavailable:
            return "Digest storage is unavailable."
        case .deliveryDisabled:
            return "Digest delivery is disabled in configuration."
        case .rateLimitExceeded(let nextAvailable):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Too many deliveries. Try again after \(formatter.string(from: nextAvailable))"
        case .deviceNotReady:
            return "Device is not ready for digest delivery (battery/charging requirement)."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Protocols

/// Protocol for notification center operations (mockable)
protocol NotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func getNotificationSettings() async -> UNNotificationSettings
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers: [String])
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
}

/// Protocol for background task scheduler operations (mockable)
protocol BackgroundTaskSchedulerProtocol {
    func register(
        forTaskWithIdentifier identifier: String,
        using queue: DispatchQueue?,
        launchHandler: @escaping (BackgroundTaskProtocol) -> Void
    ) -> Bool
    func submit(_ taskRequest: BackgroundTaskRequestProtocol) throws
    func cancel(taskRequestWithIdentifier identifier: String)
}

/// Protocol for background task operations
protocol BackgroundTaskProtocol {
    var identifier: String { get }
    func setTaskCompleted(success: Bool)
    var expirationHandler: (() -> Void)? { get set }
}

/// Protocol for background task request
protocol BackgroundTaskRequestProtocol {
    var identifier: String { get set }
    var earliestBeginDate: Date? { get set }
}

/// Protocol for constructing background task requests
protocol BackgroundTaskRequestFactory {
    func makeRequest(identifier: String, earliestBeginDate: Date?) -> BackgroundTaskRequestProtocol
}

/// Protocol for digest storage operations (mockable)
protocol DigestStorageProtocol {
    func save(_ digest: MorningDigest) async throws
    func fetch(for date: Date) async throws -> MorningDigest?
    func fetchRecent(limit: Int) async throws -> [MorningDigest]
    func getLastDeliveryDate() async throws -> Date?
    func setLastDeliveryDate(_ date: Date) async throws
}

// MARK: - Real Implementations

/// Real implementation of NotificationCenterProtocol
class RealNotificationCenter: NotificationCenterProtocol {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return try await center.requestAuthorization(options: options)
    }

    func getNotificationSettings() async -> UNNotificationSettings {
        return await center.notificationSettings()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
}

#if canImport(BackgroundTasks)
/// Real implementation of BackgroundTaskSchedulerProtocol
@available(iOS 13.0, *)
class RealBackgroundTaskScheduler: BackgroundTaskSchedulerProtocol {
    private let scheduler = BGTaskScheduler.shared

    func register(
        forTaskWithIdentifier identifier: String,
        using queue: DispatchQueue?,
        launchHandler: @escaping (BackgroundTaskProtocol) -> Void
    ) -> Bool {
        return scheduler.register(forTaskWithIdentifier: identifier, using: queue) { task in
            launchHandler(RealBackgroundTask(task: task))
        }
    }

    func submit(_ taskRequest: BackgroundTaskRequestProtocol) throws {
        guard let bgRequest = taskRequest as? RealBackgroundTaskRequest else {
            throw DigestDeliveryError.taskSchedulingFailed(
                NSError(domain: "Invalid task request type", code: -1)
            )
        }
        try scheduler.submit(bgRequest.request)
    }

    func cancel(taskRequestWithIdentifier identifier: String) {
        scheduler.cancel(taskRequestWithIdentifier: identifier)
    }
}

/// Real implementation of BackgroundTaskProtocol
@available(iOS 13.0, *)
class RealBackgroundTask: BackgroundTaskProtocol {
    private let task: BGTask

    init(task: BGTask) {
        self.task = task
    }

    var identifier: String {
        return task.identifier
    }

    func setTaskCompleted(success: Bool) {
        task.setTaskCompleted(success: success)
    }

    var expirationHandler: (() -> Void)? {
        get { task.expirationHandler }
        set { task.expirationHandler = newValue }
    }
}

/// Real implementation of BackgroundTaskRequestProtocol
@available(iOS 13.0, *)
class RealBackgroundTaskRequest: BackgroundTaskRequestProtocol {
    let request: BGProcessingTaskRequest

    init(identifier: String, earliestBeginDate: Date? = nil) {
        self.request = BGProcessingTaskRequest(identifier: identifier)
        self.request.earliestBeginDate = earliestBeginDate
    }

    var identifier: String {
        get { request.identifier }
        set { } // Read-only in real implementation
    }

    var earliestBeginDate: Date? {
        get { request.earliestBeginDate }
        set { request.earliestBeginDate = newValue }
    }
}

/// Real implementation of BackgroundTaskRequestFactory
@available(iOS 13.0, *)
struct RealBackgroundTaskRequestFactory: BackgroundTaskRequestFactory {
    func makeRequest(identifier: String, earliestBeginDate: Date?) -> BackgroundTaskRequestProtocol {
        RealBackgroundTaskRequest(identifier: identifier, earliestBeginDate: earliestBeginDate)
    }
}
#endif

/// Stub implementation for BackgroundTaskRequest (iOS <13 fallback)
class StubBackgroundTaskRequest: BackgroundTaskRequestProtocol {
    var identifier: String
    var earliestBeginDate: Date?

    init(identifier: String, earliestBeginDate: Date? = nil) {
        self.identifier = identifier
        self.earliestBeginDate = earliestBeginDate
    }
}

/// Stub factory for cases where BackgroundTasks is unavailable
struct StubBackgroundTaskRequestFactory: BackgroundTaskRequestFactory {
    func makeRequest(identifier: String, earliestBeginDate: Date?) -> BackgroundTaskRequestProtocol {
        StubBackgroundTaskRequest(identifier: identifier, earliestBeginDate: earliestBeginDate)
    }
}

/// In-memory storage for digests
class InMemoryDigestStorage: DigestStorageProtocol {
    static let shared = InMemoryDigestStorage()

    private var digests: [MorningDigest] = []
    private var lastDelivery: Date?
    private let queue = DispatchQueue(label: "com.codexify.digest.storage", attributes: .concurrent)

    private init() {}

    func save(_ digest: MorningDigest) async throws {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async(flags: .barrier) {
                self.digests.append(digest)
                print("💾 [DigestStorage] Saved digest: \(digest.headline)")
                continuation.resume()
            }
        }
    }

    func fetch(for date: Date) async throws -> MorningDigest? {
        return await withCheckedContinuation { continuation in
            queue.async {
                let calendar = Calendar.current
                let digest = self.digests.first { calendar.isDate($0.date, inSameDayAs: date) }
                continuation.resume(returning: digest)
            }
        }
    }

    func fetchRecent(limit: Int) async throws -> [MorningDigest] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let sorted = self.digests.sorted { $0.date > $1.date }
                continuation.resume(returning: Array(sorted.prefix(limit)))
            }
        }
    }

    func getLastDeliveryDate() async throws -> Date? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.lastDelivery)
            }
        }
    }

    func setLastDeliveryDate(_ date: Date) async throws {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async(flags: .barrier) {
                self.lastDelivery = date
                continuation.resume()
            }
        }
    }
}

// MARK: - Digest Delivery Manager

/// Main manager for delivering morning digests via notifications and scheduling
final class DigestDeliveryManager {

    // MARK: - Properties

    private let notificationCenter: NotificationCenterProtocol
    private let taskScheduler: BackgroundTaskSchedulerProtocol?
    private let storage: DigestStorageProtocol
    private let generator: MorningDigestGenerator
    private let requestFactory: BackgroundTaskRequestFactory
    private let config: DigestDeliveryConfig

    // Background task identifier
    private static let backgroundTaskIdentifier = "com.codexify.dailyDigest"

    // MARK: - Initialization

    /// Initialize the digest delivery manager
    /// - Parameters:
    ///   - notificationCenter: Notification center for sending notifications
    ///   - taskScheduler: Background task scheduler (optional, nil for iOS <13 or mocks)
    ///   - storage: Storage for digest persistence
    ///   - generator: Generator for creating digests
    ///   - requestFactory: Factory for creating background task requests
    ///   - config: Delivery configuration
    init(
        notificationCenter: NotificationCenterProtocol,
        taskScheduler: BackgroundTaskSchedulerProtocol? = nil,
        storage: DigestStorageProtocol,
        generator: MorningDigestGenerator,
        requestFactory: BackgroundTaskRequestFactory,
        config: DigestDeliveryConfig = .default
    ) {
        self.notificationCenter = notificationCenter
        self.taskScheduler = taskScheduler
        self.storage = storage
        self.generator = generator
        self.requestFactory = requestFactory
        self.config = config

        print("📬 [DigestDelivery] Initialized (enabled: \(config.enabled), hour: \(config.deliveryHour))")
    }

    // MARK: - Public API

    /// Schedule daily digest delivery via background tasks
    /// - Throws: DigestDeliveryError if scheduling fails
    func scheduleDailyDigest() throws {
        guard config.enabled else {
            throw DigestDeliveryError.deliveryDisabled
        }

        guard let scheduler = taskScheduler else {
            print("⚠️ [DigestDelivery] Background task scheduler not available (simulator or iOS <13)")
            // Graceful degradation - no error thrown
            return
        }

        // Cancel any existing scheduled tasks
        scheduler.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)

        // Create new task request using factory
        let nextDeliveryDate = calculateNextDeliveryDate()
        let request = requestFactory.makeRequest(
            identifier: Self.backgroundTaskIdentifier,
            earliestBeginDate: nextDeliveryDate
        )

        do {
            try scheduler.submit(request)
            print("✅ [DigestDelivery] Scheduled for \(request.earliestBeginDate!)")
        } catch {
            throw DigestDeliveryError.taskSchedulingFailed(error)
        }
    }

    /// Cancel scheduled daily digest
    func cancelScheduledDigest() {
        taskScheduler?.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)
        print("🛑 [DigestDelivery] Cancelled scheduled digest")
    }

    /// Deliver digest immediately (manual trigger)
    /// - Parameters:
    ///   - days: Number of days to include in digest (default: 7)
    /// - Returns: Generated MorningDigest
    /// - Throws: DigestDeliveryError if delivery fails
    func deliverDigestNow(days: Int = 7) async throws -> MorningDigest {
        guard config.enabled else {
            throw DigestDeliveryError.deliveryDisabled
        }

        print("\n📬 [DigestDelivery] Delivering digest now...")

        // Check rate limiting
        try await checkRateLimit()

        // Request notification permission
        let authorized = try await requestNotificationPermission()
        guard authorized else {
            throw DigestDeliveryError.notificationDenied
        }

        // Generate digest
        let digest: MorningDigest
        do {
            // Fetch recent Dreamflow logs
            let logsStorage = DreamflowStorage.shared
            let logs = try await logsStorage.fetchRecent(limit: days)

            digest = try await generator.generateMorningDigest(from: logs)
            print("✅ [DigestDelivery] Generated digest: \"\(digest.headline)\"")
        } catch {
            throw DigestDeliveryError.generationFailed(error)
        }

        // Save digest
        do {
            try await storage.save(digest)
            try await storage.setLastDeliveryDate(Date())
        } catch {
            print("⚠️ [DigestDelivery] Failed to save digest: \(error)")
            // Continue with notification even if save fails
        }

        // Send notification
        do {
            try await sendNotification(for: digest)
            print("✅ [DigestDelivery] Notification sent")
        } catch {
            print("⚠️ [DigestDelivery] Failed to send notification: \(error)")
            // Don't throw - digest was still generated successfully
        }

        return digest
    }

    /// Register background task handler (call from AppDelegate)
    func registerBackgroundTask() {
        guard let scheduler = taskScheduler else { return }

        let registered = scheduler.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundTask(task)
        }

        if registered {
            print("✅ [DigestDelivery] Background task handler registered")
        } else {
            print("⚠️ [DigestDelivery] Failed to register background task handler")
        }
    }

    // MARK: - Private Methods

    /// Request notification permission from user
    private func requestNotificationPermission() async throws -> Bool {
        let settings = await notificationCenter.getNotificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true

        case .notDetermined:
            // Request permission
            return try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

        case .denied, .ephemeral:
            return false

        @unknown default:
            throw DigestDeliveryError.notificationSettingsUnavailable
        }
    }

    /// Send notification for digest
    private func sendNotification(for digest: MorningDigest) async throws {
        let content = UNMutableNotificationContent()
        content.title = config.notificationTitle
        content.categoryIdentifier = config.notificationCategory
        content.sound = .default

        // Body content
        if config.includeSummary {
            content.body = digest.asShortSummary()
        } else {
            content.body = "Your daily digest is ready to view"
        }

        // User info for deep linking
        content.userInfo = [
            "digestId": digest.id.uuidString,
            "digestDate": ISO8601DateFormatter().string(from: digest.date),
            "type": "morning_digest"
        ]

        // Create request with unique identifier
        let identifier = "digest-\(digest.id.uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        try await notificationCenter.add(request)
    }

    /// Calculate next delivery date based on config
    private func calculateNextDeliveryDate() -> Date {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = config.deliveryHour
        components.minute = 0
        components.second = 0

        guard var nextDate = calendar.date(from: components) else {
            return now.addingTimeInterval(86400) // Fallback: 24 hours from now
        }

        // If time has passed today, schedule for tomorrow
        if nextDate <= now {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
        }

        return nextDate
    }

    /// Check rate limiting for manual deliveries
    private func checkRateLimit() async throws {
        guard let lastDelivery = try await storage.getLastDeliveryDate() else {
            return // No previous delivery
        }

        let timeSinceLastDelivery = Date().timeIntervalSince(lastDelivery)
        if timeSinceLastDelivery < config.minimumDeliveryInterval {
            let nextAvailable = lastDelivery.addingTimeInterval(config.minimumDeliveryInterval)
            throw DigestDeliveryError.rateLimitExceeded(nextAvailable: nextAvailable)
        }
    }

    /// Handle background task execution
    private func handleBackgroundTask(_ task: BackgroundTaskProtocol) {
        print("\n📬 [DigestDelivery] Background task started: \(task.identifier)")

        // Set expiration handler
        task.expirationHandler = {
            print("⚠️ [DigestDelivery] Background task expired")
            task.setTaskCompleted(success: false)
        }

        // Execute delivery in async context
        Task {
            do {
                _ = try await deliverDigestNow()
                task.setTaskCompleted(success: true)

                // Schedule next run
                try? scheduleDailyDigest()

            } catch {
                print("❌ [DigestDelivery] Background delivery failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
}

// MARK: - Convenience Initializers

extension DigestDeliveryManager {
    /// Create manager with real iOS implementations
    static func makeReal(
        generator: MorningDigestGenerator,
        config: DigestDeliveryConfig = .default
    ) -> DigestDeliveryManager {
        let notificationCenter = RealNotificationCenter()

        #if canImport(BackgroundTasks)
        let taskScheduler: BackgroundTaskSchedulerProtocol?
        let requestFactory: BackgroundTaskRequestFactory
        if #available(iOS 13.0, *) {
            taskScheduler = RealBackgroundTaskScheduler()
            requestFactory = RealBackgroundTaskRequestFactory()
        } else {
            taskScheduler = nil
            requestFactory = StubBackgroundTaskRequestFactory() // Fallback for older iOS
        }
        #else
        let taskScheduler: BackgroundTaskSchedulerProtocol? = nil
        let requestFactory: BackgroundTaskRequestFactory = StubBackgroundTaskRequestFactory()
        #endif

        let storage = InMemoryDigestStorage.shared

        return DigestDeliveryManager(
            notificationCenter: notificationCenter,
            taskScheduler: taskScheduler,
            storage: storage,
            generator: generator,
            requestFactory: requestFactory,
            config: config
        )
    }
}
