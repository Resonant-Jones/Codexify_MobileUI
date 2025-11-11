//
//  DigestDelivery.swift
//  Codexify
//
//  Created by Codexify:Scout
//  Phase Two: Dreamflow Runtime - Digest Delivery & Notification System
//
//  Delivers MorningDigest insights through local notifications, sharing, and CloudKit sync
//

import Foundation
import UserNotifications
import BackgroundTasks

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Notification Identifiers

/// Identifiers for different notification types
enum DigestNotificationIdentifier: String {
    case morningDigest = "com.codexify.digest.morning"
    case manualDigest = "com.codexify.digest.manual"
    case silentSync = "com.codexify.digest.silent"

    var categoryIdentifier: String {
        return "\(rawValue).category"
    }
}

// MARK: - Delivery Configuration

/// Configuration for digest delivery
struct DigestDeliveryConfig {
    let preferredNotificationTime: DateComponents
    let enableRichNotifications: Bool
    let enableHapticFeedback: Bool
    let maxInsightsInNotification: Int
    let enableCloudKitSync: Bool

    static let `default` = DigestDeliveryConfig(
        preferredNotificationTime: DateComponents(hour: 7, minute: 0), // 7 AM
        enableRichNotifications: true,
        enableHapticFeedback: true,
        maxInsightsInNotification: 2,
        enableCloudKitSync: false // Future feature
    )
}

// MARK: - Delivery Errors

enum DigestDeliveryError: Error, LocalizedError {
    case notificationPermissionDenied
    case notificationSchedulingFailed(Error)
    case exportFailed(Error)
    case noViewControllerAvailable

    var errorDescription: String? {
        switch self {
        case .notificationPermissionDenied:
            return "Notification permission denied. Enable in Settings."
        case .notificationSchedulingFailed(let error):
            return "Failed to schedule notification: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Failed to export digest: \(error.localizedDescription)"
        case .noViewControllerAvailable:
            return "No view controller available for presenting share sheet"
        }
    }
}

// MARK: - Digest Delivery

/// Main delivery system for MorningDigest notifications and sharing
class DigestDelivery: NSObject, UNUserNotificationCenterDelegate {

    // MARK: - Properties

    private let config: DigestDeliveryConfig
    private let notificationCenter: UNUserNotificationCenter
    private var permissionGranted: Bool = false
    private var isInitialized: Bool = false

    // Background task identifier
    private static let backgroundSyncTaskIdentifier = "com.codexify.digest.sync"

    // MARK: - Singleton

    static let shared = DigestDelivery()

    // MARK: - Initialization

    /// Initialize with custom configuration
    /// - Parameter config: DigestDeliveryConfig (default: .default)
    init(config: DigestDeliveryConfig = .default) {
        self.config = config
        self.notificationCenter = UNUserNotificationCenter.current()

        super.init()

        // Set delegate
        notificationCenter.delegate = self

        // Register notification categories
        registerNotificationCategories()

        print("📬 [DigestDelivery] Initialized")
    }

    // MARK: - Public API - Notifications

    /// Request notification permission from user
    /// - Returns: True if permission granted, false otherwise
    @discardableResult
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            permissionGranted = granted

            if granted {
                print("✅ [DigestDelivery] Notification permission granted")
            } else {
                print("⚠️ [DigestDelivery] Notification permission denied")
            }

