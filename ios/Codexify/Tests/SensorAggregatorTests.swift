//
//  SensorAggregatorTests.swift
//  Codexify Tests
//
//  Comprehensive test suite for SensorAggregator
//

import XCTest
@testable import Codexify

// MARK: - Mock Implementations

/// Mock location reader for testing
class MockLocationReader: LocationReaderProtocol {
    var isMonitoring: Bool = false
    var shouldThrowError: Bool = false
    var mockLocation: LocationSnapshot?
    var delay: TimeInterval = 0

    func getCurrentLocation() async throws -> LocationSnapshot? {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldThrowError {
            throw SensorAggregatorError.locationPermissionDenied
        }

        return mockLocation
    }

    func startMonitoring() async throws {
        if isMonitoring {
            throw SensorAggregatorError.alreadyMonitoring
        }
        isMonitoring = true
    }

    func stopMonitoring() async {
        isMonitoring = false
    }
}

/// Mock motion reader for testing
class MockMotionReader: MotionReaderProtocol {
    var isMonitoring: Bool = false
    var shouldThrowError: Bool = false
    var mockActivity: ActivityType?
    var delay: TimeInterval = 0

    func getCurrentActivity() async throws -> ActivityType? {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldThrowError {
            throw SensorAggregatorError.motionPermissionDenied
        }

        return mockActivity
    }

    func startMonitoring() async throws {
        if isMonitoring {
            throw SensorAggregatorError.alreadyMonitoring
        }
        isMonitoring = true
    }

    func stopMonitoring() async {
        isMonitoring = false
    }
}

/// Mock health reader for testing
class MockHealthReader: HealthReaderProtocol {
    var isMonitoring: Bool = false
    var shouldThrowError: Bool = false
    var mockMetrics: HealthMetrics?
    var delay: TimeInterval = 0
    var hasAuthorization: Bool = false

    func getCurrentMetrics() async throws -> HealthMetrics? {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldThrowError {
            throw SensorAggregatorError.healthPermissionDenied
        }

        return mockMetrics
    }

    func requestAuthorization() async throws {
        hasAuthorization = true
    }

    func startMonitoring() async throws {
        if isMonitoring {
            throw SensorAggregatorError.alreadyMonitoring
        }
        isMonitoring = true
    }

    func stopMonitoring() async {
        isMonitoring = false
    }
}

/// Mock device state reader for testing
class MockDeviceStateReader: DeviceStateReaderProtocol {
    var isMonitoring: Bool = false
    var mockState: DeviceState?
    var delay: TimeInterval = 0

    func getCurrentState() async -> DeviceState {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return mockState ?? DeviceState(
            batteryLevel: 0.8,
            batteryState: .unplugged,
            lowPowerMode: false,
            thermalState: .nominal,
            networkType: .wifi
        )
    }

    func startMonitoring() async {
        isMonitoring = true
    }

    func stopMonitoring() async {
        isMonitoring = false
    }
}

// MARK: - Test Suite

class SensorAggregatorTests: XCTestCase {

    var mockLocationReader: MockLocationReader!
    var mockMotionReader: MockMotionReader!
    var mockHealthReader: MockHealthReader!
    var mockDeviceStateReader: MockDeviceStateReader!
    var aggregator: SensorAggregator!

    override func setUp() {
        super.setUp()

        // Initialize mocks
        mockLocationReader = MockLocationReader()
        mockMotionReader = MockMotionReader()
        mockHealthReader = MockHealthReader()
        mockDeviceStateReader = MockDeviceStateReader()

        // Configure default mock data
        mockLocationReader.mockLocation = LocationSnapshot(
            latitude: 37.7749,
            longitude: -122.4194,
            horizontalAccuracy: 10.0,
            placeName: "San Francisco"
        )

        mockMotionReader.mockActivity = .walking

        mockHealthReader.mockMetrics = HealthMetrics(
            heartRate: 72.0,
            steps: 5000,
            distance: 3000.0
        )

        mockDeviceStateReader.mockState = DeviceState(
            batteryLevel: 0.75,
            batteryState: .unplugged,
            lowPowerMode: false,
            thermalState: .nominal,
            networkType: .wifi
        )

        // Create aggregator with mocks
        aggregator = SensorAggregator(
            locationReader: mockLocationReader,
            motionReader: mockMotionReader,
            healthReader: mockHealthReader,
            deviceStateReader: mockDeviceStateReader
        )
    }

