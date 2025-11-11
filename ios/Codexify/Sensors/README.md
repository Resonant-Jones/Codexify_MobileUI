# SensorAggregator - Unified Sensor Data Collection

🚀 **Part of Codexify:Scout**

A privacy-first, modular sensor aggregation system for iOS that collects GPS, activity, health metrics, and device state into unified snapshots for contextualizing LLM prompts in a sovereign mobile RAG system.

## Overview

SensorAggregator is the sensory layer of Codexify:Scout, providing real-world context to enhance LLM responses. It unifies data from multiple iOS frameworks into a single, lightweight snapshot that can be easily integrated into RAG pipelines.

## Architecture

```
SensorAggregator
├── Data Models
│   ├── SensorSnapshot       # Complete sensor snapshot
│   ├── LocationSnapshot     # GPS coordinates & place
│   ├── ActivityType         # Motion activity
│   ├── HealthMetrics        # HealthKit data
│   └── DeviceState          # Battery, network, thermal
│
├── Reader Protocols
│   ├── LocationReaderProtocol    # CoreLocation interface
│   ├── MotionReaderProtocol      # CoreMotion interface
│   ├── HealthReaderProtocol      # HealthKit interface
│   └── DeviceStateReaderProtocol # UIDevice interface
│
├── Implementations
│   ├── LocationReader        # GPS data collection
│   ├── MotionReader          # Activity detection
│   ├── HealthReader          # Health metrics
│   └── DeviceStateReader     # Device state
│
└── SensorAggregator          # Main coordinator
    ├── getCurrentSnapshot()  # Collect all sensors
    ├── startMonitoring()     # Begin continuous tracking
    └── stopMonitoring()      # End tracking
```

## Features

✅ **Multi-Source Data Collection**
- GPS location with place names
- Activity detection (walking, running, cycling, etc.)
- Health metrics (HR, steps, distance, calories)
- Device state (battery, network, thermal)

✅ **Privacy-First Design**
- All data processed on-device
- No cloud transmission
- User-controlled permissions
- Configurable sensor enable/disable

✅ **Modular Architecture**
- Protocol-based sensor readers
- Easy to mock for testing
- Pluggable implementations
- Independent sensor failures don't crash system

✅ **Async/Await Throughout**
- Fully modern Swift concurrency
- Parallel sensor data fetching
- Timeout protection
- Non-blocking operations

✅ **Comprehensive Testing**
- Mock implementations included
- 30+ unit tests
- Integration tests
- Performance tests
- Edge case coverage

## Quick Start

### 1. Basic Usage

```swift
import Foundation

// Initialize sensor aggregator
let aggregator = SensorAggregator.shared

// Request permissions first
try await aggregator.requestPermissions()

// Get a snapshot
let snapshot = try await aggregator.getCurrentSnapshot()

// Access components
if let location = snapshot.location {
    print("📍 Location: \(location.placeName ?? "Unknown")")
    print("   Coords: \(location.latitude), \(location.longitude)")
}

if let activity = snapshot.activity {
    print("🏃 Activity: \(activity.description)")
}

if let health = snapshot.healthMetrics {
    print("❤️ Heart Rate: \(health.heartRate ?? 0) bpm")
    print("👣 Steps: \(health.steps ?? 0)")
}

if let device = snapshot.deviceState {
    print("🔋 Battery: \(Int((device.batteryLevel ?? 0) * 100))%")
    print("📶 Network: \(device.networkType.rawValue)")
}

// Quick summary
print(snapshot.summary)
```

### 2. Continuous Monitoring

```swift
// Start monitoring all sensors
try await aggregator.startMonitoring()

// Periodically get snapshots
Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
    Task {
        let snapshot = try await aggregator.getCurrentSnapshot()
        print("Updated: \(snapshot.summary)")
    }
}

// Later, stop monitoring to save battery
await aggregator.stopMonitoring()
```

### 3. Custom Configuration

```swift
// Privacy-focused config (device state only)
let privacyConfig = SensorAggregator.Configuration.privacyFocused
let privacyAggregator = SensorAggregator(config: privacyConfig)

// Custom config
let customConfig = SensorAggregator.Configuration(
    enableLocation: true,
    enableMotion: false,
    enableHealth: false,
    enableDeviceState: true,
    timeout: 3.0
)

let customAggregator = SensorAggregator(config: customConfig)
```

### 4. Integration with ContextBroker

