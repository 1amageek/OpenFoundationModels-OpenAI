# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the OpenAI provider implementation for OpenFoundationModels framework. It enables using OpenAI's latest GPT and Reasoning models through Apple's Foundation Models API interface with a unified, self-contained architecture.

### Supported Models

**GPT Family:**
- GPT-4.1 series: `gpt-4.1`, `gpt-4.1-mini`, `gpt-4.1-nano` (latest, ~1M token context)
- GPT-4o series: `gpt-4o`, `gpt-4o-mini`
- GPT-4 Turbo: `gpt-4-turbo`

**Reasoning Family (o-series):**
- `o1`, `o1-pro`
- `o3`, `o3-pro`, `o3-mini`
- `o4-mini`

**Custom Models:**
- Any model via string literal: `OpenAIModel("your-custom-model")`

## Build and Development Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run a specific test
swift test --filter OpenAILanguageModelTests

# Clean build artifacts
swift package clean

# Update dependencies
swift package update

# Generate Xcode project (if needed)
swift package generate-xcodeproj
```

## Architecture

### Core Components

1. **OpenAILanguageModel**: Main provider class implementing the `LanguageModel` protocol from OpenFoundationModels
   - **Transcript-based interface**: Processes complete conversation context via `Transcript`
   - Unified interface for all OpenAI models (GPT and Reasoning)
   - Automatic constraint handling based on model type
   - Built-in streaming support with Server-Sent Events
   - Actor-based rate limiting and retry logic

2. **OpenAIModel**: String-based model identifier struct
   - Implements `ExpressibleByStringLiteral` for flexible model selection
   - Predefined constants for common models (`.gpt41`, `.gpt4o`, `.o3`, etc.)
   - Automatic model type inference from ID string
   - Model-specific capabilities and constraints via `ParameterConstraints`

3. **Custom HTTP Client**: Self-contained networking layer
   - No external dependencies beyond OpenFoundationModels
   - URLSession-based implementation with streaming support
   - Built-in error mapping and response handling

4. **Request/Response Handlers**: Model-specific processing
   - Separate builders for GPT vs Reasoning model requests
   - Automatic parameter filtering based on model constraints
   - Specialized error handling per model type

### Key Implementation Requirements

When implementing the OpenAILanguageModel, ensure:

1. **Protocol Conformance (Transcript-based)**:
   - `generate(transcript:options:)` - Returns `Transcript.Entry` with complete response
   - `stream(transcript:options:)` - Returns `AsyncThrowingStream<Transcript.Entry, Error>` for streaming
   - `isAvailable` - Synchronous property (returns `true`)
   - `supports(locale:)` - Returns `true` (OpenAI supports most languages)
   - Extracts tools from `Transcript.Instructions.toolDefinitions` via `TranscriptConverter`
   - Converts `Transcript.Entry` types to OpenAI message format

2. **Structured Generation**:
   - Use OpenAI Function Calling for `Generable` types
   - Convert `GenerationSchema` to JSON Schema format
   - Handle function call responses and map back to Swift types

3. **Error Handling**:
   - Map OpenAI API errors to `OpenAIError` enum
   - Handle rate limits with proper retry-after headers
   - Convert network errors appropriately

4. **Streaming Implementation**:
   - Use `AsyncStream` with proper continuation handling
   - Yield partial content from delta responses
   - Handle errors within the stream

### Dependencies

- OpenFoundationModels: Core framework providing protocols and types (only dependency)
- Self-contained HTTP client implementation (no external API clients)
- Zero third-party dependencies for maximum flexibility

### Module Structure

```
Sources/OpenFoundationModelsOpenAI/
├── OpenAILanguageModel.swift           # Main provider implementation
├── OpenAIConfiguration.swift           # Configuration and rate limit settings
├── OpenFoundationModelsOpenAI.swift    # Public API and convenience initializers
├── Models/
│   └── OpenAIModel.swift               # String-based model struct with capabilities
├── HTTP/
│   └── OpenAIHTTPClient.swift          # Actor-based HTTP client implementation
├── API/
│   └── OpenAIAPITypes.swift            # OpenAI API data structures (ChatMessage, Tool, etc.)
└── Internal/
    ├── TranscriptConverter.swift       # Transcript to OpenAI format conversion
    ├── RequestBuilders.swift           # GPT/Reasoning request builders
    ├── ResponseHandlers.swift          # GPT/Reasoning response handlers
    └── StreamingHandler.swift          # Server-Sent Events streaming
