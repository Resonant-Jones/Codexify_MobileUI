# Dreamflow - Nighttime Cognition & Semantic Reflection

🌙 **Phase Two: Codexify:Scout**

A sovereign mobile-first AI system that performs nighttime reflection, generating daily summaries, mood sketches, predictive foresight, and semantic anchors from accumulated context.

## Overview

Dreamflow runs during device idle time (typically overnight while charging) to:
- **Digest** the day's conversations, memories, and activities
- **Reflect** on patterns, themes, and insights
- **Forecast** potential outcomes based on observed trends
- **Anchor** recurring concepts for long-term memory

All processing happens **on-device** using your chosen LLM provider, with results stored locally for morning review.

## Architecture

```
Dreamflow
├── DreamflowRunner        # Main runtime & scheduling
├── DreamflowBuilder       # Modular prompt construction
├── DreamflowLog           # Daily reflection results
├── MorningDigest          # Weekly aggregation
├── DreamflowStorage       # Persistent log storage
└── Connector Hooks        # Phase-aware integrations
```

## Features

✅ **Nighttime Cognition**
- Scheduled execution (default: 3am)
- Requires device charging
- Battery-level awareness
- Configurable duration limits

✅ **Context Gathering**
- Past 24h thread history
- Day's memory fragments
- Sensor activity summary
- Location and health data

✅ **Multi-Faceted Reflection**
- Daily Summary (what happened)
- Mood Sketch (emotional tone)
- Foresight (trend predictions)
- Semantic Anchors (recurring themes)

✅ **Privacy-First**
- All inference on-device or user's LLM
- No external telemetry
- Local storage only
- User controls all data

✅ **Extensible**
- Connector hooks for email, calendar, social
- Customizable prompt templates
- Configurable inference fields
- Morning digest generation

## Quick Start

### 1. Basic Usage

```swift
import Foundation

// Initialize Dreamflow
let router = ModelRouter(preferences: .defaultConfiguration())
let dreamflow = DreamflowRunner(
    config: .default,
    modelRouter: router
)

// Run reflection for today
Task {
    do {
        let log = try await dreamflow.runDreamflow(for: Date())

        print("Summary: \(log.summary)")
        print("Mood: \(log.moodSketch ?? "N/A")")
        print("Anchors: \(log.anchors.joined(separator: ", "))")
        print("Duration: \(log.duration)s")

    } catch {
        print("Dreamflow failed: \(error)")
    }
}
```

### 2. Schedule Nightly Execution

```swift
// Schedule automatic nightly run
try dreamflow.scheduleNextRun()

// The system will run at 3am (configurable) when:
// - Device is charging
// - Battery > 30%
// - User is likely asleep
```

### 3. Custom Configuration

```swift
let customConfig = DreamflowConfig(
    enabled: true,
    preferredHour: 4,           // 4am
    requiresCharging: true,
    minimumBatteryLevel: 0.5,   // 50%
    maxDurationMinutes: 5,
    includeFields: .minimal,     // Summary only
    modelPreference: "gpt-3.5-turbo",
    maxTokens: 1000
)

let customDreamflow = DreamflowRunner(
    config: customConfig,
    modelRouter: router
)
```

### 4. Generate Morning Digest

```swift
// Aggregate past week into digestTask {
    let digest = try await dreamflow.generateMorningDigest(days: 7)

    print("Headline: \(digest.headline)")
    print("Key Insights:")
    for insight in digest.keyInsights {
        print("  - \(insight)")
    }

    print("\nActionable Items:")
    for item in digest.actionableItems {
        print("  • \(item)")
    }
}
```

## Data Models

### DreamflowLog

Complete reflection results for a single day.

```swift
struct DreamflowLog {
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
}
```

### MorningDigest

Weekly aggregation of insights.

```swift
struct MorningDigest {
    let id: UUID
    let date: Date
    let headline: String
    let keyInsights: [String]
    let moodTrend: String?
    let actionableItems: [String]
    let weeklyPatterns: [String]?
    let generatedFrom: [UUID]  // DreamflowLog IDs
}
```

### DreamflowConfig

Execution configuration.