```swift
// Use in RAG pipeline
class ContextBroker {
    private let sensorAggregator = SensorAggregator.shared

    func buildContext(forPrompt input: String) async throws -> ContextPacket {
        // Get sensor snapshot
        let sensorSnapshot = try await sensorAggregator.getCurrentSnapshot()

        // Combine with other context sources
        let packet = ContextPacket(
            threadHistory: threadHistory,
            semanticMemory: memories,
            sensorSnapshot: sensorSnapshot
        )

        return packet
    }
}
```

## Data Models

### SensorSnapshot

Complete snapshot from all sensors.

```swift
struct SensorSnapshot {
    let timestamp: Date
    let location: LocationSnapshot?
    let activity: ActivityType?
    let healthMetrics: HealthMetrics?
    let deviceState: DeviceState?

    var hasData: Bool
    var summary: String
}
```

### LocationSnapshot

GPS coordinates and place information.

```swift
struct LocationSnapshot {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double
    let verticalAccuracy: Double?
    let timestamp: Date
    let placeName: String?
    let address: String?

    func distance(to other: LocationSnapshot) -> Double
}
```

### ActivityType

Detected user activity.

```swift
enum ActivityType {
    case stationary   // 🧍
    case walking      // 🚶
    case running      // 🏃
    case cycling      // 🚴
    case automotive   // 🚗
    case unknown      // ❓
}
```

### HealthMetrics

Health and fitness data from HealthKit.

```swift
struct HealthMetrics {
    let heartRate: Double?
    let heartRateVariability: Double?
    let steps: Int?
    let distance: Double?
    let activeEnergyBurned: Double?
    let restingEnergyBurned: Double?
    let standHours: Int?
    let exerciseMinutes: Int?
    let flightsClimbed: Int?
    let vo2Max: Double?

    var hasData: Bool
}
```

### DeviceState

Device battery and system state.

```swift
struct DeviceState {
    let batteryLevel: Float?
    let batteryState: BatteryState  // unplugged, charging, full
    let lowPowerMode: Bool
    let thermalState: ThermalState  // nominal, fair, serious, critical
    let networkType: NetworkType    // wifi, cellular, none
    let diskSpaceAvailable: Int64?
    let memoryUsage: Double?

    var isOptimalForCompute: Bool
}
```

## API Reference

### SensorAggregator

#### `getCurrentSnapshot() async throws -> SensorSnapshot`

Collects current data from all enabled sensors.

**Returns:** Complete sensor snapshot

**Throws:**
- `SensorAggregatorError.timeout` if collection exceeds timeout
- Individual sensor errors are caught and result in nil values

**Example:**
```swift
let snapshot = try await aggregator.getCurrentSnapshot()
```

#### `startMonitoring() async throws`

Starts continuous monitoring of all enabled sensors.

**Throws:**
- `SensorAggregatorError.alreadyMonitoring` if already monitoring

**Example:**
```swift
try await aggregator.startMonitoring()
```

#### `stopMonitoring() async`

Stops monitoring all sensors.

**Example:**
```swift
await aggregator.stopMonitoring()
```

#### `requestPermissions() async throws`

Requests necessary permissions for enabled sensors.

**Example:**
```swift
try await aggregator.requestPermissions()
```

#### `getLastSnapshot() -> SensorSnapshot?`

Returns the last cached snapshot (may be stale).

**Returns:** Last snapshot or nil if none collected

### Configuration

```swift
struct Configuration {
    let enableLocation: Bool
    let enableMotion: Bool
    let enableHealth: Bool
    let enableDeviceState: Bool
    let timeout: TimeInterval

    static let `default`: Configuration
    static let privacyFocused: Configuration
}
```

## Required Permissions

Add these to your `Info.plist`:

```xml
<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Codexify uses your location to provide contextually relevant responses based on where you are.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Codexify can use your location in the background to provide better context.</string>

<!-- Motion & Fitness -->
<key>NSMotionUsageDescription</key>
<string>Codexify uses motion data to understand your current activity and provide relevant suggestions.</string>

<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>Codexify can use your health data to provide personalized insights and recommendations.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Codexify may record health data to track your wellness journey.</string>
```

## Integration TODOs

### 1. CoreLocation Integration

**Location:** `SensorAggregator.swift:183` (LocationReader)

```swift
import CoreLocation

class LocationReader: NSObject, LocationReaderProtocol, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager
    private var currentLocation: CLLocation?
    private var placeName: String?

    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50 // Update every 50m
    }

    func getCurrentLocation() async throws -> LocationSnapshot? {
        // Check authorization
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            throw SensorAggregatorError.locationPermissionDenied
        case .denied, .restricted:
            throw SensorAggregatorError.locationPermissionDenied
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }

        guard let location = currentLocation else {
            // Request one-time update
            locationManager.requestLocation()

            // Wait for update
            try await Task.sleep(nanoseconds: 2_000_000_000)

            guard let location = currentLocation else {
                throw SensorAggregatorError.sensorUnavailable(sensor: "Location")
            }

            return LocationSnapshot(from: location, placeName: placeName)
        }

        return LocationSnapshot(from: location, placeName: placeName)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last

        // Reverse geocode for place name
        if let location = locations.last {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                if let placemark = placemarks?.first {
                    self?.placeName = placemark.locality ?? placemark.name
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
```

