//
//  SensorAggregator.swift
//  Codexify
//
//  Created by Codexify:Scout
//  Sovereign Mobile RAG - Unified Sensor Data Collection
//

import Foundation
import CoreLocation
import Combine

// MARK: - Data Models

/// GPS location snapshot
struct LocationSnapshot: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double
    let verticalAccuracy: Double?
    let timestamp: Date
    let placeName: String?
    let address: String?

    init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double,
        verticalAccuracy: Double? = nil,
        timestamp: Date = Date(),
        placeName: String? = nil,
        address: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.timestamp = timestamp
        self.placeName = placeName
        self.address = address
    }

    init(from location: CLLocation, placeName: String? = nil, address: String? = nil) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.timestamp = location.timestamp
        self.placeName = placeName
        self.address = address
    }

    /// Distance to another location in meters
    func distance(to other: LocationSnapshot) -> Double {
        let earthRadius: Double = 6371000 // meters

        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = (other.latitude - latitude) * .pi / 180
        let deltaLon = (other.longitude - longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }
}

/// User activity type detected from motion sensors
enum ActivityType: String, Codable, CaseIterable {
    case stationary
    case walking
    case running
    case cycling
    case automotive
    case unknown

    var emoji: String {
        switch self {
        case .stationary: return "🧍"
        case .walking: return "🚶"
        case .running: return "🏃"
        case .cycling: return "🚴"
        case .automotive: return "🚗"
        case .unknown: return "❓"
        }
    }

    var description: String {
        return "\(emoji) \(rawValue.capitalized)"
    }
}

/// Health and fitness metrics from HealthKit
struct HealthMetrics: Codable, Equatable {
    let heartRate: Double?
    let heartRateVariability: Double?
    let steps: Int?
    let distance: Double? // meters
    let activeEnergyBurned: Double? // kcal
    let restingEnergyBurned: Double? // kcal
    let standHours: Int?
    let exerciseMinutes: Int?
    let flightsClimbed: Int?
    let vo2Max: Double?

    init(
        heartRate: Double? = nil,
        heartRateVariability: Double? = nil,
        steps: Int? = nil,
        distance: Double? = nil,
        activeEnergyBurned: Double? = nil,
        restingEnergyBurned: Double? = nil,
        standHours: Int? = nil,
        exerciseMinutes: Int? = nil,
        flightsClimbed: Int? = nil,
        vo2Max: Double? = nil
    ) {
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.steps = steps
        self.distance = distance
        self.activeEnergyBurned = activeEnergyBurned
        self.restingEnergyBurned = restingEnergyBurned
        self.standHours = standHours
        self.exerciseMinutes = exerciseMinutes
        self.flightsClimbed = flightsClimbed
        self.vo2Max = vo2Max
    }

    /// Check if any metrics are available
    var hasData: Bool {
        return heartRate != nil ||
               heartRateVariability != nil ||
               steps != nil ||
               distance != nil ||
               activeEnergyBurned != nil
    }
}

/// Device battery and system state
struct DeviceState: Codable, Equatable {
    let batteryLevel: Float? // 0.0 to 1.0
    let batteryState: BatteryState
    let lowPowerMode: Bool
    let thermalState: ThermalState
    let networkType: NetworkType
    let diskSpaceAvailable: Int64? // bytes
    let memoryUsage: Double? // percentage

    enum BatteryState: String, Codable {
        case unknown
        case unplugged
        case charging
        case full
    }

    enum ThermalState: String, Codable {
        case nominal
        case fair
        case serious
        case critical
    }

    enum NetworkType: String, Codable {
        case none
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    init(
        batteryLevel: Float? = nil,
        batteryState: BatteryState = .unknown,
        lowPowerMode: Bool = false,
        thermalState: ThermalState = .nominal,
        networkType: NetworkType = .unknown,
        diskSpaceAvailable: Int64? = nil,
        memoryUsage: Double? = nil
    ) {
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.lowPowerMode = lowPowerMode
        self.thermalState = thermalState
        self.networkType = networkType
        self.diskSpaceAvailable = diskSpaceAvailable
        self.memoryUsage = memoryUsage
    }

