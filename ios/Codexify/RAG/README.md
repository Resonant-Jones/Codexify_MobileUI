# ContextBroker - Sovereign Mobile RAG Node

🚀 **Part of Codexify:Scout**

A local-first, sensor-aware context engine for retrieval-augmented generation (RAG) on iOS. Collects and composes context packets from conversation history, semantic memory, and real-world sensors to enhance LLM prompts.

## Overview

ContextBroker is the central orchestrator for gathering multi-modal context on iOS devices. It bridges:
- **Thread History**: Recent conversation messages
- **Semantic Memory**: Vector-matched memory fragments
- **Sensor Data**: GPS, activity, health metrics, device state

This creates rich, contextually-aware prompts that ground LLM responses in real-world data and personal memory.

## Architecture

```
ContextBroker
├── Core Models
│   ├── ThreadMessage       # Conversation messages
│   ├── MemoryFragment      # Semantic memory with embeddings
│   ├── SensorSnapshot      # Real-time sensor data
│   └── ContextPacket       # Complete context package
│
├── Storage Protocols
│   ├── VectorStoreProtocol      # Vector database interface
│   ├── ThreadStorageProtocol    # Message storage interface
│   └── SensorAggregatorProtocol # Sensor data interface
│
├── Implementations
│   ├── VectorStore         # Vector search & storage
│   ├── ThreadStorage       # Message persistence
│   └── SensorAggregator    # Sensor data collection
│
└── ContextBroker           # Main orchestrator
    └── buildContext()      # Async context assembly
```

## Features

✅ **Multi-Source Context**
- Conversation thread history (5 most recent messages)
- Semantic memory retrieval (top 5 similar fragments)
- Real-time sensor data (location, activity, health)

✅ **Efficient Async Architecture**
- Parallel context fetching with Task Groups
- Configurable timeouts
- Non-blocking sensor queries

✅ **iPhone-Optimized**
- Local-first design (no cloud dependency)
- Minimal battery impact
- Memory-efficient vector operations

✅ **Extensible Design**
- Protocol-based interfaces
- Pluggable storage backends
- Configurable weighting strategies

✅ **Privacy-First**
- All data processed on-device
- No telemetry or tracking
- User controls all context sources

## Quick Start

### 1. Basic Usage

```swift
import Foundation

// Initialize context broker for a conversation thread
let threadId = UUID()
let broker = ContextBroker(threadId: threadId)

// Build context for a user prompt
Task {
    do {
        let context = try await broker.buildContext(forPrompt: "How do I use CoreML?")

        // Format for LLM prompt
        let promptText = context.formatForPrompt()
        print(promptText)

        // Access individual components
        print("Messages: \(context.threadHistory.count)")
        print("Memories: \(context.semanticMemory.count)")
        print("Location: \(context.sensorSnapshot.location?.placeName ?? "Unknown")")

    } catch {
        print("Failed to build context: \(error)")
    }
}
```

### 2. Custom Configuration

```swift
// Configure context collection parameters
let config = ContextBroker.Configuration(
    maxRecentMessages: 10,           // Fetch up to 10 recent messages
    maxSemanticMemories: 8,          // Retrieve 8 memory fragments
    semanticSimilarityThreshold: 0.7, // Higher threshold = more relevant
    includeSystemMessages: false,     // Filter out system messages
    includeSensorData: true,          // Include sensor snapshot
    timeoutSeconds: 5.0               // 5 second timeout
)

let broker = ContextBroker(threadId: threadId, config: config)
```

### 3. Integration with ModelRouter

```swift
// Combine ContextBroker with ModelRouter for RAG
let contextBroker = ContextBroker(threadId: threadId)
let modelRouter = ModelRouter(preferences: .defaultConfiguration())

func sendRAGRequest(_ userInput: String) async throws -> String {
    // Step 1: Build context
    let context = try await contextBroker.buildContext(forPrompt: userInput)

    // Step 2: Format context for prompt
    let contextualPrompt = """
    \(context.formatForPrompt())

    User Question: \(userInput)

    Answer based on the context above.
    """

    // Step 3: Route to LLM
    let response = try await modelRouter.routeRequest(contextualPrompt)

    return response
}

// Use it
Task {
    let answer = try await sendRAGRequest("What did we discuss about Swift?")
    print(answer)
}
```

