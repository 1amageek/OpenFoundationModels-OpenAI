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