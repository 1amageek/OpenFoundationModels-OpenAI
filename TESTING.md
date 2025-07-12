# Testing Documentation for OpenFoundationModels-OpenAI

## Overview

This document provides comprehensive testing guidance for the OpenFoundationModels-OpenAI project using Swift Testing framework. The testing strategy ensures reliability, maintainability, and compatibility with OpenAI's API.

## Test Framework Setup

### Swift Testing Integration

The project uses Swift Testing framework with the following configuration in `Package.swift`:

```swift
// Package.swift
let package = Package(
    name: "OpenFoundationModels-OpenAI",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/OpenFoundationModels.git", branch: "main")
    ],
    targets: [
        .target(
            name: "OpenFoundationModelsOpenAI",
            dependencies: ["OpenFoundationModels"]
        ),
        .testTarget(
            name: "OpenFoundationModelsOpenAITests",
            dependencies: ["OpenFoundationModelsOpenAI"]
        )
    ]
)
```

### Test Commands

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test suite
swift test --filter OpenAILanguageModelTests

# Run parallel tests
swift test --parallel

# Run tests with coverage
swift test --enable-code-coverage
```

## Test Architecture

### Test Suite Structure

```
Tests/OpenFoundationModelsOpenAITests/
├── Core/
│   ├── OpenAILanguageModelTests.swift      # Main provider tests
│   ├── OpenAIConfigurationTests.swift     # Configuration tests
│   └── OpenAIModelTests.swift             # Model enum tests
├── HTTP/
│   ├── OpenAIHTTPClientTests.swift        # HTTP client tests
│   └── HTTPMockingTests.swift             # Network mocking tests
├── API/
│   ├── RequestBuilderTests.swift          # Request building tests
│   ├── ResponseHandlerTests.swift         # Response handling tests
│   └── APITypesTests.swift               # Serialization tests
├── Streaming/
│   ├── StreamingHandlerTests.swift        # Streaming logic tests
│   └── AsyncStreamTests.swift            # Async stream tests
├── Integration/
│   ├── LiveAPITests.swift                 # Live API tests (optional)
│   └── EndToEndTests.swift               # Complete workflow tests
├── Utilities/
│   ├── MockFactory.swift                 # Test helper factories
│   ├── TestConstants.swift               # Test data constants
│   └── AsyncTestHelpers.swift            # Async testing utilities
└── TestResources/
    ├── MockResponses/                     # JSON response samples
    └── TestData/                          # Test input data
```

## Test Categories

### 1. Unit Tests

**Purpose**: Test individual components in isolation using mocks.

**Characteristics**:
- Fast execution (< 100ms per test)
- No network dependencies
- Deterministic results
- High coverage of edge cases

**Example Structure**:
```swift
@Suite("OpenAI Language Model Unit Tests")
struct OpenAILanguageModelUnitTests {
    
    @Test("Model initialization with valid configuration")
    func testModelInitialization() {
        let config = OpenAIConfiguration(apiKey: "test-key")
        let model = OpenAILanguageModel(configuration: config, model: .gpt4o)
        
        #expect(model.isAvailable == true)
        #expect(model.supports(locale: Locale(identifier: "en_US")) == true)
    }
}
```

### 2. Parameterized Tests

**Purpose**: Test same functionality across different OpenAI models.

**Implementation**:
```swift
@Test("Generation works across all models", arguments: [
    OpenAIModel.gpt4o,
    OpenAIModel.gpt4oMini,
    OpenAIModel.o3Mini,
    OpenAIModel.o3,
    OpenAIModel.o3Pro,
    OpenAIModel.o1,
    OpenAIModel.o1Pro
])
func testGenerationAcrossModels(model: OpenAIModel) async throws {
    let mockClient = MockHTTPClient()
    let languageModel = OpenAILanguageModel(
        configuration: TestConfiguration.valid,
        model: model
    )
    
    let result = try await languageModel.generate(
        prompt: "Hello",
        options: GenerationOptions(maxTokens: 10)
    )
    
    #expect(!result.isEmpty, "Model \(model.apiName) should generate content")
}
```

### 3. Async Tests

**Purpose**: Test asynchronous operations including streaming and concurrent requests.

**Pattern**:
```swift
@Test("Streaming delivers content progressively")
func testStreamingDelivery() async throws {
    let mockClient = MockStreamingHTTPClient()
    let model = OpenAILanguageModel(configuration: TestConfiguration.valid, model: .gpt4o)
    
    var receivedChunks: [String] = []
    
    await confirmation("Stream delivers multiple chunks") { confirm in
        for await chunk in model.stream(prompt: "Tell me a story", options: nil) {
            receivedChunks.append(chunk)
            if receivedChunks.count >= 3 {
                confirm()
                break
            }
        }
    }
    
    #expect(receivedChunks.count >= 3, "Should receive multiple chunks")
    #expect(receivedChunks.allSatisfy { !$0.isEmpty }, "All chunks should have content")
}
```

### 4. Error Handling Tests

**Purpose**: Verify proper error handling and recovery mechanisms.

**Categories**:
- Network errors (timeout, connection failure)
- API errors (rate limit, invalid request, model unavailable)
- Parsing errors (malformed JSON, unexpected format)
- Configuration errors (invalid API key, missing parameters)

**Example**:
```swift
@Test("Rate limit error handling")
func testRateLimitHandling() async throws {
    let mockClient = MockHTTPClient()
    mockClient.shouldReturnRateLimit = true
    
    let model = OpenAILanguageModel(configuration: TestConfiguration.valid, model: .gpt4o)
    
    await #expect(throws: OpenAIModelError.rateLimitExceeded) {
        try await model.generate(prompt: "test", options: nil)
    }
}
```

### 5. Integration Tests

**Purpose**: Test complete workflows with real or near-real scenarios.

**Note**: These tests may require API keys and should be marked as optional.

```swift
@Suite("Integration Tests", .enabled(if: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil))
struct IntegrationTests {
    
