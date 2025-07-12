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

1. **Protocol Conformance**:
   - `generate(prompt:options:)` - Synchronous text generation
   - `stream(prompt:options:)` - Returns `AsyncStream<String>`
   - `isAvailable` - Async property checking API availability
   - `supports(locale:)` - Returns true (OpenAI supports most languages)

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
├── OpenFoundationModelsOpenAI.swift    # Public API and factory methods
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

1. **Unified Model Interface**: Single OpenAIModel enum that internally handles GPT vs Reasoning model differences, providing a seamless user experience without model-specific APIs.

2. **Self-Contained Architecture**: No external dependencies beyond OpenFoundationModels, using custom URLSession-based HTTP client for maximum flexibility and control.

3. **Automatic Constraint Handling**: Internal model type detection automatically applies correct parameter constraints (e.g., temperature not supported for Reasoning models).

4. **Actor-Based Concurrency**: Rate limiting and HTTP client use Swift actors for thread-safe operation and optimal performance.

5. **Model-Specific Builders**: Internal factory pattern creates appropriate request builders and response handlers based on model type while maintaining unified external API.

6. **Advanced Streaming**: Server-Sent Events implementation with buffering, accumulation, and error handling for reliable real-time responses.

## Build Fix Strategy

Based on research of OpenFoundationModels framework documentation and current build errors, the following strategy addresses critical compatibility issues:

### OpenFoundationModels Protocol Requirements

1. **LanguageModel Protocol Interface**:
   - `generate(prompt: String, options: GenerationOptions?) async throws -> String`
   - `stream(prompt: String, options: GenerationOptions?) -> AsyncStream<String>`
   - `supports(locale: Locale) -> Bool` (default: English support)
   - `isAvailable: Bool` (synchronous property)

2. **Prompt System Compatibility**:
   - OpenFoundationModels uses `Prompt` with `Prompt.Segment` containing `id` and `text`
   - Framework currently supports text-based prompts only
   - Multimodal content (images/audio) not yet supported in the framework
   - Need conversion extensions from `Prompt` to OpenAI `ChatMessage` format

3. **GenerationOptions Structure**:
   - `sampling: Sampling` (`.greedy` or `.random(topP: Double?)`)
   - `maxTokens: Int?` (token limit)
   - `temperature: Double?` (legacy parameter)
   - `topP: Double?` (legacy parameter)

### Critical Build Fixes Required

1. **AsyncStream Closure Signatures**: 
   - Current: `AsyncStream { continuation in }` expects wrong closure type
   - Fix: Use proper `AsyncStream<String>` constructor with correct continuation parameter

2. **Sendable Conformance Issues**:
   - Generic types in rate limiter need `Sendable` constraints
   - Actor isolation requires `Sendable` compliance for async operations

3. **Type Conversion Extensions**:
   - Missing `[ChatMessage].from(prompt: Prompt)` extension
   - Missing `[ChatMessage].from(prompt: String)` extension
   - Need proper conversion between OpenFoundationModels and OpenAI types

4. **API Type Structure Issues**:
   - Encoding problems with nested dictionaries in `ToolChoiceType`
   - Initialization conflicts in `TextPart` and `Tool` structs
   - Box wrapper needed for recursive `JSONSchemaProperty` type

5. **Streaming Implementation**:
   - AsyncStream extensions have incorrect closure signatures
   - Need proper continuation parameter handling

### Implementation Priority

**High Priority (Blocking Build)**:
1. Fix AsyncStream closure signatures in `OpenAILanguageModel.swift`
2. Add Sendable constraints to generic types in `RateLimiter`
3. Implement type conversion extensions

**Medium Priority (API Compatibility)**:
4. Fix encoding issues in `OpenAIAPITypes.swift`
5. Resolve initialization conflicts in API structures

**Low Priority (Code Quality)**:
6. Clean up unused variable warnings
7. Optimize error handling patterns

### Testing Strategy

After each fix:
1. Run `swift build` to verify compilation
2. Check for new errors or warnings
3. Validate protocol conformance
4. Test basic functionality if build succeeds

This strategy ensures step-by-step resolution of build issues while maintaining compatibility with the OpenFoundationModels framework specification.

## Detailed Implementation Analysis (Based on Remark Documentation Research)

### OpenFoundationModels Framework Deep Understanding

After thorough research using remark tool to extract complete documentation from the OpenFoundationModels repository, the following critical insights have been discovered:

#### 1. **Core Protocol Definition (Confirmed from Source)**

The LanguageModel protocol from OpenFoundationModels has the exact specification:

```swift
public protocol LanguageModel: Sendable {
    func generate(prompt: String, options: GenerationOptions?) async throws -> String
    func stream(prompt: String, options: GenerationOptions?) -> AsyncStream<String>
    var isAvailable: Bool { get }
    func supports(locale: Locale) -> Bool
}
```

**Key Findings**:
- `isAvailable` is a **synchronous** property (not async)
- `stream` returns `AsyncStream<String>` (not AsyncThrowingStream)
- Default implementation for `supports(locale:)` returns `true` for English only
- Protocol conforms to `Sendable`

#### 2. **Apple Foundation Models β SDK Compatibility Requirements**

From APPLE_API_REFERENCE.md research:

- **100% API Compatibility**: Code migration requires only import statement change
- **GenerationSchema System**: Apple uses proprietary GenerationSchema (NOT JSONSchema)
- **Complex Type Hierarchy**: Transcript contains nested types with namespace conflicts
- **Exact Protocol Inheritance**: All inheritance chains must match Apple specifications

#### 3. **Critical Type System Discoveries**