```swift
struct DreamflowConfig {
    let enabled: Bool
    let preferredHour: Int        // 0-23
    let requiresCharging: Bool
    let minimumBatteryLevel: Float
    let maxDurationMinutes: Int
    let includeFields: IncludeFields
    let modelPreference: String?
    let maxTokens: Int
}
```

## API Reference

### DreamflowRunner

#### `runDreamflow(for date: Date) async throws -> DreamflowLog`

Execute reflection for a specific date.

**Parameters:**
- `date`: Date to reflect on (default: today)

**Returns:** `DreamflowLog` with complete results

**Throws:** `DreamflowError` if execution fails

**Example:**
```swift
let log = try await dreamflow.runDreamflow(for: Date())
```

#### `scheduleNextRun() throws`

Schedule the next automatic Dreamflow execution.

**Throws:** `DreamflowError` if scheduling fails

**Example:**
```swift
try dreamflow.scheduleNextRun()
```

#### `cancelScheduledRun()`

Cancel pending scheduled execution.

**Example:**
```swift
dreamflow.cancelScheduledRun()
```

#### `generateMorningDigest(days: Int) async throws -> MorningDigest`

Create weekly digest from recent logs.

**Parameters:**
- `days`: Number of days to include (default: 7)

**Returns:** `MorningDigest` with aggregated insights

### DreamflowBuilder

#### `buildPrompts(from:config:) -> Prompts`

Generate prompts for LLM inference.

**Parameters:**
- `context`: DreamflowContext with day's data
- `config`: DreamflowConfig for field selection

**Returns:** Prompts structure with formatted text

## Configuration Options

### Preset Configurations

**Default (Comprehensive)**
```swift
DreamflowConfig.default
// - All fields enabled
// - 3am execution
// - Requires charging
// - 30% minimum battery
// - 10 minute max duration
```

**Minimal (Fast)**
```swift
DreamflowConfig.minimal
// - Summary only
// - 3am execution
// - Requires charging
// - 50% minimum battery
// - 5 minute max duration
```

### Field Selection

```swift
DreamflowConfig.IncludeFields(
    summary: true,      // Daily summary (required)
    moodSketch: true,   // Emotional tone
    foresight: true,    // Predictive insights
    anchors: true       // Semantic themes
)
```

## Integration TODOs

### 1. Background Task Scheduling

**Location:** `DreamflowRunner.swift:320`

```swift
import BackgroundTasks

// Register task identifier in Info.plist
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.codexify.dreamflow.nightly</string>
</array>

// Register handler in AppDelegate
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.codexify.dreamflow.nightly",
        using: nil
    ) { task in
        self.handleDreamflowTask(task as! BGProcessingTask)
    }

    return true
}

// Handle background task
func handleDreamflowTask(_ task: BGProcessingTask) {
    task.expirationHandler = {
        task.setTaskCompleted(success: false)
    }

    Task {
        do {
            _ = try await dreamflowRunner.runDreamflow()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }

        try? dreamflowRunner.scheduleNextRun()
    }
}

// Schedule next run
func scheduleNextRun() throws {
    let request = BGProcessingTaskRequest(
        identifier: "com.codexify.dreamflow.nightly"
    )

    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = config.requiresCharging
    request.earliestBeginDate = calculateNextRunDate()

    try BGTaskScheduler.shared.submit(request)
}
```

### 2. Persistent Storage

**Location:** `DreamflowRunner.swift:151`

**Option A: CoreData**
```swift
import CoreData

class CoreDataDreamflowStorage: DreamflowStorageProtocol {
    let container: NSPersistentContainer

    func save(_ log: DreamflowLog) async throws {
        let context = container.newBackgroundContext()

        try await context.perform {
            let entity = DreamflowLogEntity(context: context)
            entity.id = log.id
            entity.date = log.date
            entity.summary = log.summary
            entity.moodSketch = log.moodSketch
            // ... map all fields

            try context.save()
        }
    }
}
```

**Option B: SQLite**
```swift
import SQLite

class SQLiteDreamflowStorage: DreamflowStorageProtocol {
    let db: Connection

    func save(_ log: DreamflowLog) async throws {
        let logs = Table("dreamflow_logs")

        let insert = logs.insert(
            idColumn <- log.id,
            dateColumn <- log.date,
            summaryColumn <- log.summary
            // ... other columns
        )

        try db.run(insert)
    }
}
```