```

## Testing Strategy

- Mock the OpenAI client for unit tests
- Use environment variable for API key in integration tests
- Test rate limiting behavior with mock timestamps
- Verify error mapping for all OpenAI error codes
- Test streaming with various response patterns

## Important Design Decisions

1. **Transcript-Centric Architecture**: Fully embraces OpenFoundationModels' Transcript-based design:
   - Stateless model interface - all context provided via Transcript
   - Converts Transcript entries (Instructions, Prompt, Response, ToolCalls, ToolOutput) to OpenAI format
   - Extracts tool definitions from Instructions for function calling

2. **Unified Model Interface**: `OpenAIModel` struct with `ExpressibleByStringLiteral` support that internally handles GPT vs Reasoning model differences, providing flexible model selection via predefined constants or custom strings.

3. **Self-Contained Architecture**: No external dependencies beyond OpenFoundationModels, using custom URLSession-based HTTP client for maximum flexibility and control.

4. **Automatic Constraint Handling**: Internal model type detection automatically applies correct parameter constraints (e.g., temperature not supported for Reasoning models).

5. **Actor-Based Concurrency**: Rate limiting and HTTP client use Swift actors for thread-safe operation and optimal performance.

6. **Direct Instantiation Pattern**: Direct instantiation of request builders and response handlers based on model type, following Swift conventions without factory pattern.

7. **Advanced Streaming**: Server-Sent Events implementation with buffering, accumulation, and error handling for reliable real-time responses.

## Transcript Processing Implementation

### Overview
The OpenAI provider now fully supports OpenFoundationModels' Transcript-based interface, providing complete conversation context management.

### Transcript to OpenAI Message Conversion

The `TranscriptConverter` utility handles all conversion between OpenFoundationModels Transcript format and OpenAI API format:

```swift
// TranscriptConverter provides static methods for transcript conversion
internal struct TranscriptConverter {

    /// Build OpenAI messages from Transcript
    static func buildMessages(from transcript: Transcript) -> [ChatMessage] {
        // Uses JSON-based extraction with fallback to entry-based extraction
        // Handles all entry types: instructions, prompt, response, toolCalls, toolOutput
    }

    /// Extract tool definitions from Transcript
    static func extractTools(from transcript: Transcript) -> [Tool]? {
        // Extracts toolDefinitions from Instructions entry
        // Converts Transcript.ToolDefinition to OpenAI Tool format
    }

    /// Extract response format for structured generation
    static func extractResponseFormatWithSchema(from transcript: Transcript) -> ResponseFormat? {
        // Extracts JSON Schema from Prompt's responseFormat if present
    }