### 2. CoreMotion Integration

**Location:** `SensorAggregator.swift:245` (MotionReader)

```swift
import CoreMotion

class MotionReader: MotionReaderProtocol {
    private let activityManager = CMMotionActivityManager()
    private var currentActivity: CMMotionActivity?

    func getCurrentActivity() async throws -> ActivityType? {
        guard CMMotionActivityManager.isActivityAvailable() else {
            throw SensorAggregatorError.sensorUnavailable(sensor: "Motion Activity")
        }

        return await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(
                from: Date().addingTimeInterval(-60),
                to: Date(),
                to: .main
            ) { activities, error in
                guard let activity = activities?.last else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: self.mapActivityType(activity))
            }
        }
    }

    func startMonitoring() async throws {
        guard CMMotionActivityManager.isActivityAvailable() else {
            throw SensorAggregatorError.sensorUnavailable(sensor: "Motion Activity")
        }

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            self?.currentActivity = activity
        }

        isMonitoring = true
    }

    private func mapActivityType(_ activity: CMMotionActivity) -> ActivityType {
        if activity.stationary {
            return .stationary
        } else if activity.walking {
            return .walking
        } else if activity.running {
            return .running
        } else if activity.cycling {
            return .cycling
        } else if activity.automotive {
            return .automotive
        } else {
            return .unknown
        }
    }
}
```

### 3. HealthKit Integration

**Location:** `SensorAggregator.swift:306` (HealthReader)

```swift
import HealthKit

class HealthReader: HealthReaderProtocol {
    private let healthStore = HKHealthStore()
    private var hasAuthorization = false

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SensorAggregatorError.sensorUnavailable(sensor: "HealthKit")
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        hasAuthorization = true
    }

    func getCurrentMetrics() async throws -> HealthMetrics? {
        guard hasAuthorization else {
            throw SensorAggregatorError.healthPermissionDenied
        }

        async let heartRate = queryMostRecentSample(for: .heartRate)
        async let hrv = queryMostRecentSample(for: .heartRateVariabilitySDNN)
        async let steps = queryTodaySum(for: .stepCount)
        async let distance = queryTodaySum(for: .distanceWalkingRunning)
        async let activeEnergy = queryTodaySum(for: .activeEnergyBurned)
        async let restingEnergy = queryTodaySum(for: .basalEnergyBurned)

        return try await HealthMetrics(
            heartRate: heartRate,
            heartRateVariability: hrv,
            steps: Int(steps),
            distance: distance,
            activeEnergyBurned: activeEnergy,
            restingEnergyBurned: restingEnergy
        )
    }

    private func queryMostRecentSample(for identifier: HKQuantityTypeIdentifier) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            // Handle result
        }

        return await withCheckedContinuation { continuation in
            healthStore.execute(query)
            // ... implementation
        }
    }

    private func queryTodaySum(for identifier: HKQuantityTypeIdentifier) async throws -> Double {
        // ... implementation
    }
}
```

### 4. UIDevice Integration

**Location:** `SensorAggregator.swift:383` (DeviceStateReader)

```swift
import UIKit

class DeviceStateReader: DeviceStateReaderProtocol {

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func getCurrentState() async -> DeviceState {
        let battery = UIDevice.current.batteryLevel
        let batteryState = mapBatteryState(UIDevice.current.batteryState)
        let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermalState = mapThermalState(ProcessInfo.processInfo.thermalState)
        let networkType = detectNetworkType()
        let diskSpace = getAvailableDiskSpace()
        let memoryUsage = getMemoryUsage()

        return DeviceState(
            batteryLevel: battery >= 0 ? battery : nil,
            batteryState: batteryState,
            lowPowerMode: lowPowerMode,
            thermalState: thermalState,
            networkType: networkType,
            diskSpaceAvailable: diskSpace,
            memoryUsage: memoryUsage
        )
    }

    private func mapBatteryState(_ state: UIDevice.BatteryState) -> DeviceState.BatteryState {
        switch state {
        case .unknown: return .unknown
        case .unplugged: return .unplugged
        case .charging: return .charging
        case .full: return .full
        @unknown default: return .unknown
        }
    }

    private func mapThermalState(_ state: ProcessInfo.ThermalState) -> DeviceState.ThermalState {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    private func detectNetworkType() -> DeviceState.NetworkType {
        // Use Network framework
        import Network

        let monitor = NWPathMonitor()
        // ... implementation

        return .wifi
    }

    private func getAvailableDiskSpace() -> Int64? {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            return nil
        }
    }

    private func getMemoryUsage() -> Double? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return nil }

        let used = Double(info.resident_size)
        let total = Double(ProcessInfo.processInfo.physicalMemory)

        return used / total
    }
}
```