## Data Models

### ThreadMessage

Represents a message in a conversation.

```swift
struct ThreadMessage {
    let id: UUID
    let role: MessageRole        // .user, .assistant, .system
    let content: String
    let timestamp: Date
    let metadata: MessageMetadata?
}
```

### MemoryFragment

A semantic memory with vector embedding.

```swift
struct MemoryFragment {
    let id: UUID
    let content: String
    let embedding: [Float]       // Vector representation
    let timestamp: Date
    let source: MemorySource     // .conversation, .document, .sensor, etc.
    let metadata: MemoryMetadata?
}
```

### SensorSnapshot

Real-time device and environmental data.

```swift
struct SensorSnapshot {
    let timestamp: Date
    let location: LocationSnapshot?
    let activity: ActivityType?       // .walking, .running, .stationary
    let healthMetrics: HealthMetrics? // Heart rate, steps, etc.
    let deviceState: DeviceState?     // Battery, network, thermal
}
```

### ContextPacket

The complete context package.

```swift
struct ContextPacket {
    let threadHistory: [ThreadMessage]
    let semanticMemory: [MemoryFragment]
    let sensorSnapshot: SensorSnapshot
    let timestamp: Date
    let metadata: ContextMetadata?
}
```

## API Reference

### ContextBroker

#### `buildContext(forPrompt input: String) async throws -> ContextPacket`

Builds a complete context packet for a given prompt.

**Parameters:**
- `input`: User input/prompt string

**Returns:** `ContextPacket` with all gathered context

**Throws:** `ContextBrokerError` if context building fails

**Example:**
```swift
let context = try await broker.buildContext(forPrompt: "Explain async/await")
```

#### `buildContext(forPrompt:weights:) async throws -> ContextPacket`

Builds context with custom salience weights (TODO: implementation pending).

**Parameters:**
- `input`: User input/prompt string
- `weights`: Custom weights for prioritizing context sources

### VectorStore

#### `search(query:limit:threshold:) async throws -> [MemoryFragment]`

Searches for semantically similar memory fragments.

**Parameters:**
- `query`: Search query string
- `limit`: Maximum number of results (default: 5)
- `threshold`: Minimum similarity score 0.0-1.0 (default: 0.5)

**Returns:** Array of memory fragments sorted by similarity

#### `store(_ fragment: MemoryFragment) async throws`

Stores a new memory fragment in the vector database.

#### `delete(id: UUID) async throws`

Deletes a memory fragment by ID.

### ThreadStorage

#### `fetchRecentMessages(threadId:limit:) async throws -> [ThreadMessage]`

Fetches recent messages from a conversation thread.

**Parameters:**
- `threadId`: Thread identifier
- `limit`: Maximum number of messages (default: 5)

**Returns:** Array of messages, most recent first

### SensorAggregator

#### `getCurrentSnapshot() async throws -> SensorSnapshot`

Retrieves the current sensor data snapshot.

**Returns:** Latest sensor snapshot with location, activity, health metrics

#### `startMonitoring() async throws`

Starts continuous sensor monitoring.

#### `stopMonitoring() async`

Stops sensor monitoring to conserve battery.

## Error Handling

```swift
do {
    let context = try await broker.buildContext(forPrompt: prompt)
} catch ContextBrokerError.threadStorageUnavailable {
    print("Thread storage is not available")
} catch ContextBrokerError.vectorStoreUnavailable {
    print("Vector store is not available")
} catch ContextBrokerError.timeout {
    print("Context building timed out")
} catch ContextBrokerError.insufficientContext {
    print("Not enough context available")
} catch {
    print("Unexpected error: \(error)")
}
```

## Integration TODOs

### 1. Vector Database Integration

**Location:** `ContextBroker.swift:272` (VectorStore.search)

Currently uses a stub implementation with random embeddings. Integrate a real vector database:

**Options:**