    /// Check if device is in good state for intensive operations
    var isOptimalForCompute: Bool {
        let hasGoodBattery = (batteryLevel ?? 0) > 0.2 || batteryState == .charging
        let notOverheating = thermalState == .nominal || thermalState == .fair
        let notLowPower = !lowPowerMode

        return hasGoodBattery && notOverheating && notLowPower
    }
}

/// Complete sensor snapshot
struct SensorSnapshot: Codable, Equatable {
    let timestamp: Date
    let location: LocationSnapshot?
    let activity: ActivityType?
    let healthMetrics: HealthMetrics?
    let deviceState: DeviceState?

    init(
        timestamp: Date = Date(),
        location: LocationSnapshot? = nil,
        activity: ActivityType? = nil,
        healthMetrics: HealthMetrics? = nil,
        deviceState: DeviceState? = nil
    ) {
        self.timestamp = timestamp
        self.location = location
        self.activity = activity
        self.healthMetrics = healthMetrics
        self.deviceState = deviceState
    }

    /// Check if snapshot has any data
    var hasData: Bool {
        return location != nil ||
               activity != nil ||
               healthMetrics?.hasData == true ||
               deviceState != nil
    }

    /// Get a human-readable summary
    var summary: String {
        var parts: [String] = []

        if let location = location {
            parts.append("📍 \(location.placeName ?? "Location available")")
        }

        if let activity = activity {
            parts.append(activity.description)
        }

        if let health = healthMetrics, health.hasData {
            if let hr = health.heartRate {
                parts.append("❤️ \(Int(hr)) bpm")
            }
            if let steps = health.steps {
                parts.append("👣 \(steps) steps")
            }
        }

        if let device = deviceState {
            if let battery = device.batteryLevel {
                parts.append("🔋 \(Int(battery * 100))%")
            }
        }

        return parts.isEmpty ? "No sensor data" : parts.joined(separator: " | ")
    }
}

// MARK: - Error Types

/// Errors that can occur during sensor operations
enum SensorAggregatorError: Error, LocalizedError {
    case locationPermissionDenied
    case motionPermissionDenied
    case healthPermissionDenied
    case locationServicesDisabled
    case sensorUnavailable(sensor: String)
    case timeout
    case alreadyMonitoring
    case notMonitoring

    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location permission denied by user"
        case .motionPermissionDenied:
            return "Motion & Fitness permission denied by user"
        case .healthPermissionDenied:
            return "HealthKit permission denied by user"
        case .locationServicesDisabled:
            return "Location services are disabled"
        case .sensorUnavailable(let sensor):
            return "Sensor unavailable: \(sensor)"
        case .timeout:
            return "Sensor data collection timed out"
        case .alreadyMonitoring:
            return "Already monitoring sensors"
        case .notMonitoring:
            return "Not currently monitoring sensors"
        }
    }
}

// MARK: - Sensor Reader Protocols

/// Protocol for reading location data
protocol LocationReaderProtocol {
    func getCurrentLocation() async throws -> LocationSnapshot?
    func startMonitoring() async throws
    func stopMonitoring() async
    var isMonitoring: Bool { get }
}

/// Protocol for reading motion/activity data
protocol MotionReaderProtocol {
    func getCurrentActivity() async throws -> ActivityType?
    func startMonitoring() async throws
    func stopMonitoring() async
    var isMonitoring: Bool { get }
}

/// Protocol for reading health metrics
protocol HealthReaderProtocol {
    func getCurrentMetrics() async throws -> HealthMetrics?
    func requestAuthorization() async throws
    func startMonitoring() async throws
    func stopMonitoring() async
    var isMonitoring: Bool { get }
}

/// Protocol for reading device state
protocol DeviceStateReaderProtocol {
    func getCurrentState() async -> DeviceState
    func startMonitoring() async
    func stopMonitoring() async
    var isMonitoring: Bool { get }
}

// MARK: - Location Reader Implementation

/// Location reader using CoreLocation
class LocationReader: NSObject, LocationReaderProtocol {

    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocation?
    private var placeName: String?
    private(set) var isMonitoring = false

    override init() {
        super.init()
        // TODO: Initialize CLLocationManager
        // locationManager = CLLocationManager()
        // locationManager?.delegate = self
        // locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
        print("📍 [LocationReader] Initialized (stub mode)")
    }

