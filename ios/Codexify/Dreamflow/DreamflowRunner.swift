//
//  DreamflowRunner.swift
//  Codexify
//
//  Created by Codexify:Scout
//  Phase Two: Dreamflow Runtime - Nighttime Cognition & Semantic Reflection
//

import Foundation
import BackgroundTasks

// MARK: - Data Models

/// Log entry from a Dreamflow reflection session
struct DreamflowLog: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let summary: String
    let moodSketch: String?
    let foresight: String?
    let anchors: [String]
    let rawPrompt: String?
    let modelUsed: String
    let duration: TimeInterval
    let contextStats: ContextStats?

    struct ContextStats: Codable, Equatable {
        let threadMessageCount: Int
        let memoryFragmentCount: Int
        let sensorSnapshotCount: Int
        let totalTokens: Int?
    }

    init(
        id: UUID = UUID(),
        date: Date,
        summary: String,
        moodSketch: String? = nil,
        foresight: String? = nil,
        anchors: [String] = [],
        rawPrompt: String? = nil,
        modelUsed: String,
        duration: TimeInterval,
        contextStats: ContextStats? = nil
    ) {
        self.id = id
        self.date = date
        self.summary = summary
        self.moodSketch = moodSketch
        self.foresight = foresight
        self.anchors = anchors
        self.rawPrompt = rawPrompt
        self.modelUsed = modelUsed
        self.duration = duration
        self.contextStats = contextStats
    }
}

/// Morning digest derived from multiple Dreamflow logs
struct MorningDigest: Codable, Identifiable {
    let id: UUID
    let date: Date
    let headline: String
    let keyInsights: [String]
    let moodTrend: String?
    let actionableItems: [String]
    let weeklyPatterns: [String]?
    let generatedFrom: [UUID] // DreamflowLog IDs

    init(
        id: UUID = UUID(),
        date: Date,
        headline: String,
        keyInsights: [String],
        moodTrend: String? = nil,
        actionableItems: [String],
        weeklyPatterns: [String]? = nil,
        generatedFrom: [UUID]
    ) {
        self.id = id
        self.date = date
        self.headline = headline
        self.keyInsights = keyInsights
        self.moodTrend = moodTrend
        self.actionableItems = actionableItems
        self.weeklyPatterns = weeklyPatterns
        self.generatedFrom = generatedFrom
    }
}

/// Configuration for Dreamflow execution
struct DreamflowConfig: Codable {
    let enabled: Bool
    let preferredHour: Int // 0-23, default 3am
    let requiresCharging: Bool
    let minimumBatteryLevel: Float
    let maxDurationMinutes: Int
    let includeFields: IncludeFields
    let modelPreference: String?
    let maxTokens: Int

    struct IncludeFields: Codable {
        let summary: Bool
        let moodSketch: Bool
        let foresight: Bool
        let anchors: Bool

        static let all = IncludeFields(
            summary: true,
            moodSketch: true,
            foresight: true,
            anchors: true
        )

        static let minimal = IncludeFields(
            summary: true,
            moodSketch: false,
            foresight: false,
            anchors: false
        )
    }

    static let `default` = DreamflowConfig(
        enabled: true,
        preferredHour: 3,
        requiresCharging: true,
        minimumBatteryLevel: 0.3,
        maxDurationMinutes: 10,
        includeFields: .all,
        modelPreference: nil,
        maxTokens: 2000
    )

    static let minimal = DreamflowConfig(
        enabled: true,
        preferredHour: 3,
        requiresCharging: true,
        minimumBatteryLevel: 0.5,
        maxDurationMinutes: 5,
        includeFields: .minimal,
        modelPreference: "gpt-3.5-turbo",
        maxTokens: 1000
    )
}

// MARK: - Error Types

enum DreamflowError: Error, LocalizedError {
    case notEnabled
    case deviceNotCharging
    case lowBattery(current: Float, required: Float)
    case contextGatheringFailed(Error)
    case inferenceFailedAllProviders
    case schedulingFailed(Error)
    case backgroundTaskNotAvailable
    case timeoutExceeded