    override func tearDown() {
        mockLocationReader = nil
        mockMotionReader = nil
        mockHealthReader = nil
        mockDeviceStateReader = nil
        aggregator = nil

        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func testGetCurrentSnapshot_ReturnsCompleteSnapshot() async throws {
        // Given: All sensors configured with mock data

        // When: Getting current snapshot
        let snapshot = try await aggregator.getCurrentSnapshot()

        // Then: Snapshot should contain all data
        XCTAssertNotNil(snapshot.location, "Location should be present")
        XCTAssertNotNil(snapshot.activity, "Activity should be present")
        XCTAssertNotNil(snapshot.healthMetrics, "Health metrics should be present")
        XCTAssertNotNil(snapshot.deviceState, "Device state should be present")

        XCTAssertEqual(snapshot.location?.latitude, 37.7749, accuracy: 0.001)
        XCTAssertEqual(snapshot.location?.longitude, -122.4194, accuracy: 0.001)
        XCTAssertEqual(snapshot.activity, .walking)
        XCTAssertEqual(snapshot.healthMetrics?.heartRate, 72.0)
        XCTAssertEqual(snapshot.deviceState?.batteryLevel, 0.75)
    }

    func testGetCurrentSnapshot_WithNilValues() async throws {
        // Given: Some sensors return nil
        mockLocationReader.mockLocation = nil
        mockMotionReader.mockActivity = nil
        mockHealthReader.mockMetrics = nil

        // When: Getting snapshot
        let snapshot = try await aggregator.getCurrentSnapshot()

        // Then: Should still return valid snapshot with available data
        XCTAssertNil(snapshot.location)
        XCTAssertNil(snapshot.activity)
        XCTAssertNil(snapshot.healthMetrics)
        XCTAssertNotNil(snapshot.deviceState) // Device state should always be available
    }

    func testSnapshotHasData() {
        // Given: Snapshots with different data availability
        let emptySnapshot = SensorSnapshot()
        let fullSnapshot = SensorSnapshot(
            location: LocationSnapshot(latitude: 0, longitude: 0, horizontalAccuracy: 10),
            activity: .walking,
            healthMetrics: HealthMetrics(heartRate: 70),
            deviceState: DeviceState()
        )

        // Then: hasData should reflect actual data
        XCTAssertFalse(emptySnapshot.hasData)
        XCTAssertTrue(fullSnapshot.hasData)
    }

    func testSnapshotSummary() {
        // Given: Snapshot with data
        let snapshot = SensorSnapshot(
            location: LocationSnapshot(
                latitude: 37.7749,
                longitude: -122.4194,
                horizontalAccuracy: 10,
                placeName: "SF"
            ),
            activity: .walking,
            healthMetrics: HealthMetrics(heartRate: 75, steps: 10000),
            deviceState: DeviceState(batteryLevel: 0.8)
        )

        // When: Getting summary
        let summary = snapshot.summary

        // Then: Should contain key information
        XCTAssertTrue(summary.contains("SF"))
        XCTAssertTrue(summary.contains("75 bpm"))
        XCTAssertTrue(summary.contains("10000 steps"))
        XCTAssertTrue(summary.contains("80%"))
    }

    // MARK: - Monitoring Tests

    func testStartMonitoring_Success() async throws {
        // Given: Aggregator not monitoring
        XCTAssertFalse(aggregator.isMonitoring)

        // When: Starting monitoring
        try await aggregator.startMonitoring()

        // Then: All readers should be monitoring
        XCTAssertTrue(aggregator.isMonitoring)
        XCTAssertTrue(mockLocationReader.isMonitoring)
        XCTAssertTrue(mockMotionReader.isMonitoring)
        XCTAssertTrue(mockHealthReader.isMonitoring)
        XCTAssertTrue(mockDeviceStateReader.isMonitoring)
    }

    func testStartMonitoring_WhenAlreadyMonitoring_ThrowsError() async {
        // Given: Already monitoring
        try? await aggregator.startMonitoring()

        // When: Starting again
        // Then: Should throw error
        do {
            try await aggregator.startMonitoring()
            XCTFail("Should have thrown alreadyMonitoring error")
        } catch SensorAggregatorError.alreadyMonitoring {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testStopMonitoring_Success() async throws {
        // Given: Monitoring active
        try await aggregator.startMonitoring()
        XCTAssertTrue(aggregator.isMonitoring)

        // When: Stopping monitoring
        await aggregator.stopMonitoring()

        // Then: All readers should stop
        XCTAssertFalse(aggregator.isMonitoring)
        XCTAssertFalse(mockLocationReader.isMonitoring)
        XCTAssertFalse(mockMotionReader.isMonitoring)
        XCTAssertFalse(mockHealthReader.isMonitoring)
        XCTAssertFalse(mockDeviceStateReader.isMonitoring)
    }

    // MARK: - Error Handling Tests

    func testGetCurrentSnapshot_WithLocationError_ContinuesGracefully() async throws {
        // Given: Location reader throws error
        mockLocationReader.shouldThrowError = true

        // When: Getting snapshot
        let snapshot = try await aggregator.getCurrentSnapshot()

        // Then: Should still get other sensor data
        XCTAssertNil(snapshot.location)
        XCTAssertNotNil(snapshot.activity)
        XCTAssertNotNil(snapshot.healthMetrics)
        XCTAssertNotNil(snapshot.deviceState)
    }

    func testGetCurrentSnapshot_WithMultipleErrors_ReturnsPartialData() async throws {
        // Given: Multiple sensors fail
        mockLocationReader.shouldThrowError = true
        mockMotionReader.shouldThrowError = true

        // When: Getting snapshot
        let snapshot = try await aggregator.getCurrentSnapshot()

        // Then: Should still get available data
        XCTAssertNil(snapshot.location)
        XCTAssertNil(snapshot.activity)
        XCTAssertNotNil(snapshot.healthMetrics)
        XCTAssertNotNil(snapshot.deviceState)
    }

    // MARK: - Timeout Tests

    func testGetCurrentSnapshot_Timeout() async {
        // Given: Sensor with very long delay
        mockLocationReader.delay = 10.0 // 10 seconds

        // Custom config with short timeout
        let config = SensorAggregator.Configuration(
            enableLocation: true,
            enableMotion: true,
            enableHealth: true,
            enableDeviceState: true,
            timeout: 0.5 // 500ms
        )

        let timeoutAggregator = SensorAggregator(
            config: config,
            locationReader: mockLocationReader,
            motionReader: mockMotionReader,
            healthReader: mockHealthReader,
            deviceStateReader: mockDeviceStateReader
        )

        // When: Getting snapshot with timeout
        do {
            _ = try await timeoutAggregator.getCurrentSnapshot()
            XCTFail("Should have timed out")
        } catch SensorAggregatorError.timeout {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Async Integration Tests

    func testConcurrentSnapshotRequests() async throws {
        // Given: Multiple concurrent requests

        // When: Making multiple snapshot requests simultaneously
        async let snapshot1 = aggregator.getCurrentSnapshot()
        async let snapshot2 = aggregator.getCurrentSnapshot()
        async let snapshot3 = aggregator.getCurrentSnapshot()

        let results = try await [snapshot1, snapshot2, snapshot3]

        // Then: All should succeed
        XCTAssertEqual(results.count, 3)
        for snapshot in results {
            XCTAssertNotNil(snapshot.location)
            XCTAssertNotNil(snapshot.activity)
        }
    }

    func testSnapshotTimestampIsRecent() async throws {
        // Given: Getting a snapshot
        let beforeTime = Date()

        // When: Getting snapshot
        let snapshot = try await aggregator.getCurrentSnapshot()

        let afterTime = Date()

        // Then: Timestamp should be between before and after
        XCTAssertGreaterThanOrEqual(snapshot.timestamp, beforeTime)
        XCTAssertLessThanOrEqual(snapshot.timestamp, afterTime)
    }

    // MARK: - Configuration Tests

    func testCustomConfiguration_DisabledSensors() async throws {
        // Given: Config with some sensors disabled
        let config = SensorAggregator.Configuration(
            enableLocation: false,
            enableMotion: false,
            enableHealth: true,
            enableDeviceState: true,
            timeout: 5.0
        )

        let customAggregator = SensorAggregator(
            config: config,
            locationReader: mockLocationReader,
            motionReader: mockMotionReader,
            healthReader: mockHealthReader,
            deviceStateReader: mockDeviceStateReader
        )

        // When: Getting snapshot
        let snapshot = try await customAggregator.getCurrentSnapshot()

        // Then: Disabled sensors should be nil
        XCTAssertNil(snapshot.location)
        XCTAssertNil(snapshot.activity)
        XCTAssertNotNil(snapshot.healthMetrics)
        XCTAssertNotNil(snapshot.deviceState)
    }

    func testPrivacyFocusedConfiguration() async throws {
        // Given: Privacy-focused config
        let customAggregator = SensorAggregator(
            config: .privacyFocused,
            locationReader: mockLocationReader,
            motionReader: mockMotionReader,
            healthReader: mockHealthReader,
            deviceStateReader: mockDeviceStateReader
        )

        // When: Getting snapshot
        let snapshot = try await customAggregator.getCurrentSnapshot()

        // Then: Only device state should be available
        XCTAssertNil(snapshot.location)
        XCTAssertNil(snapshot.activity)
        XCTAssertNil(snapshot.healthMetrics)
        XCTAssertNotNil(snapshot.deviceState)
    }

    // MARK: - Data Model Tests

    func testLocationSnapshot_DistanceCalculation() {
        // Given: Two locations
        let sf = LocationSnapshot(
            latitude: 37.7749,
            longitude: -122.4194,
            horizontalAccuracy: 10.0
        )

        let oakland = LocationSnapshot(
            latitude: 37.8044,
            longitude: -122.2712,
            horizontalAccuracy: 10.0
        )

        // When: Calculating distance
        let distance = sf.distance(to: oakland)

        // Then: Should be approximately 13km (13000m)
        XCTAssertGreaterThan(distance, 12000)
        XCTAssertLessThan(distance, 14000)
    }

    func testLocationSnapshot_SameLocation_ZeroDistance() {
        // Given: Same location
        let location = LocationSnapshot(
            latitude: 37.7749,
            longitude: -122.4194,
            horizontalAccuracy: 10.0
        )

        // When: Calculating distance to itself
        let distance = location.distance(to: location)

        // Then: Should be zero
        XCTAssertEqual(distance, 0, accuracy: 0.1)
    }

    func testActivityType_Emoji() {
        // Given: Different activity types
        let activities: [(ActivityType, String)] = [
            (.walking, "🚶"),
            (.running, "🏃"),
            (.cycling, "🚴"),
            (.automotive, "🚗"),
            (.stationary, "🧍")
        ]

        // Then: Each should have correct emoji
        for (activity, expectedEmoji) in activities {
            XCTAssertEqual(activity.emoji, expectedEmoji)
        }
    }

    func testHealthMetrics_HasData() {
        // Given: Different health metric configurations
        let emptyMetrics = HealthMetrics()
        let metricsWithHR = HealthMetrics(heartRate: 72.0)
        let metricsWithSteps = HealthMetrics(steps: 5000)

        // Then: hasData should be correct
        XCTAssertFalse(emptyMetrics.hasData)
        XCTAssertTrue(metricsWithHR.hasData)
        XCTAssertTrue(metricsWithSteps.hasData)
    }

    func testDeviceState_IsOptimalForCompute() {
        // Given: Different device states
        let goodState = DeviceState(
            batteryLevel: 0.8,
            batteryState: .unplugged,
            lowPowerMode: false,
            thermalState: .nominal
        )

        let lowBattery = DeviceState(
            batteryLevel: 0.1,
            batteryState: .unplugged,
            lowPowerMode: false,
            thermalState: .nominal
        )

        let overheating = DeviceState(
            batteryLevel: 0.8,
            batteryState: .unplugged,
            lowPowerMode: false,
            thermalState: .critical
        )

        let lowPowerMode = DeviceState(
            batteryLevel: 0.8,
            batteryState: .unplugged,
            lowPowerMode: true,
            thermalState: .nominal
        )

        let charging = DeviceState(
            batteryLevel: 0.1,
            batteryState: .charging,
            lowPowerMode: false,
            thermalState: .nominal
        )

        // Then: isOptimalForCompute should be correct
        XCTAssertTrue(goodState.isOptimalForCompute)
        XCTAssertFalse(lowBattery.isOptimalForCompute)
        XCTAssertFalse(overheating.isOptimalForCompute)
        XCTAssertFalse(lowPowerMode.isOptimalForCompute)
        XCTAssertTrue(charging.isOptimalForCompute) // Charging overrides low battery
    }

    // MARK: - Caching Tests

    func testGetLastSnapshot_ReturnsNilInitially() {
        // Given: New aggregator
        // Then: Last snapshot should be nil
        XCTAssertNil(aggregator.getLastSnapshot())
    }

    func testGetLastSnapshot_ReturnsCachedSnapshot() async throws {
        // Given: Getting a snapshot
        let snapshot = try await aggregator.getCurrentSnapshot()

        // When: Getting last snapshot
        let cached = aggregator.getLastSnapshot()

        // Then: Should return the same snapshot
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.timestamp, snapshot.timestamp)
    }

    // MARK: - Performance Tests

    func testPerformance_GetCurrentSnapshot() {
        // Measure performance of snapshot collection
        measure {
            let expectation = XCTestExpectation(description: "Snapshot collected")

            Task {
                _ = try? await aggregator.getCurrentSnapshot()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testPerformance_ConcurrentSnapshots() {
        // Measure performance of concurrent snapshot requests
        measure {
            let expectation = XCTestExpectation(description: "All snapshots collected")
            expectation.expectedFulfillmentCount = 10

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0..<10 {
                        group.addTask {
                            _ = try? await self.aggregator.getCurrentSnapshot()
                            expectation.fulfill()
                        }
                    }
                }
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Integration Tests

    func testFullWorkflow_RequestPermissions_StartMonitoring_GetSnapshot() async throws {
        // Given: Fresh aggregator
        XCTAssertFalse(aggregator.isMonitoring)

        // When: Following full workflow
        // 1. Request permissions
        try await aggregator.requestPermissions()

        // 2. Start monitoring
        try await aggregator.startMonitoring()
        XCTAssertTrue(aggregator.isMonitoring)

        // 3. Get snapshot
        let snapshot = try await aggregator.getCurrentSnapshot()
        XCTAssertNotNil(snapshot)

        // 4. Get cached snapshot
        let cached = aggregator.getLastSnapshot()
        XCTAssertNotNil(cached)

        // 5. Stop monitoring
        await aggregator.stopMonitoring()
        XCTAssertFalse(aggregator.isMonitoring)

        // Then: All steps should complete successfully
    }

    func testRapidStartStopCycles() async throws {
        // Given: Multiple rapid start/stop cycles
        for _ in 0..<5 {
            // Start
            try await aggregator.startMonitoring()
            XCTAssertTrue(aggregator.isMonitoring)

            // Get snapshot while monitoring
            _ = try await aggregator.getCurrentSnapshot()

            // Stop
            await aggregator.stopMonitoring()
            XCTAssertFalse(aggregator.isMonitoring)
        }

        // Then: Should handle cycles without issues
    }

    // MARK: - Edge Cases

    func testEmptySnapshot() {
        // Given: Completely empty snapshot
        let empty = SensorSnapshot()

        // Then: Should handle gracefully
        XCTAssertFalse(empty.hasData)
        XCTAssertEqual(empty.summary, "No sensor data")
    }

    func testPartialHealthMetrics() {
        // Given: Partial health metrics
        let partial = HealthMetrics(heartRate: 72.0)

        // Then: Should have data but missing fields should be nil
        XCTAssertTrue(partial.hasData)
        XCTAssertNotNil(partial.heartRate)
        XCTAssertNil(partial.steps)
        XCTAssertNil(partial.distance)
    }

    func testAllSensorsDisabled() async throws {
        // Given: All sensors disabled
        let config = SensorAggregator.Configuration(
            enableLocation: false,
            enableMotion: false,
            enableHealth: false,
            enableDeviceState: false,
            timeout: 5.0
        )

        let disabledAggregator = SensorAggregator(
            config: config,
            locationReader: mockLocationReader,
            motionReader: mockMotionReader,
            healthReader: mockHealthReader,
            deviceStateReader: mockDeviceStateReader
        )

        // When: Getting snapshot
        let snapshot = try await disabledAggregator.getCurrentSnapshot()

        // Then: Should return empty snapshot
        XCTAssertNil(snapshot.location)
        XCTAssertNil(snapshot.activity)
        XCTAssertNil(snapshot.healthMetrics)
        XCTAssertNil(snapshot.deviceState)
        XCTAssertFalse(snapshot.hasData)
    }
}

// MARK: - Custom XCTestCase Extensions

extension XCTestCase {
    /// Helper to wait for async operations with timeout
    func waitForAsync(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NSError(domain: "Timeout", code: -1)
            }

            try await group.next()
            group.cancelAll()
        }
    }
}

// MARK: - Performance Test Suggestions

/*
 Additional performance tests to consider:

 1. Continuous Monitoring Performance:
    - Test CPU and memory usage during extended monitoring
    - Measure battery impact over time
    - Test with real device sensors if available

 2. Stress Tests:
    - Very high frequency snapshot requests
    - Long-running monitoring sessions (hours)
    - Rapid enable/disable of individual sensors

 3. Memory Tests:
    - Check for memory leaks during monitoring
    - Test snapshot retention and cleanup
    - Verify no retain cycles in delegates

 4. Real-World Scenarios:
    - Background app monitoring
    - Interrupted monitoring (app backgrounded)
    - Low battery conditions
    - Poor GPS signal areas

 Example implementation:

 func testContinuousMonitoring_MemoryStability() {
     measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
         Task {
             try? await aggregator.startMonitoring()

             startMeasuring()

             // Collect snapshots for extended period
             for _ in 0..<100 {
                 _ = try? await aggregator.getCurrentSnapshot()
                 try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
             }

             stopMeasuring()

             await aggregator.stopMonitoring()
         }
     }
 }
 */