    func getCurrentLocation() async throws -> LocationSnapshot? {
        // TODO: Implement real CoreLocation integration
        // if !CLLocationManager.locationServicesEnabled() {
        //     throw SensorAggregatorError.locationServicesDisabled
        // }
        //
        // switch locationManager?.authorizationStatus {
        // case .notDetermined:
        //     locationManager?.requestWhenInUseAuthorization()
        //     throw SensorAggregatorError.locationPermissionDenied
        // case .denied, .restricted:
        //     throw SensorAggregatorError.locationPermissionDenied
        // case .authorizedWhenInUse, .authorizedAlways:
        //     break
        // @unknown default:
        //     break
        // }
        //
        // if let location = currentLocation {
        //     return LocationSnapshot(from: location, placeName: placeName)
        // }

        // Stub: Return simulated location
        print("📍 [LocationReader] Getting current location (stub)")

        // Simulate async delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        return LocationSnapshot(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 15.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 5.0,
            timestamp: Date(),
            placeName: "San Francisco, CA",
            address: "Market Street, San Francisco"
        )
    }

    func startMonitoring() async throws {
        guard !isMonitoring else {
            throw SensorAggregatorError.alreadyMonitoring
        }

        // TODO: Start location updates
        // locationManager?.startUpdatingLocation()

        isMonitoring = true
        print("📍 [LocationReader] Started monitoring")
    }

    func stopMonitoring() async {
        guard isMonitoring else { return }

        // TODO: Stop location updates
        // locationManager?.stopUpdatingLocation()

        isMonitoring = false
        print("📍 [LocationReader] Stopped monitoring")
    }
}

// TODO: Implement CLLocationManagerDelegate
// extension LocationReader: CLLocationManagerDelegate {
//     func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//         currentLocation = locations.last
//
//         // Reverse geocode for place name
//         if let location = locations.last {
//             let geocoder = CLGeocoder()
//             geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
//                 if let placemark = placemarks?.first {
//                     self?.placeName = placemark.locality ?? placemark.name
//                 }
//             }
//         }
//     }
//
//     func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//         print("Location error: \(error)")
//     }
// }

// MARK: - Motion Reader Implementation

/// Motion reader using CoreMotion
class MotionReader: MotionReaderProtocol {

    private var currentActivity: ActivityType?
    private(set) var isMonitoring = false

    init() {
        // TODO: Initialize CMMotionActivityManager
        // activityManager = CMMotionActivityManager()
        print("🏃 [MotionReader] Initialized (stub mode)")
    }

    func getCurrentActivity() async throws -> ActivityType? {
        // TODO: Implement real CoreMotion integration
        // guard CMMotionActivityManager.isActivityAvailable() else {
        //     throw SensorAggregatorError.sensorUnavailable(sensor: "Motion Activity")
        // }
        //
        // switch CMMotionActivityManager.authorizationStatus() {
        // case .notDetermined:
        //     throw SensorAggregatorError.motionPermissionDenied
        // case .denied, .restricted:
        //     throw SensorAggregatorError.motionPermissionDenied
        // case .authorized:
        //     break
        // @unknown default:
        //     break
        // }

        // Stub: Return simulated activity
        print("🏃 [MotionReader] Getting current activity (stub)")

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Randomly choose an activity for demo
        let activities: [ActivityType] = [.walking, .stationary, .running, .cycling]
        return activities.randomElement()
    }

    func startMonitoring() async throws {
        guard !isMonitoring else {
            throw SensorAggregatorError.alreadyMonitoring
        }

        // TODO: Start activity updates
        // activityManager?.startActivityUpdates(to: .main) { [weak self] activity in
        //     guard let activity = activity else { return }
        //     self?.currentActivity = self?.mapActivityType(activity)
        // }

        isMonitoring = true
        print("🏃 [MotionReader] Started monitoring")
    }

    func stopMonitoring() async {
        guard isMonitoring else { return }

        // TODO: Stop activity updates
        // activityManager?.stopActivityUpdates()

        isMonitoring = false
        print("🏃 [MotionReader] Stopped monitoring")
    }

    // TODO: Map CMMotionActivity to ActivityType
    // private func mapActivityType(_ activity: CMMotionActivity) -> ActivityType {
    //     if activity.stationary {
    //         return .stationary
    //     } else if activity.walking {
    //         return .walking
    //     } else if activity.running {
    //         return .running
    //     } else if activity.cycling {
    //         return .cycling
    //     } else if activity.automotive {
    //         return .automotive
    //     } else {
    //         return .unknown
    //     }
    // }
}

// MARK: - Health Reader Implementation

/// Health reader using HealthKit
class HealthReader: HealthReaderProtocol {

    private var hasAuthorization = false
    private(set) var isMonitoring = false

