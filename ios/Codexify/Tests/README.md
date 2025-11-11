# Codexify:Scout Test Suite

🧪 **Phase One: Production Readiness Validation**

Comprehensive test suite for validating the core modules of Codexify:Scout - a modular iOS-native AI agent system with model routing, context injection, and sensor-based RAG capabilities.

## Test Coverage Overview

### ✅ ModelRouterTests.swift (40+ tests)
Tests for the LLM provider routing system.

**Categories:**
- Unit Tests: Model dispatch logic (cloud vs local)
- Edge Cases: Unknown models, fallbacks, error handling
- Integration Tests: Inference result piping, keychain integration
- Performance Tests: 100+ parallel inferences simulation

### ✅ ContextBrokerTests.swift (45+ tests)
Tests for the context aggregation and compilation system.

**Categories:**
- Unit Tests: Context compilation from multiple sources
- Mock Injection: Persona, memory, sensor snapshot integration
- Failure Tests: Missing context fields, graceful degradation
- Async Edge Cases: Delayed retrieval, timeouts, concurrent requests

### ✅ SensorAggregatorTests.swift (30+ tests)
Tests for the unified sensor data collection system.

**Categories:**
- Unit Tests: Snapshot collection, individual sensors
- Mock Implementations: Location, Motion, Health, Device readers
- Edge Cases: Nil values, sensor failures, timeouts
- Performance Tests: Concurrent snapshots, rapid monitoring cycles

---

## Quick Start

### Running All Tests

```bash
# Command line (from project root)
xcodebuild test -scheme Codexify -destination 'platform=iOS Simulator,name=iPhone 15'

# Or use Xcode
# Product > Test (⌘U)
```

### Running Specific Test Class

```bash
# Run only ModelRouter tests
xcodebuild test -scheme Codexify -only-testing:ModelRouterTests

# Run only ContextBroker tests
xcodebuild test -scheme Codexify -only-testing:ContextBrokerTests

# Run only SensorAggregator tests
xcodebuild test -scheme Codexify -only-testing:SensorAggregatorTests
```

### Running Specific Test Method

```bash
# Run single test
xcodebuild test -scheme Codexify \
  -only-testing:ModelRouterTests/testRouteRequest_DispatchesToDefaultProvider
```

### Running Performance Tests Only

```bash
# Filter by test name pattern
xcodebuild test -scheme Codexify \
  -only-testing:ModelRouterTests/testPerformance_100ParallelInferences \
  -only-testing:ContextBrokerTests/testPerformance_BuildContext \
  -only-testing:SensorAggregatorTests/testPerformance_GetCurrentSnapshot
```

---

## Test Architecture

### Mock-Based Testing

All tests use **mock implementations** to ensure:
- ✅ Deterministic results
- ✅ No external dependencies (APIs, sensors, network)
- ✅ Fast execution
- ✅ Isolated failures
- ✅ Reproducible across environments

### Test Naming Convention

```swift
test[FunctionName]_[ExpectedBehavior]

// Examples:
func testRouteRequest_DispatchesToDefaultProvider()
func testBuildContext_WithEmptyThreadHistory()
func testGetCurrentSnapshot_Timeout()
```

### Test Organization

```
Tests/
├── ModelRouterTests.swift
│   ├── Mock Implementations
│   │   ├── MockOpenAIProvider
│   │   ├── MockClaudeProvider
│   │   └── MockLocalProvider
│   └── Test Categories
│       ├── Unit Tests: Model Dispatch
│       ├── Edge Cases: Fallbacks
│       ├── Error Handling
│       ├── Keychain Integration
│       ├── Usage Tracking
│       ├── Performance Tests
│       └── Integration Tests
│
├── ContextBrokerTests.swift
│   ├── Mock Implementations
│   │   ├── MockVectorStore
│   │   ├── MockThreadStorage
│   │   └── MockSensorAggregator
│   └── Test Categories
│       ├── Unit Tests: Context Compilation
│       ├── Mock Injection Tests
│       ├── Failure Tests
│       ├── Async Edge Cases
│       ├── Configuration Tests
│       ├── Context Formatting
│       ├── Performance Tests
│       └── Integration Tests
│
└── SensorAggregatorTests.swift
    ├── Mock Implementations
    │   ├── MockLocationReader
    │   ├── MockMotionReader
    │   ├── MockHealthReader
    │   └── MockDeviceStateReader
    └── Test Categories
        ├── Basic Functionality
        ├── Monitoring Tests
        ├── Error Handling
        ├── Timeout Tests
        ├── Async Integration
        ├── Configuration Tests
        ├── Data Model Tests
        ├── Performance Tests
        └── Edge Cases
```