**Namespace Conflicts Identified**:
- `ToolCall` exists both as top-level and `Transcript.ToolCall`
- `ToolOutput` exists both as top-level and `Transcript.ToolOutput`
- `Instructions` exists both as top-level and `Transcript.Instructions`

**Transcript Entry Structure (Confirmed)**:
```swift
public enum Entry {
    case prompt(Transcript.Prompt)
    case response(Transcript.Response)
    case instructions(Transcript.Instructions)    // Has associated value
    case toolCalls(Transcript.ToolCalls)         // Has associated value
    case toolOutput(Transcript.ToolOutput)       // Has associated value
}
```

#### 4. **Generable Protocol and Macro System**

**@Generable Macro Specification (Confirmed)**:
```swift
@attached(extension, conformances: Generable, names: named(init(_:)), named(generatedContent))
@attached(member, names: arbitrary)
public macro Generable(description: String? = nil)
```

**Generated Methods**:
- `init(_ generatedContent: GeneratedContent)` (NOT generationSchema)
- `generatedContent: GeneratedContent` property (NOT PartiallyGenerated)

#### 5. **SystemLanguageModel Integration Pattern**

**Confirmed API Structure**:
```swift
public final class SystemLanguageModel: Observable, Sendable, SendableMetatype, Copyable {
    public static let `default`: SystemLanguageModel
    public var isAvailable: Bool { get }
    public var availability: SystemLanguageModel.Availability { get }
    public var supportedLanguages: Set<Locale.Language> { get }
}
```

### Build Fix Implementation Strategy (Evidence-Based)

#### Phase 1: Protocol Compliance (CRITICAL)

1. **Fix LanguageModel Protocol Implementation**:
   - Change `isAvailable` from async to sync property
   - Ensure `stream` returns `AsyncStream<String>` not `AsyncThrowingStream`
   - Implement proper `supports(locale:)` with English default

2. **Fix AsyncStream Constructor Issues**:
   - Current error: Wrong closure signature for AsyncStream
   - Solution: Use `AsyncStream<String> { continuation in ... }`
   - Ensure proper continuation parameter handling

#### Phase 2: Type System Corrections (HIGH PRIORITY)

1. **Resolve Sendable Constraints**:
   - Add `where T: Sendable` constraints to generic functions
   - Fix rate limiter generic types for actor isolation compliance

2. **Implement Missing Type Conversions**:
   - Create `[ChatMessage].from(prompt: String)` extension
   - Create `[ChatMessage].from(prompt: Prompt)` extension for future Prompt support
   - Implement proper GenerationOptions to OpenAI parameter mapping

#### Phase 3: API Structure Fixes (MEDIUM PRIORITY)

1. **Fix OpenAI API Types Encoding Issues**:
   - Resolve `ToolChoiceType` encoding with proper Codable structures
   - Fix initialization conflicts in `TextPart` and `Tool`
   - Implement proper Box wrapper for recursive types

2. **Streaming Implementation Corrections**:
   - Fix AsyncStream extension closure signatures
   - Implement proper Server-Sent Events handling
   - Ensure continuation parameter compatibility

#### Phase 4: Future Compatibility Preparation (LOW PRIORITY)

1. **Prompt System Preparation**:
   - OpenFoundationModels currently supports text-only prompts
   - Multimodal support (images/audio) not yet in the framework
   - Prepare conversion layer for future multimodal support

2. **Schema System Migration Path**:
   - Current: Using JSONSchema (incompatible with Apple)
   - Future: Must migrate to GenerationSchema system
   - Prepare abstraction layer for schema system transition

### Testing and Validation Strategy

#### Compilation Verification Process

1. **Immediate Build Fix Validation**:
   ```bash
   swift build  # Must succeed without errors
   ```

2. **Protocol Conformance Testing**:
   ```swift
   // Verify LanguageModel protocol compliance
   let model: LanguageModel = OpenAILanguageModel(...)
   let available: Bool = model.isAvailable  // Must be sync
   let stream: AsyncStream<String> = model.stream(...)  // Must be AsyncStream
   ```

3. **Type Safety Verification**:
   ```swift
   // Verify Sendable compliance
   let rateLimitedOperation: () async throws -> String = { ... }  // Must be Sendable
   ```

#### Progressive Implementation Testing

1. **Build Error Resolution**:
   - Fix one error category at a time
   - Run `swift build` after each fix
   - Document any new errors discovered

2. **Runtime Behavior Validation**:
   - Test streaming functionality
   - Verify rate limiting behavior
   - Validate error handling paths

### Documentation Integration Requirements

#### CLAUDE.md Documentation Updates

1. **Protocol Compliance Section**:
   - Document exact LanguageModel protocol requirements
   - Explain synchronous vs asynchronous property differences
   - Detail AsyncStream vs AsyncThrowingStream usage

2. **Type System Documentation**:
   - Document namespace conflict resolutions
   - Explain Sendable constraint requirements
   - Detail type conversion strategies

3. **Future Migration Path**:
   - Document GenerationSchema migration requirements
   - Explain multimodal support preparation
   - Detail Apple compatibility requirements

This comprehensive analysis based on actual OpenFoundationModels framework research ensures that our implementation will achieve 100% compatibility with Apple's Foundation Models β SDK while maintaining the unified interface design goals.

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

// Extract content from web pages
let url = "https://example.com/article"
let htmlContent = try String(contentsOf: URL(string: url)!)
let remark = try Remark(htmlContent)

// Use extracted content with OpenAI
let openAI = OpenAILanguageModel.create(apiKey: apiKey)
let summary = try await openAI.generate(
    prompt: "Summarize this article:\n\(remark.page)",
    options: .precise(for: .gpt4o)
)
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