    @Test("Complete generation workflow")
    func testCompleteWorkflow() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw XCTSkip("API key not provided")
        }
        
        let model = OpenAILanguageModel.gpt4oMini(apiKey: apiKey)
        let result = try await model.generate(
            prompt: "Say hello in one word",
            options: GenerationOptions(maxTokens: 5)
        )
        
        #expect(!result.isEmpty, "Should generate content")
        #expect(result.count < 50, "Should be short response")
    }
}
```

## Mock Strategy

### HTTP Client Mocking

```swift
actor MockHTTPClient: HTTPClientProtocol {
    var responses: [String: Data] = [:]
    var errors: [String: Error] = [:]
    var shouldReturnRateLimit = false
    
    func send<T: Codable>(_ request: OpenAIHTTPRequest) async throws -> T {
        if shouldReturnRateLimit {
            throw OpenAIHTTPError.statusError(429, nil)
        }
        
        let endpoint = request.endpoint
        if let error = errors[endpoint] {
            throw error
        }
        
        guard let data = responses[endpoint] else {
            throw OpenAIHTTPError.noData
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func stream(_ request: OpenAIHTTPRequest) async throws -> AsyncStream<Data> {
        // Mock streaming implementation
        return AsyncStream<Data> { continuation in
            Task {
                // Simulate streaming chunks
                for chunk in mockStreamingChunks {
                    continuation.yield(chunk)
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
                }
                continuation.finish()
            }
        }
    }
}
```

### Response Mocking

```swift
struct MockFactory {
    static func chatCompletionResponse(content: String) -> Data {
        let response = ChatCompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0,
                    message: ChatMessage.assistant(content),
                    finishReason: "stop"
                )
            ],
            usage: ChatCompletionResponse.Usage(
                promptTokens: 10,
                completionTokens: 5,
                totalTokens: 15,
                reasoningTokens: nil
            ),
            systemFingerprint: "test-fingerprint"
        )
        
        return try! JSONEncoder().encode(response)
    }
    
    static func streamingResponse(content: String) -> [Data] {
        return content.map { char in
            let chunk = ChatCompletionStreamResponse(
                id: "test-id",
                object: "chat.completion.chunk",
                created: Int(Date().timeIntervalSince1970),
                model: "gpt-4o",
                choices: [
                    ChatCompletionStreamResponse.StreamChoice(
                        index: 0,
                        delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                            role: nil,
                            content: String(char),
                            toolCalls: nil
                        ),
                        finishReason: nil
                    )
                ]
            )
            
            let jsonData = try! JSONEncoder().encode(chunk)
            return "data: \(String(data: jsonData, encoding: .utf8)!)\n\n".data(using: .utf8)!
        }
    }
}
```

## Test Data Management

### Constants

```swift
enum TestConstants {
    static let samplePrompt = "Hello, how are you?"
    static let shortPrompt = "Hi"
    static let longPrompt = String(repeating: "This is a very long prompt. ", count: 100)
    static let emptyPrompt = ""
    
    static let validAPIKey = "sk-test-valid-key-12345"
    static let invalidAPIKey = "invalid-key"
    