---

## Detailed Test Coverage

### ModelRouterTests (40+ tests)

#### Unit Tests: Model Dispatch (5 tests)
```swift
✓ testRouteRequest_DispatchesToDefaultProvider()
✓ testRouteRequest_CloudVsLocalDispatch()
✓ testRouteRequest_SelectsCorrectEndpoint()
✓ testProviderConfig_ProperlyStoresModelIdentifiers()
```

**What they validate:**
- Default provider selection
- Cloud vs local model routing
- Endpoint configuration
- Model identifier storage

#### Edge Cases: Fallbacks (5 tests)
```swift
✓ testTryFallbackProvider_WithNoFallbacks_ThrowsError()
✓ testTryFallbackProvider_WithDisabledFallback_DoesNotAttempt()
✓ testTryFallbackProvider_AllProvidersFailSimulation()
✓ testDefaultConfiguration_HasReasonableFallbacks()
✓ testLocalOnlyConfiguration_HasNoFallbacks()
```

**What they validate:**
- Fallback chain execution
- Graceful degradation
- Configuration presets
- Error propagation

#### Error Handling (4 tests)
```swift
✓ testModelRouterError_NoAPIKeyFound()
✓ testModelRouterError_InvalidResponse()
✓ testModelRouterError_AllProvidersFailed()
✓ testModelRouterError_LocalModelNotImplemented()
```

**What they validate:**
- Error message clarity
- Error type accuracy
- Appropriate error codes

#### Keychain Integration (4 tests)
```swift
✓ testKeychainManager_StoreAndRetrieveAPIKey()
✓ testKeychainManager_RetrieveNonExistentKey_ThrowsError()
✓ testKeychainManager_DeleteAPIKey()
✓ testKeychainManager_DeleteAllAPIKeys()
```

**What they validate:**
- Secure key storage
- Key retrieval
- Key deletion
- Error handling for missing keys

#### Usage Tracking (4 tests)
```swift
✓ testUsageTracker_IncrementUsage()
✓ testUsageTracker_GetAllUsage()
✓ testUsageTracker_ResetUsage()
✓ testUsageTracker_ConcurrentIncrements()
```

**What they validate:**
- Request counting
- Thread-safe increments
- Statistics aggregation
- Concurrent access handling

#### Performance Tests (3 tests)
```swift
✓ testPerformance_100ParallelInferences()
✓ testPerformance_RapidKeychainAccess()
✓ testPerformance_ProviderConfigurationCreation()
```

**What they validate:**
- Parallel request handling (100+ concurrent)
- Keychain access speed
- Object creation overhead

#### Integration Tests (3 tests)
```swift
✓ testIntegration_FullRoutingWorkflow()
✓ testIntegration_FallbackChain()
✓ testIntegration_MultiProviderUsageTracking()
```

**What they validate:**
- End-to-end routing flow
- Multi-provider coordination
- Cross-component integration

#### Edge Cases (8 tests)
```swift
✓ testEdgeCase_EmptyProviderName()
✓ testEdgeCase_VeryLongAPIKey()
✓ testEdgeCase_SpecialCharactersInProviderName()
✓ testEdgeCase_NilOptionalFields()
✓ testEdgeCase_ConcurrentKeychainAccess()
✓ testOpenAIResponse_Decoding()
✓ testClaudeResponse_Decoding()
✓ testProviderConfig_Codable()
```

**What they validate:**
- Boundary conditions
- Special character handling
- JSON parsing
- Codable compliance

---

### ContextBrokerTests (45+ tests)

#### Unit Tests: Context Compilation (6 tests)
```swift
✓ testBuildContext_CompletesSuccessfully()
✓ testBuildContext_IncludesThreadHistory()
✓ testBuildContext_IncludesSemanticMemory()
✓ testBuildContext_IncludesSensorSnapshot()
✓ testBuildContext_HasMetadata()
✓ testBuildContext_ParallelFetching()
```