    /// Extract generation options from the most recent prompt
    static func extractOptions(from transcript: Transcript) -> GenerationOptions? {
        // Returns options from the most recent prompt entry
    }
}
```

### Usage in OpenAILanguageModel

```swift
// In generate method:
let messages = TranscriptConverter.buildMessages(from: transcript)
let tools = TranscriptConverter.extractTools(from: transcript)
let responseFormat = TranscriptConverter.extractResponseFormatWithSchema(from: transcript)
let finalOptions = options ?? TranscriptConverter.extractOptions(from: transcript)
```

### Key Benefits

1. **Stateless Design**: Model doesn't maintain conversation state
2. **Complete Context**: Every request includes full conversation history
3. **Tool Support**: Automatic extraction of tool definitions from Instructions
4. **Flexible Segments**: Handles both text and structured segments
5. **Provider Agnostic**: Clean separation between OpenFoundationModels and OpenAI APIs

## Current Implementation Status

### LanguageModel Protocol (Verified)

The current implementation correctly conforms to the LanguageModel protocol from OpenFoundationModels:

```swift
public protocol LanguageModel: Sendable {
    func generate(transcript: Transcript, options: GenerationOptions?) async throws -> Transcript.Entry
    func stream(transcript: Transcript, options: GenerationOptions?) -> AsyncThrowingStream<Transcript.Entry, Error>
    var isAvailable: Bool { get }
    func supports(locale: Locale) -> Bool
}
```

**Implementation Status**:
- ✅ `generate(transcript:options:)` - Returns `Transcript.Entry` with complete response
- ✅ `stream(transcript:options:)` - Returns `AsyncThrowingStream<Transcript.Entry, Error>` for streaming
- ✅ `isAvailable` - Synchronous property (returns `true`)
- ✅ `supports(locale:)` - Returns `true` for all locales (OpenAI supports most languages)

### Additional Features

The implementation also provides extended capabilities:
- `generate(transcript:schema:options:)` - Structured output with explicit `GenerationSchema`
- `generate(transcript:generating:options:)` - Type-safe generation for `Generable` types
- `modelInfo` - Access to model metadata (`contextWindow`, `maxOutputTokens`, `capabilities`)

### Build Status

- ✅ Build succeeds: `swift build` completes without errors
- ✅ All tests pass: 245 tests in 12 suites
- ✅ No TODO/FIXME comments in source code

### Transcript Entry Types

The implementation correctly handles all Transcript.Entry types:

```swift
public enum Transcript.Entry {
    case instructions(Transcript.Instructions)
    case prompt(Transcript.Prompt)
    case response(Transcript.Response)
    case toolCalls(Transcript.ToolCalls)
    case toolOutput(Transcript.ToolOutput)
}
```

### TranscriptConverter

The `TranscriptConverter` utility handles conversion between OpenFoundationModels Transcript format and OpenAI API format:

- Converts Transcript entries to OpenAI ChatMessage array
- Extracts tool definitions for function calling
- Handles response format extraction for structured generation
- Supports JSON-based extraction with fallback methods
- Converts `GeneratedContent` to JSON for tool call arguments

### OpenAIModel

The `OpenAIModel` struct provides flexible model selection:

```swift
// Using predefined constants
let model1 = OpenAIModel.gpt41
let model2 = OpenAIModel.o3Mini

// Using string literals
let model3: OpenAIModel = "gpt-4.1-mini"

// Using explicit initialization with type hint
let model4 = OpenAIModel("custom-fine-tuned-model", type: .gpt)
```

Model properties available:
- `id: String` - Model identifier for API requests
- `modelType: ModelType` - `.gpt` or `.reasoning`
- `contextWindow: Int` - Maximum context size in tokens
- `maxOutputTokens: Int` - Maximum output tokens
- `capabilities: ModelCapabilities` - Feature flags (vision, functionCalling, etc.)
- `constraints: ParameterConstraints` - API parameter support

## Remark Tool Integration

### Overview
[Remark](https://github.com/1amageek/Remark) is a Swift library and command-line tool that converts HTML to Markdown and enables viewing JavaScript-containing pages. This is particularly useful for documentation generation and web content processing.

### Installation

#### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/1amageek/Remark.git", branch: "main")
]
```

#### Command Line Installation
```bash
git clone https://github.com/1amageek/Remark.git
cd Remark
make install
```

### Usage Examples

#### CLI Usage
```bash
# Basic HTML to Markdown conversion
remark https://example.com

# Include front matter for static site generators
remark --include-front-matter https://platform.openai.com/docs/models

# Process JavaScript-heavy pages
remark https://docs.openai.com/api
```

#### Swift Library Usage
```swift
import Remark

// Convert HTML to Markdown
let htmlContent = """
<h1>OpenAI Models</h1>
<p>GPT-4o is a multimodal model...</p>
"""

let remark = try Remark(htmlContent)
let markdown = remark.page
print(markdown)
```

### Integration with OpenFoundationModels-OpenAI

#### Documentation Generation
Use Remark to convert OpenAI documentation pages to Markdown for local reference:

```bash
# Convert model documentation
remark --include-front-matter https://platform.openai.com/docs/models > models.md

# Convert API reference
remark https://platform.openai.com/docs/api-reference/chat > api-reference.md
```