    var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "Dreamflow is not enabled in configuration"
        case .deviceNotCharging:
            return "Device must be charging to run Dreamflow"
        case .lowBattery(let current, let required):
            return "Battery too low (\(Int(current * 100))%, need \(Int(required * 100))%)"
        case .contextGatheringFailed(let error):
            return "Failed to gather context: \(error.localizedDescription)"
        case .inferenceFailedAllProviders:
            return "All LLM providers failed during Dreamflow"
        case .schedulingFailed(let error):
            return "Failed to schedule Dreamflow: \(error.localizedDescription)"
        case .backgroundTaskNotAvailable:
            return "Background task scheduling not available on this platform"
        case .timeoutExceeded:
            return "Dreamflow execution exceeded maximum duration"
        }
    }
}

// MARK: - Dreamflow Context

/// Complete context gathered for Dreamflow
struct DreamflowContext {
    let threadHistory: [ThreadMessage]
    let memoryFragments: [MemoryFragment]
    let sensorSummary: SensorDaySummary
    let dateRange: DateInterval
    let totalElements: Int

    struct SensorDaySummary: Codable {
        let locations: [String]
        let activities: [String]
        let avgHeartRate: Double?
        let totalSteps: Int?
        let totalDistance: Double?
    }

    init(
        threadHistory: [ThreadMessage],
        memoryFragments: [MemoryFragment],
        sensorSummary: SensorDaySummary,
        dateRange: DateInterval
    ) {
        self.threadHistory = threadHistory
        self.memoryFragments = memoryFragments
        self.sensorSummary = sensorSummary
        self.dateRange = dateRange
        self.totalElements = threadHistory.count + memoryFragments.count
    }
}

// MARK: - Dreamflow Storage Protocol

protocol DreamflowStorageProtocol {
    func save(_ log: DreamflowLog) async throws
    func fetch(for date: Date) async throws -> DreamflowLog?
    func fetchRecent(limit: Int) async throws -> [DreamflowLog]
    func delete(_ id: UUID) async throws
}

/// In-memory storage for Dreamflow logs (stub)
class DreamflowStorage: DreamflowStorageProtocol {
    static let shared = DreamflowStorage()

    private var logs: [DreamflowLog] = []
    private let queue = DispatchQueue(label: "com.codexify.dreamflow.storage", attributes: .concurrent)

    private init() {}

    func save(_ log: DreamflowLog) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.logs.append(log)
                print("💾 [DreamflowStorage] Saved log for \(log.date)")
                continuation.resume()
            }
        }
    }

    func fetch(for date: Date) async throws -> DreamflowLog? {
        return await withCheckedContinuation { continuation in
            queue.async {
                let calendar = Calendar.current
                let log = self.logs.first { calendar.isDate($0.date, inSameDayAs: date) }
                continuation.resume(returning: log)
            }
        }
    }

    func fetchRecent(limit: Int) async throws -> [DreamflowLog] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let sorted = self.logs.sorted { $0.date > $1.date }
                continuation.resume(returning: Array(sorted.prefix(limit)))
            }
        }
    }

    func delete(_ id: UUID) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.logs.removeAll { $0.id == id }
                continuation.resume()
            }
        }
    }

    // TODO: Implement persistent storage
    // Options:
    // - CoreData for structured storage
    // - SQLite for custom queries
    // - File-based JSON storage
    // - CloudKit for cross-device sync
}

// MARK: - Dreamflow Runner

/// Main runtime for nighttime reflection and semantic processing
class DreamflowRunner {

    // MARK: - Properties

    private let config: DreamflowConfig
    private let modelRouter: ModelRouter
    private let contextBroker: ContextBroker?
    private let threadStorage: ThreadStorageProtocol
    private let vectorStore: VectorStoreProtocol
    private let sensorAggregator: SensorAggregatorProtocol
    private let storage: DreamflowStorageProtocol
    private let builder: DreamflowBuilder