**What they validate:**
- Complete context assembly
- Thread history inclusion
- Semantic memory retrieval
- Sensor data integration
- Metadata generation
- Parallel data fetching (not sequential)

#### Mock Injection Tests (3 tests)
```swift
✓ testBuildContext_WithCustomVectorStore()
✓ testBuildContext_WithCustomThreadStorage()
✓ testBuildContext_WithCustomSensorAggregator()
```

**What they validate:**
- Dependency injection
- Custom mock usage
- Interface compliance

#### Failure Tests: Missing Context (7 tests)
```swift
✓ testBuildContext_WithEmptyThreadHistory()
✓ testBuildContext_WithEmptySemanticMemory()
✓ testBuildContext_WithNoSensorData()
✓ testBuildContext_WithAllSourcesEmpty()
✓ testBuildContext_ThreadStorageFailure_ContinuesGracefully()
✓ testBuildContext_VectorStoreFailure_ContinuesGracefully()
✓ testBuildContext_SensorAggregatorFailure_ContinuesGracefully()
```

**What they validate:**
- Graceful degradation
- Partial context handling
- Error isolation
- Non-critical sensor failures

#### Async Edge Cases (5 tests)
```swift
✓ testBuildContext_WithSlowThreadStorage()
✓ testBuildContext_WithSlowVectorStore()
✓ testBuildContext_WithSlowSensorAggregator()
✓ testBuildContext_Timeout()
✓ testBuildContext_ConcurrentRequests()
```

**What they validate:**
- Delayed data retrieval
- Timeout behavior
- Concurrent context builds
- Async coordination

#### Configuration Tests (3 tests)
```swift
✓ testConfiguration_CustomMaxMessages()
✓ testConfiguration_DisabledSensors()
✓ testConfiguration_HighSimilarityThreshold()
```

**What they validate:**
- Configuration respect
- Feature toggles
- Threshold filtering

#### Context Formatting (4 tests)
```swift
✓ testContextPacket_FormatForPrompt()
✓ testContextPacket_Summary()
✓ testContextPacket_TotalElements()
✓ testContextPacket_IsEmpty()
```

**What they validate:**
- Human-readable formatting
- Summary generation
- Element counting
- Empty detection

#### Performance Tests (2 tests)
```swift
✓ testPerformance_BuildContext()
✓ testPerformance_ConcurrentContextBuilds()
```

**What they validate:**
- Single context build speed
- Concurrent build performance (10 simultaneous)

#### Integration Tests (2 tests)
```swift
✓ testIntegration_FullContextWorkflow()
✓ testIntegration_ContextWithAllComponents()
```

**What they validate:**
- End-to-end workflow
- Multi-component integration
- Complete context validity

#### Data Model Tests (4 tests)
```swift
✓ testThreadMessage_Creation()
✓ testMemoryFragment_SimilarityCalculation()
✓ testCosineSimilarity_OrthogonalVectors()
✓ testCosineSimilarity_IdenticalVectors()
```

**What they validate:**
- Data model integrity
- Similarity computation
- Mathematical accuracy

---

### SensorAggregatorTests (30+ tests)

Comprehensive coverage already documented in `ios/Codexify/Sensors/README.md`

**Highlights:**
- ✅ Mock-based sensor readers
- ✅ Parallel data collection tests
- ✅ Timeout and error handling
- ✅ Device state computation
- ✅ Location distance calculation
- ✅ Concurrent snapshot requests
- ✅ Configuration validation

---

## Running Tests in CI/CD

### GitHub Actions Example

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_15.0.app

    - name: Run tests
      run: |
        xcodebuild test \
          -scheme Codexify \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          -resultBundlePath TestResults

    - name: Upload test results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: TestResults
```

### Fastlane Example

```ruby
# Fastfile
lane :test do
  run_tests(
    scheme: "Codexify",
    devices: ["iPhone 15"],
    code_coverage: true
  )