### 3. Connector Implementations

**Email Connector**
```swift
import MessageUI

class EmailConnector: DreamflowConnectorProtocol {
    func provideContext(for date: Date) async throws -> [String: Any] {
        // Fetch email stats for the day
        let unreadCount = try await fetchUnreadCount(for: date)
        let important = try await fetchImportantThreads(for: date)

        return [
            "emailUnreadCount": unreadCount,
            "importantThreads": important.map { $0.subject }
        ]
    }

    func afterDreamflow(log: DreamflowLog) async throws {
        // Could trigger email digest generation
        if log.anchors.contains(where: { $0.contains("email") }) {
            try await generateEmailDigest(from: log)
        }
    }
}
```

**Calendar Connector**
```swift
import EventKit

class CalendarConnector: DreamflowConnectorProtocol {
    let eventStore = EKEventStore()

    func provideContext(for date: Date) async throws -> [String: Any] {
        // Fetch calendar events
        let events = try await fetchEvents(for: date)

        return [
            "meetingCount": events.count,
            "totalDuration": calculateTotalDuration(events),
            "nextMeeting": events.first?.title
        ]
    }
}
```

## Performance Considerations

### Battery Impact
- **Minimal**: Runs once per day during charging
- **Duration**: Typically 2-5 minutes
- **Optimization**: Use efficient model (gpt-3.5-turbo vs gpt-4)

### Network Usage
- **On-device only**: If using local model
- **API calls**: 3-5 requests if using cloud LLM
- **Total bandwidth**: < 50KB per session

### Storage
- **Per log**: ~5-10KB (text only)
- **Annual storage**: ~2-4MB for 365 days
- **Cleanup**: Auto-delete logs older than 1 year

## Privacy & Security

### Data Collection
- ✅ All data processed on-device
- ✅ No telemetry sent to Codexify
- ✅ LLM inference via user's choice
- ✅ Logs stored locally only

### User Controls
```swift
// Disable Dreamflow
let disabledConfig = DreamflowConfig(
    enabled: false,
    // ... other settings
)

// Delete all logs
let storage = DreamflowStorage.shared
let logs = try await storage.fetchRecent(limit: .max)
for log in logs {
    try await storage.delete(log.id)
}

// Prevent specific fields
let privacyConfig = DreamflowConfig(
    // ... settings
    includeFields: DreamflowConfig.IncludeFields(
        summary: true,
        moodSketch: false,  // Disable mood tracking
        foresight: false,   // Disable predictions
        anchors: false      // Disable theme extraction
    )
)
```

## SwiftUI Integration

```swift
import SwiftUI

struct DreamflowHistoryView: View {
    @StateObject private var viewModel = DreamflowViewModel()

    var body: some View {
        List(viewModel.logs) { log in
            VStack(alignment: .leading, spacing: 8) {
                Text(log.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(log.summary)
                    .font(.body)

                if let mood = log.moodSketch {
                    Text(mood)
                        .font(.caption)
                        .italic()
                        .foregroundColor(.blue)
                }

                if !log.anchors.isEmpty {
                    HStack {
                        ForEach(log.anchors, id: \.self) { anchor in
                            Text(anchor)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Dreamflow History")
        .onAppear {
            Task {
                await viewModel.loadLogs()
            }
        }
    }
}

@MainActor
class DreamflowViewModel: ObservableObject {
    @Published var logs: [DreamflowLog] = []

    private let storage = DreamflowStorage.shared

    func loadLogs() async {
        logs = (try? await storage.fetchRecent(limit: 30)) ?? []
    }
}
```

## Testing

```bash
# Run Dreamflow tests
xcodebuild test -scheme Codexify -only-testing:DreamflowRunnerTests

# Run single test
xcodebuild test -scheme Codexify \
  -only-testing:DreamflowRunnerTests/testDreamflowRunner_Initialization
```

## Roadmap

- [ ] CloudKit sync for cross-device access
- [ ] Voice summary playback (read digest aloud)
- [ ] Interactive reflection (ask follow-up questions)
- [ ] Trend visualization (graphs over time)
- [ ] Smart notifications (insights worth acting on)
- [ ] Export to journal apps (Day One, etc.)
- [ ] Sharing digests with trusted contacts