            return granted

        } catch {
            print("❌ [DigestDelivery] Permission request failed: \(error)")
            return false
        }
    }

    /// Check current notification authorization status
    /// - Returns: True if authorized, false otherwise
    func checkNotificationPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        let granted = settings.authorizationStatus == .authorized
        permissionGranted = granted
        return granted
    }

    /// Schedule a notification for a MorningDigest
    /// - Parameter digest: The MorningDigest to schedule notification for
    /// - Throws: DigestDeliveryError if scheduling fails
    func scheduleNotification(for digest: MorningDigest) async throws {
        print("\n📅 [DigestDelivery] Scheduling notification for digest: \(digest.headline)")

        // Check permission
        guard await checkNotificationPermission() else {
            throw DigestDeliveryError.notificationPermissionDenied
        }

        // Create notification content
        let content = createNotificationContent(for: digest)

        // Create trigger for next morning
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: config.preferredNotificationTime,
            repeats: false
        )

        // Create request
        let request = UNNotificationRequest(
            identifier: DigestNotificationIdentifier.morningDigest.rawValue,
            content: content,
            trigger: trigger
        )

        // Schedule
        do {
            try await notificationCenter.add(request)
            print("✅ [DigestDelivery] Notification scheduled for \(formatNotificationTime())")
        } catch {
            print("❌ [DigestDelivery] Failed to schedule notification: \(error)")
            throw DigestDeliveryError.notificationSchedulingFailed(error)
        }
    }

    /// Send notification immediately (for manual digest generation)
    /// - Parameter digest: The MorningDigest to send
    func sendNow(digest: MorningDigest) {
        print("\n📨 [DigestDelivery] Sending immediate notification...")

        Task {
            // Check permission
            guard await checkNotificationPermission() else {
                print("⚠️ [DigestDelivery] Cannot send - permission denied")
                return
            }

            // Create notification content
            let content = createNotificationContent(for: digest)

            // Create immediate trigger (1 second delay)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            // Create request
            let request = UNNotificationRequest(
                identifier: DigestNotificationIdentifier.manualDigest.rawValue,
                content: content,
                trigger: trigger
            )

            // Send
            do {
                try await notificationCenter.add(request)
                print("✅ [DigestDelivery] Immediate notification sent")

                // Haptic feedback
                if config.enableHapticFeedback {
                    performHaptic(.success)
                }
            } catch {
                print("❌ [DigestDelivery] Failed to send notification: \(error)")
            }
        }
    }

    /// Cancel all scheduled digest notifications
    func cancelScheduledNotifications() {
        let identifiers = [
            DigestNotificationIdentifier.morningDigest.rawValue,
            DigestNotificationIdentifier.manualDigest.rawValue
        ]

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🛑 [DigestDelivery] Cancelled \(identifiers.count) scheduled notifications")
    }

    /// Cancel a specific notification
    /// - Parameter identifier: The notification identifier to cancel
    func cancelNotification(_ identifier: DigestNotificationIdentifier) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier.rawValue])
        print("🛑 [DigestDelivery] Cancelled notification: \(identifier.rawValue)")
    }

    // MARK: - Public API - Export & Sharing

    /// Share digest via UIActivityViewController
    /// - Parameters:
    ///   - digest: The MorningDigest to share
    ///   - viewController: The presenting view controller
    ///   - sourceView: Optional source view for iPad popover
    func shareDigest(
        _ digest: MorningDigest,
        from viewController: UIViewController,
        sourceView: UIView? = nil
    ) {
        #if canImport(UIKit)
        print("📤 [DigestDelivery] Preparing to share digest...")

        // Create share items
        let textToShare = digest.asPlainText()
        let markdownToShare = digest.asMarkdown()

        // Create activity items
        var items: [Any] = [textToShare]

        // Add markdown as file attachment
        if let markdownData = markdownToShare.data(using: .utf8) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("MorningDigest-\(formatDateForFile(digest.date)).md")

            do {
                try markdownData.write(to: tempURL)
                items.append(tempURL)
                print("📄 [DigestDelivery] Created markdown file: \(tempURL.lastPathComponent)")
            } catch {
                print("⚠️ [DigestDelivery] Failed to create markdown file: \(error)")
            }
        }

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                           y: viewController.view.bounds.midY,
                                           width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }

        // Completion handler
        activityVC.completionWithItemsHandler = { activityType, completed, _, error in
            if completed {
                print("✅ [DigestDelivery] Successfully shared via \(activityType?.rawValue ?? "unknown")")

                if self.config.enableHapticFeedback {
                    self.performHaptic(.success)
                }
            } else if let error = error {
                print("❌ [DigestDelivery] Share failed: \(error)")
            }
        }

        // Present
        viewController.present(activityVC, animated: true) {
            if self.config.enableHapticFeedback {
                self.performHaptic(.light)
            }
        }
        #else
        print("⚠️ [DigestDelivery] Sharing not available on this platform")
        #endif
    }

    /// Export digest as markdown file
    /// - Parameters:
    ///   - digest: The MorningDigest to export
    ///   - destinationURL: Optional destination URL (default: Documents directory)
    /// - Returns: URL of exported file
    /// - Throws: DigestDeliveryError if export fails
    @discardableResult
    func exportAsMarkdown(
        _ digest: MorningDigest,
        to destinationURL: URL? = nil
    ) async throws -> URL {
        print("💾 [DigestDelivery] Exporting digest as markdown...")

        let markdown = digest.asMarkdown()

        guard let data = markdown.data(using: .utf8) else {
            throw DigestDeliveryError.exportFailed(
                NSError(domain: "Cannot encode markdown", code: -1)
            )
        }

        // Determine destination
        let fileURL: URL
        if let destinationURL = destinationURL {
            fileURL = destinationURL
        } else {
            // Default to Documents directory
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            fileURL = documentsDir.appendingPathComponent("MorningDigest-\(formatDateForFile(digest.date)).md")
        }

        // Write file
        do {
            try data.write(to: fileURL)
            print("✅ [DigestDelivery] Exported to: \(fileURL.path)")

            // Haptic feedback
            if config.enableHapticFeedback {
                performHaptic(.success)
            }

            return fileURL
        } catch {
            print("❌ [DigestDelivery] Export failed: \(error)")
            throw DigestDeliveryError.exportFailed(error)
        }
    }

    // MARK: - Background Refresh (Stub)

    /// Register background task for silent digest delivery and CloudKit sync
    /// - Note: This is a stub for future CloudKit integration
    func registerBackgroundTasks() {
        #if !os(watchOS) && !os(tvOS)
        // TODO: Implement BGTaskScheduler integration
        // This would handle:
        // 1. Silent digest generation in background
        // 2. CloudKit sync for cross-device digest delivery
        // 3. Digest pre-caching for faster morning load

        /*
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundSyncTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundSync(task as! BGProcessingTask)
        }
        */

        print("🔄 [DigestDelivery] Background task registration (stub)")
        print("   NOTE: Implement BGTaskScheduler for production use")
        #endif
    }

    /// Schedule next background sync task
    /// - Note: This is a stub for future CloudKit integration
    func scheduleBackgroundSync() {
        #if !os(watchOS) && !os(tvOS)
        // TODO: Schedule BGProcessingTask

        /*
        let request = BGProcessingTaskRequest(identifier: Self.backgroundSyncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1 hour from now

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ [DigestDelivery] Background sync scheduled")
        } catch {
            print("❌ [DigestDelivery] Failed to schedule background sync: \(error)")
        }
        */

        print("🔄 [DigestDelivery] Background sync scheduling (stub)")
        #endif
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📬 [DigestDelivery] Notification received in foreground")

        // Show banner even when app is open
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("👆 [DigestDelivery] Notification tapped: \(response.actionIdentifier)")

        let userInfo = response.notification.request.content.userInfo

        // Handle different actions
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification - open digest view
            handleOpenDigest(userInfo: userInfo)

        case "SHARE_ACTION":
            // User tapped share action
            handleShareAction(userInfo: userInfo)

        case "DISMISS_ACTION":
            // User dismissed
            print("🔕 [DigestDelivery] Notification dismissed")

        default:
            break
        }

        completionHandler()
    }

    // MARK: - Private Helpers - Notifications

    private func createNotificationContent(for digest: MorningDigest) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        // Title with emoji
        content.title = "🌅 Your Morning Digest is Ready"

        // Body with headline and first insight
        var body = "\"\(digest.headline)\""

        if let mood = digest.moodTrend {
            body += "\n🟢 Mood: \(mood)"
        }

        if !digest.keyInsights.isEmpty {
            let insightCount = min(config.maxInsightsInNotification, digest.keyInsights.count)
            let insights = digest.keyInsights.prefix(insightCount)
            body += "\n💡 Insights: \(insights.count)"

            if config.enableRichNotifications {
                for (index, insight) in insights.enumerated() {
                    body += "\n  \(index + 1). \(insight.prefix(60))\(insight.count > 60 ? "..." : "")"
                }
            }
        }

        content.body = body

        // Sound
        content.sound = .default

        // Badge
        content.badge = 1

        // Category for actions
        content.categoryIdentifier = DigestNotificationIdentifier.morningDigest.categoryIdentifier

        // User info (for deep linking)
        content.userInfo = [
            "digestId": digest.id.uuidString,
            "digestDate": ISO8601DateFormatter().string(from: digest.date)
        ]

        // Thread identifier (for grouping)
        content.threadIdentifier = "morning-digest"

        return content
    }

    private func registerNotificationCategories() {
        // Define actions
        let shareAction = UNNotificationAction(
            identifier: "SHARE_ACTION",
            title: "Share",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: [.destructive]
        )

        // Create category
        let category = UNNotificationCategory(
            identifier: DigestNotificationIdentifier.morningDigest.categoryIdentifier,
            actions: [shareAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Register
        notificationCenter.setNotificationCategories([category])
        print("📋 [DigestDelivery] Registered notification categories")
    }

    private func handleOpenDigest(userInfo: [AnyHashable: Any]) {
        guard let digestId = userInfo["digestId"] as? String else {
            print("⚠️ [DigestDelivery] No digestId in notification")
            return
        }

        print("📖 [DigestDelivery] Opening digest: \(digestId)")

        // TODO: Post notification for app to handle navigation
        // NotificationCenter.default.post(
        //     name: .openDigestNotification,
        //     object: nil,
        //     userInfo: ["digestId": digestId]
        // )

        // Haptic feedback
        if config.enableHapticFeedback {
            performHaptic(.medium)
        }
    }

    private func handleShareAction(userInfo: [AnyHashable: Any]) {
        guard let digestId = userInfo["digestId"] as? String else {
            print("⚠️ [DigestDelivery] No digestId in notification")
            return
        }

        print("📤 [DigestDelivery] Share action for digest: \(digestId)")

        // TODO: Fetch digest and present share sheet
        // This would require retrieving the digest from storage
        // and presenting the share UI
    }

    // MARK: - Private Helpers - Background Tasks

    /*
    private func handleBackgroundSync(_ task: BGProcessingTask) {
        print("🔄 [DigestDelivery] Handling background sync task")

        task.expirationHandler = {
            print("⏱️ [DigestDelivery] Background task expired")
            task.setTaskCompleted(success: false)
        }

        Task {
            do {
                // 1. Generate digest if needed
                // 2. Sync to CloudKit
                // 3. Schedule notification

                // Placeholder implementation
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                print("✅ [DigestDelivery] Background sync completed")
                task.setTaskCompleted(success: true)

                // Schedule next sync
                scheduleBackgroundSync()

            } catch {
                print("❌ [DigestDelivery] Background sync failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    */

    // MARK: - Private Helpers - Utilities

    private func performHaptic(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(style)
        #endif
    }

    private func performHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    private func formatNotificationTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        var components = config.preferredNotificationTime
        components.timeZone = Calendar.current.timeZone

        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }

        return "7:00 AM"
    }

    private func formatDateForFile(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Integration Extensions

extension DigestDelivery {

    /// Complete delivery flow after Dreamflow completion
    /// - Parameters:
    ///   - digest: The generated MorningDigest
    ///   - immediate: Whether to send notification immediately (default: false)
    func deliverAfterDreamflow(_ digest: MorningDigest, immediate: Bool = false) async {
        print("\n📬 [DigestDelivery] Starting delivery flow...")

        // Check permission first
        let hasPermission = await checkNotificationPermission()

        if !hasPermission {
            print("⚠️ [DigestDelivery] No notification permission - requesting...")
            await requestNotificationPermission()
        }

        // Deliver notification
        if immediate {
            sendNow(digest)
        } else {
            do {
                try await scheduleNotification(for: digest)
            } catch {
                print("❌ [DigestDelivery] Failed to schedule notification: \(error)")
            }
        }

        // Schedule background sync if enabled
        if config.enableCloudKitSync {
            scheduleBackgroundSync()
        }

        print("✅ [DigestDelivery] Delivery flow completed")
    }
}

// MARK: - Notification Name Extensions

extension Notification.Name {
    /// Posted when user taps to open a digest from notification
    static let openDigestNotification = Notification.Name("com.codexify.openDigest")
}

// MARK: - Preview Helpers

#if DEBUG
extension DigestDelivery {
    /// Send a test notification (development only)
    func sendTestNotification() {
        let testDigest = MorningDigest(
            date: Date(),
            headline: "Test notification from Codexify",
            keyInsights: [
                "This is a test insight",
                "Notifications are working correctly"
            ],
            moodTrend: "testing and functional",
            actionableItems: [
                "Verify notification appearance",
                "Test notification actions"
            ],
            weeklyPatterns: nil,
            generatedFrom: []
        )

        sendNow(digest: testDigest)
    }
}
#endif