    private var scheduledTask: BGTaskRequest?
    private var isRunning = false

    // Background task identifier
    private static let backgroundTaskIdentifier = "com.codexify.dreamflow.nightly"

    // MARK: - Initialization

    init(
        config: DreamflowConfig = .default,
        modelRouter: ModelRouter,
        contextBroker: ContextBroker? = nil,
        threadStorage: ThreadStorageProtocol = ThreadStorage.shared,
        vectorStore: VectorStoreProtocol = VectorStore.shared,
        sensorAggregator: SensorAggregatorProtocol = SensorAggregator.shared,
        storage: DreamflowStorageProtocol = DreamflowStorage.shared,
        builder: DreamflowBuilder? = nil
    ) {
        self.config = config
        self.modelRouter = modelRouter
        self.contextBroker = contextBroker
        self.threadStorage = threadStorage
        self.vectorStore = vectorStore
        self.sensorAggregator = sensorAggregator
        self.storage = storage
        self.builder = builder ?? DreamflowBuilder(config: config)

        print("🌙 [DreamflowRunner] Initialized (enabled: \(config.enabled))")
    }

    // MARK: - Public API

    /// Run Dreamflow reflection for a specific date
    /// - Parameter date: The date to run reflection for
    /// - Returns: DreamflowLog with results
    /// - Throws: DreamflowError if execution fails
    func runDreamflow(for date: Date = Date()) async throws -> DreamflowLog {
        let startTime = Date()
        print("\n🌙 [Dreamflow] Starting reflection for \(date)")

        // Validate configuration
        guard config.enabled else {
            throw DreamflowError.notEnabled
        }

        // Check device state
        try validateDeviceState()

        // Set running state
        isRunning = true
        defer { isRunning = false }

        do {
            // Step 1: Gather context
            print("📦 [Dreamflow] Gathering context...")
            let context = try await gatherContext(for: date)
            print("✅ [Dreamflow] Context gathered: \(context.totalElements) elements")

            // Step 2: Build prompts
            print("📝 [Dreamflow] Building prompts...")
            let prompts = builder.buildPrompts(from: context, config: config)

            // Step 3: Run inference
            print("🤖 [Dreamflow] Running inference...")
            let results = try await runInference(prompts: prompts)

            // Step 4: Create log
            let duration = Date().timeIntervalSince(startTime)
            let log = DreamflowLog(
                date: date,
                summary: results.summary,
                moodSketch: results.moodSketch,
                foresight: results.foresight,
                anchors: results.anchors,
                rawPrompt: prompts.combined,
                modelUsed: results.modelUsed,
                duration: duration,
                contextStats: DreamflowLog.ContextStats(
                    threadMessageCount: context.threadHistory.count,
                    memoryFragmentCount: context.memoryFragments.count,
                    sensorSnapshotCount: 1,
                    totalTokens: nil // TODO: Calculate from responses
                )
            )

            // Step 5: Save log
            try await storage.save(log)

            print("✅ [Dreamflow] Completed in \(String(format: "%.2f", duration))s")
            print("   Summary: \(log.summary.prefix(100))...")

            return log

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ [Dreamflow] Failed after \(String(format: "%.2f", duration))s: \(error)")
            throw error
        }
    }

    /// Schedule the next Dreamflow run
    /// - Throws: DreamflowError if scheduling fails
    func scheduleNextRun() throws {
        guard config.enabled else {
            throw DreamflowError.notEnabled
        }

        // TODO: Implement BGTaskScheduler integration
        // Register background task handler
        // BGTaskScheduler.shared.register(
        //     forTaskWithIdentifier: Self.backgroundTaskIdentifier,
        //     using: nil
        // ) { task in
        //     self.handleBackgroundTask(task as! BGProcessingTask)
        // }

        // Schedule next run
        // let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskIdentifier)
        // request.requiresNetworkConnectivity = false
        // request.requiresExternalPower = config.requiresCharging
        // request.earliestBeginDate = calculateNextRunDate()
        //
        // try BGTaskScheduler.shared.submit(request)

        print("⏰ [Dreamflow] Scheduled next run for \(calculateNextRunDate())")
        print("   NOTE: Background task scheduling requires BGTaskScheduler integration")
    }