---

## Phase Three: Digest Delivery System 📬

### Overview

The **Digest Delivery System** automates the delivery of Morning Digests to users through notifications and background scheduling. It seamlessly integrates with the Dreamflow runtime to provide timely, actionable insights from your daily reflections.

### Quick Start: Digest Delivery

```swift
import Foundation

// Initialize delivery manager
let generator = MorningDigestGenerator(modelRouter: router)
let deliveryManager = DigestDeliveryManager.makeReal(
    generator: generator,
    config: .default
)

// Manual delivery
Task {
    do {
        let digest = try await deliveryManager.deliverDigestNow()
        print("✅ Delivered: \(digest.headline)")
    } catch {
        print("❌ Delivery failed: \(error)")
    }
}

// Schedule daily delivery at 8am
try deliveryManager.scheduleDailyDigest()
```

### Architecture: Digest Delivery

```
┌─────────────────────────────────────────────────────────────┐
│                   DigestDeliveryManager                      │
│                                                               │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │ Notification    │  │ Background Task  │  │  Storage   │ │
│  │ Center          │  │ Scheduler        │  │            │ │
│  └─────────────────┘  └──────────────────┘  └────────────┘ │
│           │                     │                    │       │
│           └─────────────────────┴────────────────────┘       │
│                             │                                │
│                   ┌─────────▼─────────┐                     │
│                   │ MorningDigest     │                     │
│                   │ Generator         │                     │
│                   └───────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

✅ **Local Notifications**
- Rich notification content with digest summaries
- Custom notification categories with actions
- User info for deep linking to full digest view

✅ **Background Scheduling**
- Automated daily delivery via BGTaskScheduler
- Configurable delivery time (default: 8am)
- Battery and charging requirements

✅ **Rate Limiting**
- Prevents notification spam
- Configurable minimum interval between deliveries
- Graceful error messages with next available time

✅ **Mock Architecture**
- Full protocol-based DI for testing
- Mock implementations for all iOS APIs
- Graceful degradation in simulator

✅ **Error Handling**
- Comprehensive error types
- Localized error descriptions
- Recovery suggestions

### Configuration Options

```swift
// Default configuration (8am, full summary)
let defaultConfig = DigestDeliveryConfig.default

// Minimal configuration (9am, no summary)
let minimalConfig = DigestDeliveryConfig.minimal

// Custom configuration
let customConfig = DigestDeliveryConfig(
    deliveryHour: 7,                    // 7am
    allowOnBattery: true,
    includeSummary: true,
    notificationTitle: "Good Morning ☀️",
    notificationCategory: "DIGEST",
    enabled: true,
    minimumDeliveryInterval: 3600       // 1 hour
)
```

### AppDelegate Integration

```swift
import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var deliveryManager: DigestDeliveryManager?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize delivery system
        let router = ModelRouter(preferences: .defaultConfiguration())
        let generator = MorningDigestGenerator(modelRouter: router)

        deliveryManager = DigestDeliveryManager.makeReal(
            generator: generator,
            config: .default
        )

        // Register background task
        deliveryManager?.registerBackgroundTask()

        // Schedule daily delivery
        try? deliveryManager?.scheduleDailyDigest()

        return true
    }
}
```

### Info.plist Configuration

Add these keys for notifications and background tasks:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.codexify.dailyDigest</string>
</array>

<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>

<key>NSUserNotificationsUsageDescription</key>
<string>Codexify sends you daily digests with insights from your reflections.</string>
```

### SwiftUI Integration Example

```swift
import SwiftUI

struct DigestView: View {
    @StateObject private var viewModel = DigestViewModel()

    var body: some View {
        VStack(spacing: Spacing.lg) {
            if let digest = viewModel.currentDigest {
                DigestCard(digest: digest)
            }

            Button("Refresh Digest") {
                Task {
                    await viewModel.deliverNow()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isLoading)

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(TextStyle.caption)
                    .foregroundColor(ColorTokens.error)
            }
        }
        .padding(Spacing.lg)
    }
}
```

### Error Handling

