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
├── MorningDigestGenerator # Digest generation from logs
├── DigestDelivery         # Notifications & sharing
├── DreamflowStorage       # Persistent log storage
├── DigestCard/DigestView  # SwiftUI presentation
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

✅ **Digest Delivery**
- Local push notifications
- Rich notification previews
- Share digest via activity sheet
- Markdown export for journaling
- Haptic feedback on interactions
- Background sync (CloudKit ready)

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
// Aggregate past week into digest
Task {
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

### 5. Deliver Digest via Notifications

```swift
import DigestDelivery

// Initialize delivery system
let delivery = DigestDelivery.shared

// Request notification permissions
let granted = await delivery.requestNotificationPermission()

if granted {
    // Generate digest
    let digest = try await dreamflow.generateMorningDigest(days: 7)

    // Schedule notification for next morning
    try await delivery.scheduleNotification(for: digest)

    // Or send immediately
    delivery.sendNow(digest: digest)
}
```

### 6. Share Digest

```swift
// From a UIViewController
let digest = try await dreamflow.generateMorningDigest()

delivery.shareDigest(
    digest,
    from: self.viewController,
    sourceView: shareButton
)

// Export as markdown file
let fileURL = try await delivery.exportAsMarkdown(digest)
print("Exported to: \(fileURL.path)")
```

### 7. Integrated Delivery Flow

```swift
// Complete flow: run Dreamflow → generate digest → deliver notification
Task {
    do {
        // 1. Run nightly Dreamflow
        let log = try await dreamflow.runDreamflow(for: Date())
        print("✅ Dreamflow complete: \(log.summary)")

        // 2. Generate morning digest
        let digest = try await dreamflow.generateMorningDigest(days: 7)

        // 3. Deliver via notification
        await delivery.deliverAfterDreamflow(digest, immediate: false)

        print("✅ Digest scheduled for morning delivery")

    } catch {
        print("❌ Error: \(error)")
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

### DigestDelivery

#### `requestNotificationPermission() async -> Bool`

Request user permission for notifications.

**Returns:** `true` if granted, `false` otherwise

**Example:**
```swift
let granted = await delivery.requestNotificationPermission()
```

#### `scheduleNotification(for digest: MorningDigest) async throws`

Schedule a notification for next morning.

**Parameters:**
- `digest`: MorningDigest to deliver

**Throws:** `DigestDeliveryError` if scheduling fails

**Example:**
```swift
try await delivery.scheduleNotification(for: digest)
```

#### `sendNow(digest: MorningDigest)`

Send notification immediately.

**Parameters:**
- `digest`: MorningDigest to send

**Example:**
```swift
delivery.sendNow(digest: digest)
```

#### `shareDigest(_:from:sourceView:)`

Share digest via UIActivityViewController.

**Parameters:**
- `digest`: MorningDigest to share
- `viewController`: Presenting view controller
- `sourceView`: Optional source for iPad popover

**Example:**
```swift
delivery.shareDigest(digest, from: self, sourceView: button)
```

#### `exportAsMarkdown(_:to:) async throws -> URL`

Export digest as markdown file.

**Parameters:**
- `digest`: MorningDigest to export
- `destinationURL`: Optional destination (default: Documents)

**Returns:** URL of exported file

**Example:**
```swift
let url = try await delivery.exportAsMarkdown(digest)
```

#### `cancelScheduledNotifications()`

Cancel all pending digest notifications.

**Example:**
```swift
delivery.cancelScheduledNotifications()
```

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

### 1. Notification Setup

**Location:** `DigestDelivery.swift`

**Info.plist Configuration:**

Add notification capability to your app's Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

**App Initialization:**

```swift
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Initialize DigestDelivery
        let delivery = DigestDelivery.shared

        // Request notification permissions on first launch
        Task {
            await delivery.requestNotificationPermission()
        }

        return true
    }
}
```

**SwiftUI App Integration:**

```swift
import SwiftUI

@main
struct CodexifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task {
                        await DigestDelivery.shared.requestNotificationPermission()
                    }
                }
        }
    }
}
```

### 2. Background Task Scheduling

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

### 3. Persistent Storage

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

### 4. Connector Implementations

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

- [x] **Smart notifications** (insights worth acting on) ✅
- [x] **Export to journal apps** (markdown format) ✅
- [x] **Sharing digests** via activity sheet ✅
- [ ] CloudKit sync for cross-device access
- [ ] Voice summary playback (read digest aloud)
- [ ] Interactive reflection (ask follow-up questions)
- [ ] Trend visualization (graphs over time)
- [ ] Advanced notification actions (mark as read, archive)
- [ ] Widget support for home screen digest preview

---

**Built with ❤️ by Codexify:Scout**

Phase Two: Dreamflow Runtime Complete 🌙