    init() {
        // TODO: Initialize HKHealthStore
        // healthStore = HKHealthStore()
        print("❤️ [HealthReader] Initialized (stub mode)")
    }

    func requestAuthorization() async throws {
        // TODO: Request HealthKit authorization
        // guard HKHealthStore.isHealthDataAvailable() else {
        //     throw SensorAggregatorError.sensorUnavailable(sensor: "HealthKit")
        // }
        //
        // let typesToRead: Set<HKObjectType> = [
        //     HKObjectType.quantityType(forIdentifier: .heartRate)!,
        //     HKObjectType.quantityType(forIdentifier: .heartRateVariability)!,
        //     HKObjectType.quantityType(forIdentifier: .stepCount)!,
        //     HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        //     HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        //     HKObjectType.quantityType(forIdentifier: .appleStandHour)!,
        //     HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        //     HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
        //     HKObjectType.quantityType(forIdentifier: .vo2Max)!
        // ]
        //
        // try await healthStore?.requestAuthorization(toShare: [], read: typesToRead)

        hasAuthorization = true
        print("❤️ [HealthReader] Authorization granted (stub)")
    }

    func getCurrentMetrics() async throws -> HealthMetrics? {
        // TODO: Query HealthKit for current metrics
        // guard hasAuthorization else {
        //     throw SensorAggregatorError.healthPermissionDenied
        // }
        //
        // async let heartRate = queryMostRecentSample(for: .heartRate)
        // async let hrv = queryMostRecentSample(for: .heartRateVariability)
        // async let steps = queryTodaySum(for: .stepCount)
        // async let distance = queryTodaySum(for: .distanceWalkingRunning)
        // async let energy = queryTodaySum(for: .activeEnergyBurned)
        //
        // return try await HealthMetrics(
        //     heartRate: heartRate,
        //     steps: Int(steps),
        //     distance: distance,
        //     activeEnergyBurned: energy
        // )

        // Stub: Return simulated health metrics
        print("❤️ [HealthReader] Getting current metrics (stub)")

        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        return HealthMetrics(
            heartRate: Double.random(in: 60...100),
            heartRateVariability: Double.random(in: 20...80),
            steps: Int.random(in: 1000...15000),
            distance: Double.random(in: 500...10000),
            activeEnergyBurned: Double.random(in: 100...500),
            restingEnergyBurned: Double.random(in: 1200...1800),
            standHours: Int.random(in: 6...12),
            exerciseMinutes: Int.random(in: 0...90),
            flightsClimbed: Int.random(in: 0...20),
            vo2Max: Double.random(in: 30...50)
        )
    }

    func startMonitoring() async throws {
        guard !isMonitoring else {
            throw SensorAggregatorError.alreadyMonitoring
        }

        // TODO: Start HealthKit observers
        // Set up observers for real-time updates

        isMonitoring = true
        print("❤️ [HealthReader] Started monitoring")
    }

    func stopMonitoring() async {
        guard isMonitoring else { return }

        // TODO: Stop HealthKit observers

        isMonitoring = false
        print("❤️ [HealthReader] Stopped monitoring")
    }

    // TODO: Helper methods for HealthKit queries
    // private func queryMostRecentSample(for identifier: HKQuantityTypeIdentifier) async throws -> Double? {
    //     // Implementation
    // }
    //
    // private func queryTodaySum(for identifier: HKQuantityTypeIdentifier) async throws -> Double {
    //     // Implementation
    // }
}

// MARK: - Device State Reader Implementation

/// Device state reader using UIDevice and ProcessInfo
class DeviceStateReader: DeviceStateReaderProtocol {

    private(set) var isMonitoring = false

    init() {
        // TODO: Enable battery monitoring
        // UIDevice.current.isBatteryMonitoringEnabled = true
        print("📱 [DeviceStateReader] Initialized (stub mode)")
    }

    func getCurrentState() async -> DeviceState {
        // TODO: Read actual device state
        // let battery = UIDevice.current.batteryLevel
        // let batteryState = mapBatteryState(UIDevice.current.batteryState)
        // let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        // let thermalState = mapThermalState(ProcessInfo.processInfo.thermalState)
        // let networkType = detectNetworkType()
        // let diskSpace = getAvailableDiskSpace()
        // let memoryUsage = getMemoryUsage()

        // Stub: Return simulated device state
        print("📱 [DeviceStateReader] Getting current state (stub)")

        return DeviceState(
            batteryLevel: Float.random(in: 0.5...1.0),
            batteryState: .unplugged,
            lowPowerMode: false,
            thermalState: .nominal,
            networkType: .wifi,
            diskSpaceAvailable: 50_000_000_000, // 50GB
            memoryUsage: Double.random(in: 0.3...0.7)
        )
    }