    static let defaultOptions = GenerationOptions(
        maxTokens: 100,
        temperature: 0.7,
        topP: 1.0
    )
}

struct TestConfiguration {
    static let valid = OpenAIConfiguration(
        apiKey: TestConstants.validAPIKey,
        baseURL: URL(string: "https://api.openai.com/v1")!,
        organization: nil
    )
    
    static let invalidKey = OpenAIConfiguration(
        apiKey: TestConstants.invalidAPIKey,
        baseURL: URL(string: "https://api.openai.com/v1")!,
        organization: nil
    )
}
```

### JSON Test Resources

Store mock JSON responses in `Tests/TestResources/MockResponses/`:

```
MockResponses/
├── chat_completion_success.json
├── chat_completion_error.json
├── streaming_chunks.json
├── rate_limit_error.json
└── model_not_found_error.json
```

## Performance Testing

### Test Execution Time

```swift
@Test("Generation performance benchmark")
func testGenerationPerformance() async throws {
    let startTime = Date()
    
    let mockClient = MockHTTPClient()
    mockClient.responses["chat/completions"] = MockFactory.chatCompletionResponse(content: "Hello")
    
    let model = OpenAILanguageModel(configuration: TestConfiguration.valid, model: .gpt4o)
    let _ = try await model.generate(prompt: "Hello", options: nil)
    
    let executionTime = Date().timeIntervalSince(startTime)
    #expect(executionTime < 1.0, "Generation should complete within 1 second")
}
```

### Memory Usage

```swift
@Test("Memory usage within bounds")
func testMemoryUsage() async throws {
    let initialMemory = getMemoryUsage()
    
    // Create and use model multiple times
    for _ in 1...100 {
        let model = OpenAILanguageModel(configuration: TestConfiguration.valid, model: .gpt4o)
        let _ = model.isAvailable
    }
    
    let finalMemory = getMemoryUsage()
    let memoryIncrease = finalMemory - initialMemory
    
    #expect(memoryIncrease < 10_000_000, "Memory increase should be less than 10MB")
}
```

## Test Execution Strategy

### Phase 1: Foundation Tests
1. OpenAIConfiguration validation
2. OpenAIModel enum functionality
3. Basic OpenAILanguageModel initialization

### Phase 2: Core Functionality Tests
1. Text generation with mocked responses
2. Parameter validation and constraint checking
3. Locale support verification

### Phase 3: HTTP Layer Tests
1. Request building for different models
2. Response parsing and content extraction
3. Error mapping and handling

### Phase 4: Streaming Tests
1. AsyncStream functionality
2. Server-Sent Events parsing
3. Streaming error handling

### Phase 5: Advanced Features Tests
1. Rate limiting behavior
2. Retry logic
3. Concurrent request handling

### Phase 6: Integration Tests
1. End-to-end workflows (optional, with API key)
2. Performance validation
3. Compatibility verification

## Debugging Failed Tests

### Analysis Checklist

When a test fails:

1. **Verify Test Logic**:
   - Is the test expectation correct?
   - Are the mock responses appropriate?
   - Is the test setup complete?

2. **Check Implementation**:
   - Does the implementation match the API specification?
   - Are there edge cases not handled?
   - Is error handling appropriate?

3. **Validate Dependencies**:
   - Are mock objects configured correctly?
   - Is the test environment properly set up?
   - Are async operations properly awaited?

4. **Cross-Reference Documentation**:
   - Does behavior match OpenAI API docs?
   - Is it compatible with OpenFoundationModels protocol?
   - Are Swift concurrency patterns followed correctly?

### Common Issues and Solutions

**Issue**: Async test timeouts
**Solution**: Check for proper continuation handling in AsyncStream

**Issue**: Sendable conformance errors
**Solution**: Verify all types passed across actor boundaries are Sendable

**Issue**: JSON parsing failures
**Solution**: Validate mock JSON matches actual API response format

**Issue**: Rate limiting not working
**Solution**: Ensure actor-based rate limiter is properly implemented

## Continuous Integration

### GitHub Actions Configuration

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v4
    - name: Run tests
      run: swift test --enable-code-coverage
    - name: Generate coverage report
      run: xcrun llvm-cov show .build/debug/*.xctest/Contents/MacOS/* -instr-profile .build/debug/codecov/default.profdata
```

### Coverage Requirements

- **Minimum Coverage**: 80% overall
- **Core Components**: 95% coverage required
- **Error Paths**: 90% coverage required
- **Integration Code**: 70% coverage acceptable

This testing strategy ensures comprehensive validation of the OpenFoundationModels-OpenAI implementation while maintaining development velocity and code quality.