# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the OpenAI provider implementation for OpenFoundationModels framework. It enables using OpenAI's latest GPT and Reasoning models (GPT-4o, o1, o3, o4-mini) through Apple's Foundation Models API interface with a unified, self-contained architecture.

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

2. **OpenAIModel**: Unified model enumeration
   - Single enum covering GPT-4o, Reasoning models (o1, o3, o4-mini)
   - Internal model type detection for automatic parameter validation
   - Model-specific capabilities and constraints

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
   - `stream(transcript:options:)` - Returns `AsyncStream<Transcript.Entry>` for streaming
   - `isAvailable` - Synchronous property checking API availability
   - `supports(locale:)` - Returns true (OpenAI supports most languages)
   - Extracts tools from `Transcript.Instructions.toolDefinitions`
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
├── OpenAIConfiguration.swift           # Configuration and model definitions
├── OpenFoundationModelsOpenAI.swift    # Public API and convenience initializers
├── Models/
│   └── OpenAIModel.swift               # Unified model enum with capabilities
├── HTTP/
│   └── OpenAIHTTPClient.swift          # Custom HTTP client implementation
├── API/
│   └── OpenAIAPITypes.swift            # OpenAI API data structures
└── Internal/
    ├── RequestBuilders.swift           # Model-specific request builders
    ├── ResponseHandlers.swift          # Model-specific response handlers
    └── StreamingHandler.swift          # Advanced streaming implementation
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

2. **Unified Model Interface**: Single OpenAIModel enum that internally handles GPT vs Reasoning model differences, providing a seamless user experience without model-specific APIs.

3. **Self-Contained Architecture**: No external dependencies beyond OpenFoundationModels, using custom URLSession-based HTTP client for maximum flexibility and control.

4. **Automatic Constraint Handling**: Internal model type detection automatically applies correct parameter constraints (e.g., temperature not supported for Reasoning models).

5. **Actor-Based Concurrency**: Rate limiting and HTTP client use Swift actors for thread-safe operation and optimal performance.

6. **Direct Instantiation Pattern**: Direct instantiation of request builders and response handlers based on model type, following Swift conventions without factory pattern.

7. **Advanced Streaming**: Server-Sent Events implementation with buffering, accumulation, and error handling for reliable real-time responses.

## Transcript Processing Implementation

### Overview
The OpenAI provider now fully supports OpenFoundationModels' Transcript-based interface, providing complete conversation context management.

### Transcript to OpenAI Message Conversion

```swift
// Convert Transcript entries to OpenAI ChatMessage format
internal extension Array where Element == ChatMessage {
    static func from(transcript: Transcript) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        
        for entry in transcript.entries {
            switch entry {
            case .instructions(let instructions):
                // System message with instructions
                let content = extractText(from: instructions.segments)
                messages.append(ChatMessage.system(content))
                
            case .prompt(let prompt):
                // User message
                let content = extractText(from: prompt.segments)
                messages.append(ChatMessage.user(content))
                
            case .response(let response):
                // Assistant message
                let content = extractText(from: response.segments)
                messages.append(ChatMessage.assistant(content))
                
            case .toolCalls:
                // Tool execution (placeholder for now)
                messages.append(ChatMessage.assistant("Tool calls executed"))
                
            case .toolOutput(let toolOutput):
                // Tool result
                messages.append(ChatMessage.system("Tool output: \(toolOutput.toolName)"))
            }
        }
        return messages
    }
}
```

### Tool Extraction from Transcript

```swift
private func extractTools(from transcript: Transcript) -> [Transcript.ToolDefinition]? {
    for entry in transcript.entries {
        if case .instructions(let instructions) = entry {
            return instructions.toolDefinitions
        }
    }
    return nil
}
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
    func stream(transcript: Transcript, options: GenerationOptions?) -> AsyncStream<Transcript.Entry>
    var isAvailable: Bool { get }
    func supports(locale: Locale) -> Bool
}
```

**Implementation Status**:
- ✅ `generate(transcript:options:)` - Returns `Transcript.Entry` with complete response
- ✅ `stream(transcript:options:)` - Returns `AsyncStream<Transcript.Entry>` for streaming
- ✅ `isAvailable` - Synchronous property (returns `true`)
- ✅ `supports(locale:)` - Returns `true` for all locales (OpenAI supports most languages)

### Build Status

- ✅ Build succeeds: `swift build` completes without errors
- ✅ All tests pass: 205 tests in 11 suites
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

    await confirmation("Stream delivers content") { confirm in
        for await entry in model.stream(transcript: transcript, options: nil) {
            confirm()
            break
        }
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