**a) On-Device Vector Database**
```swift
// SQLite with VSS extension
import SQLite
import VSS

class VectorStore: VectorStoreProtocol {
    private let db: Connection

    func search(query: String, limit: Int, threshold: Float) async throws -> [MemoryFragment] {
        // 1. Generate embedding with CoreML
        let embedding = try await embeddingModel.encode(query)

        // 2. VSS similarity search
        let stmt = try db.prepare("""
            SELECT id, content, embedding,
                   vss_distance_l2(embedding, ?) as distance
            FROM memories
            WHERE distance < ?
            ORDER BY distance
            LIMIT ?
        """)

        // 3. Return results
        return try stmt.run(embedding, threshold, limit).map { row in
            // Parse and return MemoryFragment
        }
    }
}
```

**b) CoreML Embedding Model**
```swift
import CoreML

class EmbeddingModel {
    private let model: MLModel

    init() throws {
        // Load sentence-transformers model converted to CoreML
        self.model = try SentenceTransformer(configuration: .init()).model
    }

    func encode(_ text: String) async throws -> [Float] {
        // Tokenize and encode text
        let input = SentenceTransformerInput(text: text)
        let output = try model.prediction(from: input)
        return output.embedding
    }
}
```

**c) Cloud Vector DB with Local Cache**
```swift
class HybridVectorStore: VectorStoreProtocol {
    private let localCache: LocalVectorCache
    private let cloudStore: CloudVectorStore

    func search(query: String, limit: Int, threshold: Float) async throws -> [MemoryFragment] {
        // Try local cache first
        let cached = try await localCache.search(query: query, limit: limit)
        if cached.count >= limit {
            return cached
        }

        // Fall back to cloud if needed
        let cloudResults = try await cloudStore.search(query: query, limit: limit)

        // Update cache
        try await localCache.store(cloudResults)

        return cloudResults
    }
}
```

### 2. Embedding Generation

**Location:** `ContextBroker.swift:291` (generateEmbedding)

Replace stub implementation with real embedding model:

**Option A: sentence-transformers via CoreML**
```bash
# Convert model to CoreML
pip install coremltools sentence-transformers
python convert_model.py --model sentence-transformers/all-MiniLM-L6-v2
```

```swift
import CoreML

class SentenceEncoder {
    private let model: MLModel

    func encode(_ text: String) -> [Float] {
        // Tokenize
        let tokens = tokenizer.tokenize(text)

        // Run model
        let input = TokenizerInput(tokens: tokens)
        let output = try! model.prediction(from: input)

        // Extract embedding
        return output.embedding
    }
}
```

**Option B: OpenAI Embeddings API (with caching)**
```swift
func generateEmbedding(for text: String) async throws -> [Float] {
    // Check cache first
    if let cached = embeddingCache[text] {
        return cached
    }

    // Call OpenAI API
    let request = URLRequest(url: URL(string: "https://api.openai.com/v1/embeddings")!)
    // ... configure request ...

    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(EmbeddingResponse.self, from: data)

    // Cache result
    embeddingCache[text] = response.embedding

    return response.embedding
}
```

### 3. Sensor Integration

**Location:** `ContextBroker.swift:453` (getCurrentSnapshot)

Integrate real iOS sensors:

**CoreLocation Integration**
```swift
import CoreLocation

class SensorAggregator: NSObject, CLLocationManagerDelegate, SensorAggregatorProtocol {
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func getCurrentSnapshot() async throws -> SensorSnapshot {
        // Start location updates if needed
        if currentLocation == nil {
            locationManager.startUpdatingLocation()
            try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1s
        }

        let location = currentLocation.map { LocationSnapshot(from: $0) }
        // ... gather other sensor data ...

        return SensorSnapshot(location: location, ...)
    }
}
```

**HealthKit Integration**
```swift
import HealthKit

class HealthDataCollector {
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        let types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]

        try await healthStore.requestAuthorization(toShare: [], read: types)
    }

    func getCurrentMetrics() async throws -> SensorSnapshot.HealthMetrics {
        // Query heart rate
        let heartRate = try await queryMostRecentSample(for: .heartRate)

        // Query steps today
        let steps = try await queryTodaySum(for: .stepCount)

        return SensorSnapshot.HealthMetrics(
            heartRate: heartRate,
            steps: Int(steps),
            distance: nil,
            activeEnergyBurned: nil,
            standHours: nil
        )
    }
}
```