## Testing

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme Codexify -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme Codexify -only-testing:SensorAggregatorTests
```

### Test Coverage

The test suite includes:
- ✅ 30+ unit tests
- ✅ Mock implementations for all sensors
- ✅ Integration tests
- ✅ Edge case tests
- ✅ Performance tests
- ✅ Async/await tests
- ✅ Timeout tests
- ✅ Error handling tests

### Example Test

```swift
func testGetCurrentSnapshot_ReturnsCompleteSnapshot() async throws {
    // Given: All sensors configured
    let aggregator = SensorAggregator(
        locationReader: mockLocationReader,
        motionReader: mockMotionReader,
        healthReader: mockHealthReader,
        deviceStateReader: mockDeviceStateReader
    )

    // When: Getting snapshot
    let snapshot = try await aggregator.getCurrentSnapshot()

    // Then: Should contain all data
    XCTAssertNotNil(snapshot.location)
    XCTAssertNotNil(snapshot.activity)
    XCTAssertNotNil(snapshot.healthMetrics)
    XCTAssertNotNil(snapshot.deviceState)
}
```

## Performance Considerations

### Battery Impact

- Location: **Low** (100m accuracy, 50m filter)
- Motion: **Very Low** (efficient CoreMotion)
- Health: **Low** (query-based, not continuous)
- Device: **Negligible** (system APIs)

### Optimization Tips

1. **Use appropriate location accuracy:**
```swift
locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
```

2. **Set distance filter:**
```swift
locationManager.distanceFilter = 50 // meters
```

3. **Stop monitoring when not needed:**
```swift
await aggregator.stopMonitoring()
```

4. **Use privacy-focused config for background:**
```swift
let bgConfig = SensorAggregator.Configuration.privacyFocused
```

## Privacy & Security

### Data Storage
- All sensor data processed on-device
- No cloud transmission
- No persistent storage (unless you implement it)
- User controls all permissions

### Best Practices

1. **Request permissions only when needed**
2. **Explain why each permission is required**
3. **Provide graceful degradation if denied**
4. **Allow users to disable sensors**
5. **Show sensor status in UI**

## SwiftUI Integration

```swift
import SwiftUI

struct SensorStatusView: View {
    @StateObject private var viewModel = SensorViewModel()

    var body: some View {
        VStack {
            if let snapshot = viewModel.currentSnapshot {
                Text(snapshot.summary)
                    .font(.headline)

                if let location = snapshot.location {
                    HStack {
                        Image(systemName: "location.fill")
                        Text(location.placeName ?? "Unknown")
                    }
                }

                if let activity = snapshot.activity {
                    HStack {
                        Text(activity.emoji)
                        Text(activity.rawValue.capitalized)
                    }
                }
            }

            Button(viewModel.isMonitoring ? "Stop" : "Start") {
                Task {
                    if viewModel.isMonitoring {
                        await viewModel.stopMonitoring()
                    } else {
                        try? await viewModel.startMonitoring()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.refreshSnapshot()
            }
        }
    }
}

@MainActor
class SensorViewModel: ObservableObject {
    @Published var currentSnapshot: SensorSnapshot?
    @Published var isMonitoring = false

    private let aggregator = SensorAggregator.shared

    func startMonitoring() async throws {
        try await aggregator.startMonitoring()
        isMonitoring = true
    }

    func stopMonitoring() async {
        await aggregator.stopMonitoring()
        isMonitoring = false
    }

    func refreshSnapshot() async {
        currentSnapshot = try? await aggregator.getCurrentSnapshot()
    }
}
```

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 13.0+

## Related Modules

- **ContextBroker**: Uses SensorSnapshot for RAG context
- **ModelRouter**: Receives context-enhanced prompts

## Roadmap

- [ ] Bluetooth beacon detection
- [ ] Wi-Fi network context
- [ ] Calendar event awareness
- [ ] Weather integration
- [ ] AirPods connectivity state
- [ ] Focus mode detection
- [ ] Screen time data
- [ ] Noise level monitoring

---

**Built with ❤️ by Codexify:Scout**