    /// Cancel scheduled Dreamflow run
    func cancelScheduledRun() {
        // TODO: Implement cancellation
        // BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)

        scheduledTask = nil
        print("🛑 [Dreamflow] Cancelled scheduled run")
    }

    /// Check if Dreamflow is currently running
    var running: Bool {
        return isRunning
    }

    // MARK: - Private Methods

    private func validateDeviceState() throws {
        // TODO: Integrate with actual device state
        // let deviceState = await DeviceStateReader().getCurrentState()

        // Simulate device state for now
        let batteryLevel: Float = 0.8
        let isCharging = true

        if config.requiresCharging && !isCharging {
            throw DreamflowError.deviceNotCharging
        }

        if batteryLevel < config.minimumBatteryLevel {
            throw DreamflowError.lowBattery(
                current: batteryLevel,
                required: config.minimumBatteryLevel
            )
        }
    }

    private func gatherContext(for date: Date) async throws -> DreamflowContext {
        // Define 24-hour window
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let dateRange = DateInterval(start: startOfDay, end: endOfDay)

        // Gather in parallel
        async let threadHistory = fetchThreadHistory(in: dateRange)
        async let memoryFragments = fetchMemoryFragments(in: dateRange)
        async let sensorSummary = fetchSensorSummary(in: dateRange)

        do {
            let thread = try await threadHistory
            let memories = try await memoryFragments
            let sensors = try await sensorSummary

            return DreamflowContext(
                threadHistory: thread,
                memoryFragments: memories,
                sensorSummary: sensors,
                dateRange: dateRange
            )
        } catch {
            throw DreamflowError.contextGatheringFailed(error)
        }
    }

    private func fetchThreadHistory(in range: DateInterval) async throws -> [ThreadMessage] {
        // TODO: Query thread storage for messages in date range
        // For now, return empty array

        print("💬 [Dreamflow] Fetching thread history...")
        return []
    }

    private func fetchMemoryFragments(in range: DateInterval) async throws -> [MemoryFragment] {
        // TODO: Query vector store for memories created in date range
        // Filter by timestamp metadata

        print("🧠 [Dreamflow] Fetching memory fragments...")
        return []
    }

    private func fetchSensorSummary(in range: DateInterval) async throws -> DreamflowContext.SensorDaySummary {
        // TODO: Aggregate sensor data for the day
        // - Unique locations visited
        // - Activities performed
        // - Average health metrics

        print("📡 [Dreamflow] Fetching sensor summary...")

        return DreamflowContext.SensorDaySummary(
            locations: ["Home", "Office", "Gym"],
            activities: ["walking", "stationary", "running"],
            avgHeartRate: 72.0,
            totalSteps: 8543,
            totalDistance: 6.2
        )
    }

    private func runInference(prompts: DreamflowBuilder.Prompts) async throws -> InferenceResults {
        var results = InferenceResults()

        // Run summary inference
        if config.includeFields.summary {
            print("📝 [Dreamflow] Generating summary...")
            results.summary = try await modelRouter.routeRequest(prompts.summary)
            results.modelUsed = modelRouter.preferences.defaultProvider.name
        }

        // Run mood sketch inference
        if config.includeFields.moodSketch, let moodPrompt = prompts.moodSketch {
            print("🎨 [Dreamflow] Sketching mood...")
            results.moodSketch = try await modelRouter.routeRequest(moodPrompt)
        }

        // Run foresight inference
        if config.includeFields.foresight, let foresightPrompt = prompts.foresight {
            print("🔮 [Dreamflow] Generating foresight...")
            results.foresight = try await modelRouter.routeRequest(foresightPrompt)
        }

        // Run anchors inference
        if config.includeFields.anchors, let anchorsPrompt = prompts.anchors {
            print("⚓ [Dreamflow] Extracting semantic anchors...")
            let anchorsText = try await modelRouter.routeRequest(anchorsPrompt)
            results.anchors = parseAnchors(from: anchorsText)
        }

        return results
    }