**CoreMotion Integration**
```swift
import CoreMotion

class ActivityDetector {
    private let motionManager = CMMotionActivityManager()

    func getCurrentActivity() async throws -> SensorSnapshot.ActivityType {
        return try await withCheckedThrowingContinuation { continuation in
            motionManager.startActivityUpdates(to: .main) { activity in
                guard let activity = activity else {
                    continuation.resume(throwing: SensorError.unavailable)
                    return
                }

                let type: SensorSnapshot.ActivityType
                if activity.walking {
                    type = .walking
                } else if activity.running {
                    type = .running
                } else if activity.cycling {
                    type = .cycling
                } else if activity.automotive {
                    type = .automotive
                } else if activity.stationary {
                    type = .stationary
                } else {
                    type = .unknown
                }

                continuation.resume(returning: type)
                self.motionManager.stopActivityUpdates()
            }
        }
    }
}
```

### 4. Salience Weighting

**Location:** `ContextBroker.swift:588` (buildContext)

Implement intelligent context prioritization:

```swift
struct SalienceWeightCalculator {
    func calculateWeights(
        for query: String,
        threadHistory: [ThreadMessage],
        semanticMemory: [MemoryFragment],
        sensorSnapshot: SensorSnapshot
    ) -> ContextPacket.SalienceWeights {

        // Calculate recency score
        let recencyScore = calculateRecencyScore(threadHistory)

        // Calculate semantic relevance
        let semanticScore = calculateSemanticRelevance(query, semanticMemory)

        // Calculate sensor signal strength
        let sensorScore = calculateSensorSignalStrength(sensorSnapshot)

        // Normalize and return
        let total = recencyScore + semanticScore + sensorScore
        return ContextPacket.SalienceWeights(
            recentMessagesWeight: recencyScore / total,
            semanticMemoryWeight: semanticScore / total,
            sensorDataWeight: sensorScore / total
        )
    }

    private func calculateRecencyScore(_ messages: [ThreadMessage]) -> Float {
        guard let mostRecent = messages.last else { return 0.0 }
        let age = Date().timeIntervalSince(mostRecent.timestamp)
        // Exponential decay: newer = higher weight
        return exp(-Float(age) / 3600.0) // 1 hour half-life
    }

    private func calculateSemanticRelevance(_ query: String, _ fragments: [MemoryFragment]) -> Float {
        guard !fragments.isEmpty else { return 0.0 }
        // Average similarity of top fragments
        return fragments.reduce(0) { $0 + ($1.metadata?.importance ?? 0.5) } / Float(fragments.count)
    }

    private func calculateSensorSignalStrength(_ snapshot: SensorSnapshot) -> Float {
        var strength: Float = 0.0

        // Boost if significant location
        if snapshot.location != nil {
            strength += 0.3
        }

        // Boost if active (not stationary)
        if snapshot.activity != .stationary && snapshot.activity != nil {
            strength += 0.2
        }

        // Boost if health metrics unusual
        if let hr = snapshot.healthMetrics?.heartRate, hr > 100 || hr < 50 {
            strength += 0.5
        }

        return min(strength, 1.0)
    }
}
```

### 5. Context Compression

Implement token-aware context truncation:

```swift
extension ContextPacket {
    func compressed(maxTokens: Int, tokenizer: Tokenizer) -> ContextPacket {
        var currentTokens = 0
        var compressedHistory: [ThreadMessage] = []
        var compressedMemory: [MemoryFragment] = []

        // Allocate tokens based on salience weights
        let historyBudget = Int(Float(maxTokens) * (metadata?.salienceWeights?.recentMessagesWeight ?? 0.5))
        let memoryBudget = Int(Float(maxTokens) * (metadata?.salienceWeights?.semanticMemoryWeight ?? 0.3))

        // Add messages until budget exhausted
        for message in threadHistory.reversed() {
            let tokens = tokenizer.count(message.content)
            if currentTokens + tokens <= historyBudget {
                compressedHistory.insert(message, at: 0)
                currentTokens += tokens
            }
        }

        // Add memories until budget exhausted
        currentTokens = 0
        for fragment in semanticMemory {
            let tokens = tokenizer.count(fragment.content)
            if currentTokens + tokens <= memoryBudget {
                compressedMemory.append(fragment)
                currentTokens += tokens
            }
        }

        return ContextPacket(
            threadHistory: compressedHistory,
            semanticMemory: compressedMemory,
            sensorSnapshot: sensorSnapshot,
            timestamp: timestamp,
            metadata: metadata
        )
    }
}
```

## Performance Optimization

### Parallel Context Fetching

The ContextBroker fetches context sources in parallel using Swift Task Groups:

```swift
// Concurrent fetching
async let threadHistory = fetchThreadHistory()
async let semanticMemory = fetchSemanticMemory(for: input)
async let sensorSnapshot = fetchSensorSnapshot()

// All execute simultaneously
let (thread, memory, sensors) = try await (threadHistory, semanticMemory, sensorSnapshot)
```

### Caching Strategy

```swift
class CachedContextBroker: ContextBroker {
    private var contextCache: [String: (ContextPacket, Date)] = [:]
    private let cacheExpiry: TimeInterval = 30.0 // 30 seconds

    override func buildContext(forPrompt input: String) async throws -> ContextPacket {
        // Check cache
        if let (cached, timestamp) = contextCache[input],
           Date().timeIntervalSince(timestamp) < cacheExpiry {
            print("✅ Returning cached context")
            return cached
        }

        // Build fresh context
        let context = try await super.buildContext(forPrompt: input)

        // Update cache
        contextCache[input] = (context, Date())

        return context
    }
}
```

## Privacy & Security

### Data Storage
- All memory fragments stored locally in SQLite
- Embeddings computed on-device when possible
- No cloud sync by default

### Permissions
```swift
// Info.plist entries required
<key>NSLocationWhenInUseUsageDescription</key>
<string>Codexify uses your location to provide contextually relevant responses.</string>

<key>NSMotionUsageDescription</key>
<string>Codexify uses motion data to understand your current activity.</string>

<key>NSHealthShareUsageDescription</key>
<string>Codexify can use health data to provide personalized insights.</string>
```

### User Control
```swift
struct PrivacySettings {
    var enableLocationTracking: Bool = false
    var enableActivityTracking: Bool = false
    var enableHealthData: Bool = false
    var vectorStorageLocation: StorageLocation = .local
}
```

## Testing

### Unit Tests

```swift
import XCTest
@testable import Codexify

class ContextBrokerTests: XCTestCase {

    func testContextBuilding() async throws {
        let threadId = ThreadStorage.defaultThreadId
        let broker = ContextBroker(threadId: threadId)

        let context = try await broker.buildContext(forPrompt: "test query")

        XCTAssertFalse(context.isEmpty)
        XCTAssertGreaterThan(context.threadHistory.count, 0)
    }

    func testCosineSimilarity() {
        let a: [Float] = [1.0, 0.0, 0.0]
        let b: [Float] = [1.0, 0.0, 0.0]
        let similarity = cosineSimilarity(a, b)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.01)
    }

    func testVectorSearch() async throws {
        let store = VectorStore.shared
        let results = try await store.search(query: "Swift programming", limit: 5)

        XCTAssertLessThanOrEqual(results.count, 5)
    }
}
```

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 13.0+

## Related Modules

- **ModelRouter**: Routes LLM requests to providers
- **VectorStore**: Manages semantic memory
- **SensorAggregator**: Collects device sensor data

## Future Enhancements

- [ ] Multi-modal context (images, audio)
- [ ] Cross-device context sync (CloudKit)
- [ ] Temporal reasoning (time-based context)
- [ ] Context summarization for long threads
- [ ] User feedback loop for relevance tuning
- [ ] Graph-based memory relationships
- [ ] Proactive context suggestions

---

**Built with ❤️ by Codexify:Scout**