#### Web Content Processing
When building applications that need to process web content with OpenAI:

```swift
import Remark
import OpenFoundationModelsOpenAI
import OpenFoundationModels

// Extract content from web pages
let url = "https://example.com/article"
let htmlContent = try String(contentsOf: URL(string: url)!)
let remark = try Remark(htmlContent)

// Use extracted content with OpenAI via Transcript
let openAI = OpenAILanguageModel(apiKey: apiKey)
var transcript = Transcript()
transcript.append(.prompt(Transcript.Prompt(segments: [
    .text(Transcript.TextSegment(content: "Summarize this article:\n\(remark.page)"))
])))
let response = try await openAI.generate(transcript: transcript, options: nil)
```

#### Metadata Extraction
Remark automatically extracts Open Graph metadata, useful for content analysis:

```swift
let remark = try Remark(htmlContent)
print("Title: \(remark.title)")
print("Description: \(remark.description)")
print("Image: \(remark.image)")
```

### Common Use Cases

1. **API Documentation Processing**: Convert OpenAI's API docs to Markdown for offline reference
2. **Content Ingestion**: Process web articles for AI analysis
3. **Static Site Generation**: Extract content with proper front matter
4. **Research Material**: Convert research papers and documentation to readable format

## Testing Strategy and Methodology

### Testing Philosophy

This project follows a **structured testing approach** using Swift Testing framework to ensure comprehensive coverage and reliable validation of the OpenAI provider implementation.

### Core Testing Principles

1. **Incremental Implementation**: Tests are implemented one at a time, with each test fully completed and validated before proceeding to the next.

2. **Failure Analysis Protocol**: When any test fails, follow this analysis procedure:
   - **Step 1**: Determine if the test itself is incorrect (test bug)
   - **Step 2**: Analyze if the implementation has a defect (implementation bug)
   - **Step 3**: Verify expected behavior against OpenAI API documentation
   - **Step 4**: Make targeted fixes based on root cause analysis

3. **Structural Test Design**: Tests are organized in a hierarchical structure using Swift Testing's `@Suite` for logical grouping and clear separation of concerns.

### Test Implementation Methodology

#### Phase-Based Implementation
1. **Foundation Phase**: Core component tests (OpenAILanguageModel, basic functionality)
2. **API Layer Phase**: Request builders, response handlers, and serialization
3. **Streaming Phase**: Async operations, Server-Sent Events processing
4. **Error Handling Phase**: Comprehensive error scenarios and recovery
5. **Integration Phase**: End-to-end testing with live API (optional, requires API key)

#### Test Analysis and Debugging Process

When a test fails:

1. **Test Validation**:
   ```swift
   // Verify test expectations are correct
   #expect(actualValue == expectedValue, "Clear description of what should happen")
   ```

2. **Implementation Analysis**:
   ```swift
   // Add debug logging to understand actual behavior
   print("Expected: \(expected), Actual: \(actual)")
   ```

3. **Documentation Cross-Reference**:
   - Check OpenAI API documentation for correct behavior
   - Verify OpenFoundationModels protocol requirements
   - Validate against Apple Foundation Models β SDK compatibility

4. **Targeted Fix Implementation**:
   - Fix only the specific issue identified
   - Ensure fix doesn't break existing tests
   - Re-run affected test suite to validate

### Test Quality Assurance

#### Mock Strategy
- **Unit Tests**: Use mock implementations to isolate components
- **Integration Tests**: Use real HTTP client with stubbed responses
- **Live Tests**: Optional tests with real API for final validation

#### Coverage Requirements
- **Core Functionality**: 100% coverage of public APIs
- **Error Scenarios**: All documented error codes and network failures
- **Edge Cases**: Boundary conditions, rate limits, timeouts
- **Concurrency**: Thread safety and actor isolation compliance

#### Test Maintenance
- **Brittle Test Prevention**: Avoid testing implementation details
- **Clear Test Intent**: Each test has single, clear responsibility
- **Maintainable Assertions**: Use descriptive failure messages

### Swift Testing Framework Usage