```swift
do {
    let digest = try await manager.deliverDigestNow()
    print("✅ Delivered: \(digest.headline)")

} catch DigestDeliveryError.notificationDenied {
    // Prompt user to enable notifications
    showNotificationSettings()

} catch DigestDeliveryError.rateLimitExceeded(let nextAvailable) {
    // Show cooldown message
    print("⏳ Next delivery available at: \(nextAvailable)")

} catch DigestDeliveryError.generationFailed(let error) {
    // Log generation error
    print("❌ Generation failed: \(error)")

} catch {
    print("❌ Unexpected error: \(error)")
}
```

### Testing

The Digest Delivery system includes comprehensive tests (36+ test cases):

```bash
# Run all digest delivery tests
xcodebuild test \
  -scheme Codexify \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CodexifyTests/DigestDeliveryTests
```

**Test Coverage:**
- ✅ Configuration validation
- ✅ Immediate delivery flow
- ✅ Notification sending
- ✅ Background task scheduling
- ✅ Rate limiting
- ✅ Error handling
- ✅ Mock implementations
- ✅ Storage operations
- ✅ Integration tests
- ✅ Performance benchmarks

### Mock Architecture

All iOS APIs are mockable for testing:

```swift
// Create mocked manager
let mockCenter = MockNotificationCenter()
let mockScheduler = MockBackgroundTaskScheduler()
let mockStorage = MockDigestStorage()

let manager = DigestDeliveryManager.makeMock(
    notificationCenter: mockCenter,
    taskScheduler: mockScheduler,
    storage: mockStorage,
    config: .default
)

// Test delivery
let digest = try await manager.deliverDigestNow()

// Verify behavior
XCTAssertEqual(mockCenter.sentNotifications.count, 1)
XCTAssertEqual(mockStorage.savedDigests.count, 1)
```

### API Reference: Digest Delivery

#### `DigestDeliveryManager`

```swift
// Initialization
init(
    notificationCenter: NotificationCenterProtocol,
    taskScheduler: BackgroundTaskSchedulerProtocol?,
    storage: DigestStorageProtocol,
    generator: MorningDigestGenerator,
    config: DigestDeliveryConfig = .default
)

// Static factories
static func makeReal(
    generator: MorningDigestGenerator,
    config: DigestDeliveryConfig = .default
) -> DigestDeliveryManager

static func makeMock(...) -> DigestDeliveryManager

// Methods
func scheduleDailyDigest() throws
func cancelScheduledDigest()
func deliverDigestNow(days: Int = 7) async throws -> MorningDigest
func registerBackgroundTask()
```

#### `DigestDeliveryConfig`

```swift
struct DigestDeliveryConfig: Codable, Equatable {
    let deliveryHour: Int                   // 0-23
    let allowOnBattery: Bool
    let includeSummary: Bool
    let notificationTitle: String
    let notificationCategory: String
    let enabled: Bool
    let minimumDeliveryInterval: TimeInterval

    static let `default`: DigestDeliveryConfig
    static let minimal: DigestDeliveryConfig
}
```

#### `DigestDeliveryError`

```swift
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
}
```

### Troubleshooting

**Notifications not appearing:**
1. Check notification permissions in Settings
2. Verify notification was sent: `mockCenter.sentNotifications`
3. Check Do Not Disturb settings

**Background tasks not running:**
1. Test on physical device (simulator is unreliable)
2. Verify `Info.plist` configuration
3. Force task in debugger: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.codexify.dailyDigest"]`

**Rate limit errors:**
1. Check last delivery time: `storage.getLastDeliveryDate()`
2. Adjust `minimumDeliveryInterval` for testing

### Roadmap: Phase Three Extensions

- [ ] CloudKit sync for multi-device digest history
- [ ] Rich notification content extensions with previews
- [ ] Interactive notification actions (mark read, share)
- [ ] Smart delivery time based on wake patterns
- [ ] Adaptive frequency (skip if no new content)
- [ ] Do Not Disturb integration
- [ ] Delivery analytics and metrics
- [ ] Full-text search for digest history
- [ ] Export digest history (JSON/Markdown)

---

**Built with ❤️ and ☕️ by Codexify:Scout**

Phase Two: Dreamflow Runtime Complete 🌙
Phase Three: Digest Delivery Complete 📬