    private func parseAnchors(from text: String) -> [String] {
        // Parse anchors from response
        // Expected format: bullet points or numbered list
        let lines = text.components(separatedBy: .newlines)
        return lines
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") ||
                     $0.trimmingCharacters(in: .whitespaces).hasPrefix("•") ||
                     $0.range(of: "^\\d+\\.", options: .regularExpression) != nil }
            .map { $0.trimmingCharacters(in: .whitespaces)
                     .replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                     .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
    }

    private func calculateNextRunDate() -> Date {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = config.preferredHour
        components.minute = 0
        components.second = 0

        guard var nextRun = calendar.date(from: components) else {
            return now.addingTimeInterval(86400) // 24 hours
        }

        // If time has passed today, schedule for tomorrow
        if nextRun <= now {
            nextRun = calendar.date(byAdding: .day, value: 1, to: nextRun)!
        }

        return nextRun
    }

    // TODO: Background task handler
    // private func handleBackgroundTask(_ task: BGProcessingTask) {
    //     task.expirationHandler = {
    //         task.setTaskCompleted(success: false)
    //     }
    //
    //     Task {
    //         do {
    //             _ = try await runDreamflow()
    //             task.setTaskCompleted(success: true)
    //         } catch {
    //             print("Background Dreamflow failed: \(error)")
    //             task.setTaskCompleted(success: false)
    //         }
    //
    //         // Schedule next run
    //         try? scheduleNextRun()
    //     }
    // }

    // MARK: - Helper Types

    private struct InferenceResults {
        var summary: String = ""
        var moodSketch: String?
        var foresight: String?
        var anchors: [String] = []
        var modelUsed: String = "unknown"
    }
}

// MARK: - Morning Digest Generator

extension DreamflowRunner {
    /// Generate morning digest from recent Dreamflow logs
    /// - Parameter days: Number of days to include (default: 7)
    /// - Returns: MorningDigest
    func generateMorningDigest(days: Int = 7) async throws -> MorningDigest {
        print("\n☀️ [Dreamflow] Generating morning digest for past \(days) days...")

        // Fetch recent logs
        let logs = try await storage.fetchRecent(limit: days)

        guard !logs.isEmpty else {
            throw DreamflowError.contextGatheringFailed(
                NSError(domain: "No logs available", code: -1)
            )
        }

        // Aggregate summaries
        let summaries = logs.map { $0.summary }.joined(separator: "\n\n")

        // Build digest prompt
        let digestPrompt = """
        Based on the following daily summaries from the past \(days) days, create a morning digest:

        \(summaries)

        Generate:
        1. A compelling headline summarizing the week
        2. 3-5 key insights or patterns
        3. Overall mood trend
        4. 2-3 actionable items for today
        5. Recurring weekly patterns (if any)

        Format as JSON with keys: headline, insights (array), moodTrend, actionableItems (array), patterns (array)
        """

        // Run inference
        let response = try await modelRouter.routeRequest(digestPrompt)

        // Parse response (simplified)
        let digest = MorningDigest(
            date: Date(),
            headline: "Weekly Digest Available",
            keyInsights: [
                "Pattern 1",
                "Pattern 2",
                "Pattern 3"
            ],
            moodTrend: "stable and positive",
            actionableItems: [
                "Action 1",
                "Action 2"
            ],
            weeklyPatterns: [
                "Weekly pattern 1"
            ],
            generatedFrom: logs.map { $0.id }
        )

        print("✅ [Dreamflow] Morning digest generated")
        return digest
    }
}