    func startMonitoring() async {
        guard !isMonitoring else { return }

        // TODO: Register for battery state notifications
        // NotificationCenter.default.addObserver(
        //     self,
        //     selector: #selector(batteryLevelChanged),
        //     name: UIDevice.batteryLevelDidChangeNotification,
        //     object: nil
        // )

        isMonitoring = true
        print("📱 [DeviceStateReader] Started monitoring")
    }

    func stopMonitoring() async {
        guard isMonitoring else { return }

        // TODO: Unregister notifications
        // NotificationCenter.default.removeObserver(self)

        isMonitoring = false
        print("📱 [DeviceStateReader] Stopped monitoring")
    }

    // TODO: Helper methods
    // private func mapBatteryState(_ state: UIDevice.BatteryState) -> DeviceState.BatteryState {
    //     switch state {
    //     case .unknown: return .unknown
    //     case .unplugged: return .unplugged
    //     case .charging: return .charging
    //     case .full: return .full
    //     @unknown default: return .unknown
    //     }
    // }
    //
    // private func mapThermalState(_ state: ProcessInfo.ThermalState) -> DeviceState.ThermalState {
    //     switch state {
    //     case .nominal: return .nominal
    //     case .fair: return .fair
    //     case .serious: return .serious
    //     case .critical: return .critical
    //     @unknown default: return .nominal
    //     }
    // }
}

// MARK: - Sensor Aggregator

/// Main sensor aggregator that unifies all sensor inputs
class SensorAggregator {

    // MARK: - Configuration

    struct Configuration {
        let enableLocation: Bool
        let enableMotion: Bool
        let enableHealth: Bool
        let enableDeviceState: Bool
        let timeout: TimeInterval

        static let `default` = Configuration(
            enableLocation: true,
            enableMotion: true,
            enableHealth: true,
            enableDeviceState: true,
            timeout: 5.0
        )

        static let privacyFocused = Configuration(
            enableLocation: false,
            enableMotion: false,
            enableHealth: false,
            enableDeviceState: true,
            timeout: 2.0
        )
    }

    // MARK: - Properties

    static let shared = SensorAggregator()

    private let config: Configuration
    private let locationReader: LocationReaderProtocol
    private let motionReader: MotionReaderProtocol
    private let healthReader: HealthReaderProtocol
    private let deviceStateReader: DeviceStateReaderProtocol

    private(set) var isMonitoring = false
    private var lastSnapshot: SensorSnapshot?

    // MARK: - Initialization

    init(
        config: Configuration = .default,
        locationReader: LocationReaderProtocol? = nil,
        motionReader: MotionReaderProtocol? = nil,
        healthReader: HealthReaderProtocol? = nil,
        deviceStateReader: DeviceStateReaderProtocol? = nil
    ) {
        self.config = config
        self.locationReader = locationReader ?? LocationReader()
        self.motionReader = motionReader ?? MotionReader()
        self.healthReader = healthReader ?? HealthReader()
        self.deviceStateReader = deviceStateReader ?? DeviceStateReader()

        print("🎯 [SensorAggregator] Initialized")
    }

    // MARK: - Public API

    /// Get current snapshot from all enabled sensors
    /// - Returns: Complete sensor snapshot
    /// - Throws: SensorAggregatorError if critical sensors fail
    func getCurrentSnapshot() async throws -> SensorSnapshot {
        let startTime = Date()
        print("\n📡 [SensorAggregator] Collecting sensor snapshot...")

        // Collect data from all sensors in parallel
        async let location = fetchLocation()
        async let activity = fetchActivity()
        async let health = fetchHealth()
        async let device = fetchDeviceState()

        // Wait for collection with timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.config.timeout * 1_000_000_000))
                throw SensorAggregatorError.timeout
            }

            // Add collection task
            group.addTask {
                _ = try await (location, activity, health, device)
            }

