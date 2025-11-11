//
//  SensorAggregatorExamples.swift
//  Codexify
//
//  Example usage scenarios for SensorAggregator
//

import Foundation
import SwiftUI

// MARK: - Example 1: Basic Sensor Snapshot

func example1_BasicSnapshot() async {
    print("\n========== Example 1: Basic Sensor Snapshot ==========\n")

    let aggregator = SensorAggregator.shared

    do {
        // Request permissions first
        try await aggregator.requestPermissions()

        // Get current snapshot
        let snapshot = try await aggregator.getCurrentSnapshot()

        // Print summary
        print("📊 Snapshot Summary:")
        print(snapshot.summary)
        print("\n")

        // Access individual components
        if let location = snapshot.location {
            print("📍 Location Details:")
            print("   Coordinates: \(location.latitude), \(location.longitude)")
            print("   Accuracy: ±\(location.horizontalAccuracy)m")
            print("   Place: \(location.placeName ?? "Unknown")")
            print("   Time: \(location.timestamp)")
        }

        if let activity = snapshot.activity {
            print("\n🏃 Activity: \(activity.description)")
        }

        if let health = snapshot.healthMetrics {
            print("\n❤️ Health Metrics:")
            if let hr = health.heartRate {
                print("   Heart Rate: \(Int(hr)) bpm")
            }
            if let steps = health.steps {
                print("   Steps: \(steps)")
            }
            if let distance = health.distance {
                print("   Distance: \(String(format: "%.1f", distance/1000))km")
            }
        }

        if let device = snapshot.deviceState {
            print("\n📱 Device State:")
            if let battery = device.batteryLevel {
                print("   Battery: \(Int(battery * 100))%")
            }
            print("   Power Mode: \(device.lowPowerMode ? "Low" : "Normal")")
            print("   Thermal: \(device.thermalState.rawValue)")
            print("   Network: \(device.networkType.rawValue)")
        }

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 2: Continuous Monitoring

func example2_ContinuousMonitoring() async {
    print("\n========== Example 2: Continuous Monitoring ==========\n")

    let aggregator = SensorAggregator.shared

    do {
        // Start monitoring
        print("🎯 Starting sensor monitoring...")
        try await aggregator.startMonitoring()

        // Simulate periodic snapshot collection
        for i in 1...5 {
            print("\n📸 Snapshot #\(i):")

            let snapshot = try await aggregator.getCurrentSnapshot()
            print(snapshot.summary)

            // Wait before next snapshot
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        // Stop monitoring
        print("\n⏸️ Stopping monitoring...")
        await aggregator.stopMonitoring()

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 3: Custom Configuration

func example3_CustomConfiguration() async {
    print("\n========== Example 3: Custom Configuration ==========\n")

    // Privacy-focused configuration
    print("🔒 Privacy-Focused Configuration:")
    let privacyAggregator = SensorAggregator(config: .privacyFocused)

    do {
        let snapshot = try await privacyAggregator.getCurrentSnapshot()
        print("   \(snapshot.summary)")
        print("   Location: \(snapshot.location == nil ? "Disabled" : "Enabled")")
        print("   Health: \(snapshot.healthMetrics == nil ? "Disabled" : "Enabled")")
    } catch {
        print("   Error: \(error)")
    }

    // Location-only configuration
    print("\n📍 Location-Only Configuration:")
    let locationConfig = SensorAggregator.Configuration(
        enableLocation: true,
        enableMotion: false,
        enableHealth: false,
        enableDeviceState: false,
        timeout: 3.0
    )

    let locationAggregator = SensorAggregator(config: locationConfig)

    do {
        let snapshot = try await locationAggregator.getCurrentSnapshot()
        print("   \(snapshot.summary)")
    } catch {
        print("   Error: \(error)")
    }

    // Performance-optimized configuration
    print("\n⚡ Performance-Optimized Configuration:")
    let perfConfig = SensorAggregator.Configuration(
        enableLocation: false,
        enableMotion: true,
        enableHealth: false,
        enableDeviceState: true,
        timeout: 1.0 // Fast timeout
    )

    let perfAggregator = SensorAggregator(config: perfConfig)

    do {
        let snapshot = try await perfAggregator.getCurrentSnapshot()
        print("   \(snapshot.summary)")
    } catch {
        print("   Error: \(error)")
    }
}

// MARK: - Example 4: Location Distance Tracking

func example4_LocationTracking() async {
    print("\n========== Example 4: Location Distance Tracking ==========\n")

    let aggregator = SensorAggregator.shared

    var previousLocation: LocationSnapshot?

    do {
        try await aggregator.startMonitoring()

        // Track movement over time
        for i in 1...10 {
            let snapshot = try await aggregator.getCurrentSnapshot()

            if let currentLocation = snapshot.location {
                print("📍 Update #\(i):")
                print("   Location: \(currentLocation.placeName ?? "Unknown")")

                if let previous = previousLocation {
                    let distance = previous.distance(to: currentLocation)
                    print("   Distance moved: \(String(format: "%.1f", distance))m")
                }

                previousLocation = currentLocation
            }

            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        }

        await aggregator.stopMonitoring()

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 5: Device State Monitoring

func example5_DeviceStateMonitoring() async {
    print("\n========== Example 5: Device State Monitoring ==========\n")

    let aggregator = SensorAggregator.shared

    do {
        let snapshot = try await aggregator.getCurrentSnapshot()

        if let device = snapshot.deviceState {
            print("📱 Device Analysis:")
            print("   Battery: \(Int((device.batteryLevel ?? 0) * 100))%")
            print("   Charging: \(device.batteryState == .charging ? "Yes" : "No")")
            print("   Low Power Mode: \(device.lowPowerMode ? "On" : "Off")")
            print("   Thermal State: \(device.thermalState.rawValue)")
            print("   Network: \(device.networkType.rawValue)")

            // Check if optimal for compute
            if device.isOptimalForCompute {
                print("\n✅ Device is optimal for intensive operations")
            } else {
                print("\n⚠️ Device may not be optimal for intensive operations")

                // Provide specific recommendations
                if let battery = device.batteryLevel, battery < 0.2 {
                    print("   - Battery is low (\(Int(battery * 100))%)")
                }
                if device.lowPowerMode {
                    print("   - Low Power Mode is enabled")
                }
                if device.thermalState == .serious || device.thermalState == .critical {
                    print("   - Device is overheating")
                }
            }
        }

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 6: Health Metrics Tracking

func example6_HealthMetricsTracking() async {
    print("\n========== Example 6: Health Metrics Tracking ==========\n")

    let aggregator = SensorAggregator.shared

    do {
        // Request health permissions
        try await aggregator.requestPermissions()

        let snapshot = try await aggregator.getCurrentSnapshot()

        if let health = snapshot.healthMetrics {
            print("❤️ Health Dashboard:")

            // Cardiovascular
            if let hr = health.heartRate {
                print("\n💓 Cardiovascular:")
                print("   Heart Rate: \(Int(hr)) bpm")

                if let hrv = health.heartRateVariability {
                    print("   HRV: \(Int(hrv)) ms")
                }

                if let vo2 = health.vo2Max {
                    print("   VO2 Max: \(String(format: "%.1f", vo2)) ml/kg/min")
                }
            }

            // Activity
            print("\n🏃 Activity:")
            if let steps = health.steps {
                print("   Steps: \(steps)")
            }
            if let distance = health.distance {
                print("   Distance: \(String(format: "%.2f", distance/1000))km")
            }
            if let flights = health.flightsClimbed {
                print("   Flights Climbed: \(flights)")
            }

            // Energy
            print("\n🔥 Energy:")
            if let active = health.activeEnergyBurned {
                print("   Active: \(Int(active)) kcal")
            }
            if let resting = health.restingEnergyBurned {
                print("   Resting: \(Int(resting)) kcal")
            }

            // Goals
            print("\n🎯 Daily Goals:")
            if let standHours = health.standHours {
                print("   Stand Hours: \(standHours)/12")
            }
            if let exercise = health.exerciseMinutes {
                print("   Exercise: \(exercise)/30 minutes")
            }

        } else {
            print("⚠️ Health data not available")
        }

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 7: Activity-Based Actions

func example7_ActivityBasedActions() async {
    print("\n========== Example 7: Activity-Based Actions ==========\n")

    let aggregator = SensorAggregator.shared

    do {
        try await aggregator.startMonitoring()

        // Monitor activity for 30 seconds
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < 30 {
            let snapshot = try await aggregator.getCurrentSnapshot()

            if let activity = snapshot.activity {
                print("\(activity.emoji) Detected: \(activity.rawValue)")

                // Take actions based on activity
                switch activity {
                case .stationary:
                    print("   → User is stationary, good time for notifications")

                case .walking:
                    print("   → User is walking, brief updates OK")

                case .running, .cycling:
                    print("   → User is exercising, minimize interruptions")

                case .automotive:
                    print("   → User is driving, DO NOT DISTURB")

                case .unknown:
                    print("   → Activity unknown, use default behavior")
                }
            }

            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }

        await aggregator.stopMonitoring()

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 8: Context-Aware LLM Prompts

func example8_ContextAwareLLMPrompts() async {
    print("\n========== Example 8: Context-Aware LLM Prompts ==========\n")

    let aggregator = SensorAggregator.shared

    do {
        let snapshot = try await aggregator.getCurrentSnapshot()

        // Build context-enriched prompt
        var context = "Current Context:\n"

        if let location = snapshot.location {
            context += "- Location: \(location.placeName ?? "Unknown location")\n"
        }

        if let activity = snapshot.activity {
            context += "- Activity: \(activity.rawValue)\n"
        }

        if let health = snapshot.healthMetrics {
            if let hr = health.heartRate {
                context += "- Heart Rate: \(Int(hr)) bpm\n"
            }
        }

        if let device = snapshot.deviceState {
            if let battery = device.batteryLevel {
                context += "- Battery: \(Int(battery * 100))%\n"
            }
            context += "- Network: \(device.networkType.rawValue)\n"
        }

        context += "\nUser Query: Find nearby coffee shops\n\n"
        context += "Please provide recommendations considering the above context."

        print("🤖 LLM Prompt with Context:\n")
        print(context)

        // This would be sent to ModelRouter
        // let response = try await modelRouter.routeRequest(context)

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 9: SwiftUI Integration

struct SensorDashboardView: View {
    @StateObject private var viewModel = SensorDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Sensor Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    Button(viewModel.isMonitoring ? "Stop" : "Start") {
                        Task {
                            if viewModel.isMonitoring {
                                await viewModel.stopMonitoring()
                            } else {
                                try? await viewModel.startMonitoring()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                // Summary
                if let snapshot = viewModel.currentSnapshot {
                    Text(snapshot.summary)
                        .font(.headline)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                // Location Card
                if let location = viewModel.currentSnapshot?.location {
                    SensorCardView(
                        icon: "location.fill",
                        title: "Location",
                        content: location.placeName ?? "Unknown"
                    )
                }

                // Activity Card
                if let activity = viewModel.currentSnapshot?.activity {
                    SensorCardView(
                        icon: "figure.walk",
                        title: "Activity",
                        content: activity.description
                    )
                }

                // Health Card
                if let health = viewModel.currentSnapshot?.healthMetrics {
                    VStack(alignment: .leading) {
                        if let hr = health.heartRate {
                            SensorCardView(
                                icon: "heart.fill",
                                title: "Heart Rate",
                                content: "\(Int(hr)) bpm"
                            )
                        }

                        if let steps = health.steps {
                            SensorCardView(
                                icon: "figure.walk.circle",
                                title: "Steps",
                                content: "\(steps)"
                            )
                        }
                    }
                }

                // Device Card
                if let device = viewModel.currentSnapshot?.deviceState {
                    VStack(alignment: .leading) {
                        if let battery = device.batteryLevel {
                            SensorCardView(
                                icon: "battery.100",
                                title: "Battery",
                                content: "\(Int(battery * 100))%",
                                color: battery > 0.2 ? .green : .red
                            )
                        }

                        SensorCardView(
                            icon: "network",
                            title: "Network",
                            content: device.networkType.rawValue.capitalized
                        )
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            Task {
                await viewModel.refreshSnapshot()
            }
        }
        .refreshable {
            await viewModel.refreshSnapshot()
        }
    }
}

struct SensorCardView: View {
    let icon: String
    let title: String
    let content: String
    var color: Color = .blue

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 50)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(content)
                    .font(.headline)
            }

            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

@MainActor
class SensorDashboardViewModel: ObservableObject {
    @Published var currentSnapshot: SensorSnapshot?
    @Published var isMonitoring = false
    @Published var error: String?

    private let aggregator = SensorAggregator.shared
    private var monitoringTask: Task<Void, Never>?

    func startMonitoring() async throws {
        try await aggregator.startMonitoring()
        isMonitoring = true

        // Periodically refresh
        monitoringTask = Task {
            while !Task.isCancelled {
                await refreshSnapshot()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }

    func stopMonitoring() async {
        await aggregator.stopMonitoring()
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func refreshSnapshot() async {
        do {
            currentSnapshot = try await aggregator.getCurrentSnapshot()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Example 10: Cached Snapshots

func example10_CachedSnapshots() async {
    print("\n========== Example 10: Cached Snapshots ==========\n")

    let aggregator = SensorAggregator.shared

    do {
        // Check for cached snapshot
        if let cached = aggregator.getLastSnapshot() {
            let age = Date().timeIntervalSince(cached.timestamp)
            print("📦 Found cached snapshot (\(String(format: "%.1f", age))s old)")
            print("   \(cached.summary)")

            if age < 60 {
                print("   → Using cached snapshot (fresh)")
            } else {
                print("   → Refreshing snapshot (stale)")
            }
        } else {
            print("📦 No cached snapshot available")
        }

        // Get fresh snapshot
        print("\n🔄 Fetching fresh snapshot...")
        let fresh = try await aggregator.getCurrentSnapshot()
        print("   \(fresh.summary)")

        // Now cached snapshot should be available
        if let newCache = aggregator.getLastSnapshot() {
            print("\n✅ New snapshot cached")
            print("   Timestamp: \(newCache.timestamp)")
        }

    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Running Examples

/*
 To run these examples:

 // Run individual examples
 Task {
     await example1_BasicSnapshot()
     await example2_ContinuousMonitoring()
     await example3_CustomConfiguration()
     await example4_LocationTracking()
     await example5_DeviceStateMonitoring()
     await example6_HealthMetricsTracking()
     await example7_ActivityBasedActions()
     await example8_ContextAwareLLMPrompts()
     await example10_CachedSnapshots()
 }

 // Or use the SwiftUI dashboard
 struct ContentView: View {
     var body: some View {
         NavigationView {
             SensorDashboardView()
         }
     }
 }
 */