end
```

---

## Test Metrics

### Expected Performance Benchmarks

**ModelRouter:**
- Single routing decision: < 1ms
- 100 parallel inferences: < 2s
- Keychain access: < 10ms per operation

**ContextBroker:**
- Single context build: < 100ms
- 10 concurrent builds: < 500ms
- Parallel data fetching: ~max(sources), not sum(sources)

**SensorAggregator:**
- Single snapshot: < 100ms
- 10 concurrent snapshots: < 500ms
- Monitoring start/stop: < 50ms

### Code Coverage Goals

- **Line Coverage**: > 85%
- **Branch Coverage**: > 80%
- **Function Coverage**: > 90%

### Generating Coverage Reports

```bash
# Generate coverage
xcodebuild test \
  -scheme Codexify \
  -enableCodeCoverage YES \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# View coverage in Xcode
# Open Report Navigator (⌘9) > Coverage tab
```

---

## Debugging Failed Tests

### Common Issues

**1. Keychain Access Errors**
```
Error: errSecItemNotFound
```
**Solution:** Tests run in simulator - keychain is sandboxed and cleared between runs. This is expected.

**2. Timeout Errors**
```
Error: Context building timed out
```
**Solution:** Adjust timeout configuration or check for slow mocks in setup.

**3. Concurrent Access Issues**
```
Error: Thread sanitizer warning
```
**Solution:** Verify mock implementations use proper synchronization (DispatchQueue, actors).

### Debug Mode

```swift
// Enable verbose logging in tests
override func setUp() {
    super.setUp()

    // Add logging
    print("🧪 Test: \(self.name)")
}

override func tearDown() {
    // Verify cleanup
    XCTAssertNil(contextBroker)

    super.tearDown()
}
```

---

## Best Practices

### Writing New Tests

1. **Use descriptive names**: `test[What]_[When]_[Expected]`
2. **Follow AAA pattern**: Arrange, Act, Assert
3. **Keep tests focused**: One assertion per logical test
4. **Use mocks liberally**: Avoid real API calls, sensors, or network
5. **Test edge cases**: nil, empty, very large, concurrent
6. **Add performance tests**: For critical paths
7. **Document complex setups**: Use comments

### Example Test Structure

```swift
func testBuildContext_WithEmptyThreadHistory() async throws {
    // ARRANGE: Setup test conditions
    mockThreadStorage.mockMessages[testThreadId] = []

    // ACT: Execute the code under test
    let context = try await contextBroker.buildContext(forPrompt: "Test")

    // ASSERT: Verify expectations
    XCTAssertTrue(context.threadHistory.isEmpty)
    XCTAssertFalse(context.semanticMemory.isEmpty)
}
```

### Mock Guidelines

```swift
// Good mock: Configurable, deterministic
class MockVectorStore: VectorStoreProtocol {
    var mockFragments: [MemoryFragment] = []
    var shouldFail: Bool = false
    var searchDelay: TimeInterval = 0

    func search(...) async throws -> [MemoryFragment] {
        if searchDelay > 0 {
            try await Task.sleep(...)
        }

        if shouldFail {
            throw ContextBrokerError.vectorStoreUnavailable
        }

        return mockFragments
    }
}

// Bad mock: Hardcoded, not configurable
class BadMock: VectorStoreProtocol {
    func search(...) async throws -> [MemoryFragment] {
        return [] // Can't configure!
    }
}
```

---

## Continuous Improvement

### Adding New Tests

When adding features, add corresponding tests:

1. **Unit tests**: Test the feature in isolation
2. **Integration tests**: Test the feature with real dependencies
3. **Edge cases**: Test boundary conditions
4. **Performance tests**: Test under load

### Test Coverage Analysis

```bash
# Generate coverage report
xcodebuild test \
  -scheme Codexify \
  -enableCodeCoverage YES \
  -derivedDataPath ./DerivedData

# Convert to HTML
xcov --scheme Codexify \
  --workspace Codexify.xcworkspace \
  --output_directory coverage_report
```

### Maintaining Tests

- ✅ Run tests before every commit
- ✅ Fix flaky tests immediately
- ✅ Update tests when APIs change
- ✅ Remove obsolete tests
- ✅ Keep mocks in sync with real implementations

---

## Requirements

- **Xcode**: 15.0+
- **iOS Deployment Target**: 15.0+
- **Swift**: 5.9+
- **Testing Framework**: XCTest

---

## Additional Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Testing in Xcode (WWDC)](https://developer.apple.com/videos/testing)
- [Swift Testing Best Practices](https://www.swift.org/documentation/testing)

---

**Built with ❤️ by Codexify:Scout Team**

Last Updated: 2025-11-11