            // Wait for first to complete
            try await group.next()
            group.cancelAll()
        }

        // Build snapshot after task group completes
        let loc = try? await location
        let act = try? await activity
        let hlt = try? await health
        let dev = await device

        let snapshot = SensorSnapshot(
            timestamp: Date(),
            location: loc,
            activity: act,
            healthMetrics: hlt,
            deviceState: dev
        )

        let duration = Date().timeIntervalSince(startTime)
        lastSnapshot = snapshot

        print("✅ [SensorAggregator] Snapshot collected in \(String(format: "%.2f", duration))s")
        print("   \(snapshot.summary)")

        return snapshot
    }

    /// Start monitoring all enabled sensors
    /// - Throws: SensorAggregatorError if already monitoring
    func startMonitoring() async throws {
        guard !isMonitoring else {
            throw SensorAggregatorError.alreadyMonitoring
        }

        print("🎯 [SensorAggregator] Starting sensor monitoring...")

        // Start each sensor reader
        if config.enableLocation {
            try? await locationReader.startMonitoring()
        }

        if config.enableMotion {
            try? await motionReader.startMonitoring()
        }

        if config.enableHealth {
            try? await healthReader.startMonitoring()
        }

        if config.enableDeviceState {
            await deviceStateReader.startMonitoring()
        }

        isMonitoring = true
        print("✅ [SensorAggregator] Monitoring started")
    }

    /// Stop monitoring all sensors
    func stopMonitoring() async {
        guard isMonitoring else { return }

        print("🎯 [SensorAggregator] Stopping sensor monitoring...")

        await locationReader.stopMonitoring()
        await motionReader.stopMonitoring()
        await healthReader.stopMonitoring()
        await deviceStateReader.stopMonitoring()

        isMonitoring = false
        print("✅ [SensorAggregator] Monitoring stopped")
    }

    /// Request necessary permissions for sensors
    func requestPermissions() async throws {
        print("🔐 [SensorAggregator] Requesting sensor permissions...")

        if config.enableHealth {
            try await healthReader.requestAuthorization()
        }

        // TODO: Request location permissions
        // if config.enableLocation {
        //     // CLLocationManager authorization request
        // }

        // TODO: Request motion permissions
        // if config.enableMotion {
        //     // CMMotionActivityManager authorization request
        // }

        print("✅ [SensorAggregator] Permissions requested")
    }

    /// Get the last cached snapshot (may be stale)
    func getLastSnapshot() -> SensorSnapshot? {
        return lastSnapshot
    }

    // MARK: - Private Methods

    private func fetchLocation() async throws -> LocationSnapshot? {
        guard config.enableLocation else { return nil }

        do {
            return try await locationReader.getCurrentLocation()
        } catch {
            print("⚠️ [SensorAggregator] Location fetch failed: \(error)")
            return nil
        }
    }

    private func fetchActivity() async throws -> ActivityType? {
        guard config.enableMotion else { return nil }

        do {
            return try await motionReader.getCurrentActivity()
        } catch {
            print("⚠️ [SensorAggregator] Activity fetch failed: \(error)")
            return nil
        }
    }

    private func fetchHealth() async throws -> HealthMetrics? {
        guard config.enableHealth else { return nil }

        do {
            return try await healthReader.getCurrentMetrics()
        } catch {
            print("⚠️ [SensorAggregator] Health fetch failed: \(error)")
            return nil
        }
    }

    private func fetchDeviceState() async -> DeviceState? {
        guard config.enableDeviceState else { return nil }

        return await deviceStateReader.getCurrentState()
    }
}

// MARK: - Example Usage

/*
 // Initialize sensor aggregator
 let aggregator = SensorAggregator.shared

 // Request permissions first
 try await aggregator.requestPermissions()

 // Get a snapshot
 let snapshot = try await aggregator.getCurrentSnapshot()
 print(snapshot.summary)

 // Access individual components
 if let location = snapshot.location {
     print("📍 At: \(location.placeName ?? "Unknown")")
 }

 if let activity = snapshot.activity {
     print("🏃 Activity: \(activity.description)")
 }

 if let health = snapshot.healthMetrics {
     print("❤️ HR: \(health.heartRate ?? 0) bpm")
 }

 // Start continuous monitoring
 try await aggregator.startMonitoring()

 // Later, stop monitoring
 await aggregator.stopMonitoring()

 // Custom configuration
 let customConfig = SensorAggregator.Configuration(
     enableLocation: true,
     enableMotion: false,
     enableHealth: false,
     enableDeviceState: true,
     timeout: 3.0
 )

 let customAggregator = SensorAggregator(config: customConfig)
 */
