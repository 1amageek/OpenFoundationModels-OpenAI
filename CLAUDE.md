# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the OpenAI provider implementation for OpenFoundationModels framework. It enables using OpenAI models (GPT-3.5, GPT-4, GPT-4o) through Apple's Foundation Models API interface.

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
   - Handles both synchronous generation and streaming
   - Manages rate limiting and error handling
   - Supports structured generation via Function Calling

2. **OpenAIConfiguration**: Configuration management
   - API credentials and model selection
   - Rate limit configuration
   - Retry policies and timeouts

3. **Parameter Mapping**: Converts between Foundation Models API and OpenAI API
   - `GenerationOptions` → OpenAI `ChatQuery`
   - `Prompt` segments → OpenAI messages with multimodal support
   - `GenerationSchema` → OpenAI Function Calling schema

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

- OpenFoundationModels: Core framework providing protocols and types
- MacPaw/OpenAI: Swift client for OpenAI API
- Both should be added to Package.swift

### Module Structure

```
Sources/OpenFoundationModelsOpenAI/
├── OpenAILanguageModel.swift      # Main provider implementation
├── OpenAIConfiguration.swift      # Configuration and model definitions
├── OpenAIError.swift             # Error types and mapping
├── ParameterMapping.swift        # API parameter conversion
├── StructuredGeneration.swift    # Function Calling implementation
├── StreamingHandler.swift        # Streaming response handling
└── Extensions/                   # Convenience extensions
```

## Testing Strategy

- Mock the OpenAI client for unit tests
- Use environment variable for API key in integration tests
- Test rate limiting behavior with mock timestamps
- Verify error mapping for all OpenAI error codes
- Test streaming with various response patterns

## Important Design Decisions

1. **Function Calling for Structured Generation**: Instead of using response format, use OpenAI's Function Calling feature for reliable structured output generation.

2. **Rate Limiting**: Implement client-side rate limiting with configurable limits per model tier, using actor-based concurrency for thread safety.

3. **Model Selection**: Support all GPT models with proper context window limits and capability flags (vision, function calling).

4. **Error Mapping**: Map OpenAI-specific errors to generic `LanguageModelError` types while preserving detailed error information.

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