#### Test Structure
```swift
@Suite("OpenAI Language Model Tests")
struct OpenAILanguageModelTests {
    
    @Test("Basic text generation")
    func testBasicGeneration() async throws {
        // Implementation
    }
    
    @Test("Generation with different models", arguments: [
        OpenAIModel.gpt4o,
        OpenAIModel.gpt4oMini,
        OpenAIModel.o3Mini
    ])
    func testGenerationWithModels(model: OpenAIModel) async throws {
        // Parameterized test implementation
    }
}
```

#### Async Testing Pattern
```swift
@Test("Streaming content delivery")
func testStreaming() async throws {
    var transcript = Transcript()
    transcript.append(.prompt(Transcript.Prompt(segments: [
        .text(Transcript.TextSegment(content: "test"))
    ])))

    // AsyncThrowingStream requires try-await
    for try await entry in model.stream(transcript: transcript, options: nil) {
        // Process entry
        break
    }
}
```

### Continuous Improvement

#### Test Metrics Tracking
- Test execution time monitoring
- Flaky test identification and resolution
- Coverage gap analysis and remediation

#### Documentation Updates
- Test results inform implementation documentation
- Edge case discoveries update API usage examples
- Performance insights guide optimization recommendations

This methodology ensures high-quality, maintainable tests that provide confidence in the OpenAI provider implementation while supporting future development and debugging efforts.

## Error Handling

### Error Types

The implementation provides structured error types:

```swift
// Model-specific errors
public enum OpenAIModelError: Error {
    case modelNotAvailable(String)
    case parameterNotSupported(parameter: String, model: String)
    case contextLengthExceeded(model: String, maxTokens: Int)
    case invalidRequest(String)
    case rateLimitExceeded
    case quotaExceeded
    case apiError(OpenAIAPIError)
}

// HTTP/Network errors
public enum OpenAIHTTPError: Error {
    case invalidURL(String)
    case networkError(Error)
    case invalidResponse
    case statusError(Int, Data?)
    case decodingError(Error)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case authenticationFailed
    case apiError(OpenAIAPIError)
    case timeout
}
```

### Rate Limiting

Built-in rate limiting with configurable tiers:

```swift
// Default configuration
let config = OpenAIConfiguration(
    apiKey: "sk-...",
    rateLimits: .default  // 3,500 RPM, 90,000 TPM
)

// Tier-specific configurations
.tier1   // 500 RPM, 30,000 TPM
.tier2   // 3,500 RPM, 90,000 TPM (same as default)
.tier3   // 10,000 RPM, 150,000 TPM
.unlimited  // No rate limiting
```

## Quick Reference

### Initialization Patterns

```swift
// Simple initialization (default: gpt-4.1)
let model = OpenAILanguageModel(apiKey: "sk-...")

// With specific model
let model = OpenAILanguageModel(apiKey: "sk-...", model: .gpt4o)

// With custom model string
let model = OpenAILanguageModel(apiKey: "sk-...", model: "gpt-4.1-mini")

// Full configuration
let config = OpenAIConfiguration(
    apiKey: "sk-...",
    baseURL: URL(string: "https://api.openai.com/v1")!,
    organization: "org-...",
    timeout: 120.0,
    retryPolicy: .exponentialBackoff(),
    rateLimits: .default
)
let model = OpenAILanguageModel(configuration: config, model: .gpt41)
```

### Generation Examples

```swift
// Basic generation
var transcript = Transcript()
transcript.append(.prompt(Transcript.Prompt(segments: [
    .text(Transcript.TextSegment(content: "Hello, world!"))
])))
let entry = try await model.generate(transcript: transcript, options: nil)

// Streaming
for try await entry in model.stream(transcript: transcript, options: nil) {
    if case .response(let response) = entry {
        // Process streamed response
    }
}

// Structured generation with Generable type
let (entry, result) = try await model.generate(
    transcript: transcript,
    generating: MyGenerableType.self
)
```

## Version Information

- **Library Version**: 2.1.0
- **Build Date**: 2025-01-13
- **Min Swift Version**: 6.0
- **Dependencies**: OpenFoundationModels only