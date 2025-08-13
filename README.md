# OpenFoundationModels-OpenAI

OpenAI provider for the [OpenFoundationModels](https://github.com/1amageek/OpenFoundationModels) framework, enabling the use of OpenAI's latest GPT and Reasoning models through Apple's Foundation Models API interface. Features a unified model interface with automatic constraint handling and self-contained architecture.

## Features

- 📜 **Transcript-Based Interface**: Full support for OpenFoundationModels' Transcript-centric design
- 🤖 **Complete Model Support**: GPT-4o, GPT-4o Mini, GPT-4 Turbo, and all Reasoning models (o1, o1-pro, o3, o3-pro, o4-mini)
- 🧠 **Reasoning Models**: Native support for o1, o1-pro, o3, o3-pro, and o4-mini with automatic constraint handling
- 🔄 **Streaming Support**: Real-time response streaming with Server-Sent Events
- 🎯 **Unified Interface**: Single API for all models with automatic parameter validation
- 🔧 **Multimodal Support**: Text, image, and audio input support (GPT models only)
- 🚦 **Self-Contained**: No external dependencies beyond OpenFoundationModels
- ⚡ **Performance Optimized**: Custom HTTP client with actor-based concurrency
- 🛡️ **Type Safety**: Compile-time model validation and constraint checking
- 🛠️ **Tool Support**: Automatic extraction and conversion of tool definitions from Transcript

## Installation

### Swift Package Manager

Add this package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/OpenFoundationModels-OpenAI.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/1amageek/OpenFoundationModels-OpenAI.git`

## Quick Start

```swift
import OpenFoundationModels
import OpenFoundationModelsOpenAI

// Simple model creation with convenience initializers
let gptModel = OpenAILanguageModel(apiKey: "your-openai-api-key", model: .gpt4o)
let reasoningModel = OpenAILanguageModel(apiKey: "your-openai-api-key", model: .o3)

// Use with LanguageModelSession (Transcript-based)
let session = LanguageModelSession(
    model: gptModel, // or reasoningModel
    tools: [],
    instructions: "You are a helpful assistant."
)

// Generate text - Session manages the Transcript
let response = try await session.respond(to: "Tell me about Swift programming")
print(response.content)

// Continue conversation - Transcript automatically updated
let followUp = try await session.respond(to: "What are its main features?")
print(followUp.content)
```

## Configuration

### Basic Model Creation

```swift
// Create with API key and model
let model = OpenAILanguageModel(apiKey: "your-api-key", model: .gpt4o)

// Create with default model (GPT-4o)
let defaultModel = OpenAILanguageModel(apiKey: "your-api-key")

// Create with custom base URL
let customModel = OpenAILanguageModel(
    apiKey: "your-api-key",
    model: .o3,
    baseURL: URL(string: "https://custom.openai.com/v1")!
)
```

### Advanced Configuration

```swift
// Create configuration with custom settings
let configuration = OpenAIConfiguration(
    apiKey: "your-api-key",
    timeout: 120.0,
    retryPolicy: .exponentialBackoff(maxAttempts: 3),
    rateLimits: .tier3
)

// Create model with custom configuration
let model = OpenAILanguageModel(configuration: configuration, model: .gpt4o)
```

## Supported Models

| Model Family | Model | Context Window | Max Output | Vision | Reasoning | Knowledge Cutoff |
|--------------|-------|----------------|------------|--------|-----------|------------------|
| **GPT** | gpt-4o | 128,000 | 16,384 | ✅ | ❌ | October 2023 |
| **GPT** | gpt-4o-mini | 128,000 | 16,384 | ✅ | ❌ | October 2023 |
| **GPT** | gpt-4-turbo | 128,000 | 4,096 | ✅ | ❌ | April 2024 |
| **Reasoning** | o1 | 200,000 | 32,768 | ❌ | ✅ | October 2023 |
| **Reasoning** | o1-pro | 200,000 | 65,536 | ❌ | ✅ | October 2023 |
| **Reasoning** | o3 | 200,000 | 32,768 | ❌ | ✅ | October 2023 |
| **Reasoning** | o3-pro | 200,000 | 65,536 | ❌ | ✅ | October 2023 |
| **Reasoning** | o4-mini | 200,000 | 16,384 | ❌ | ✅ | October 2023 |

## Model Constraints

### Parameter Support by Model Type

| Parameter | GPT Models | Reasoning Models | Notes |
|-----------|------------|------------------|-------|
| `temperature` | ✅ (0.0-2.0) | ❌ | Reasoning models use deterministic generation |
| `topP` | ✅ (0.0-1.0) | ❌ | Alternative to temperature for nucleus sampling |
| `frequencyPenalty` | ✅ (-2.0-2.0) | ❌ | Reduces repetition based on frequency |
| `presencePenalty` | ✅ (-2.0-2.0) | ❌ | Reduces repetition based on presence |
| `stop` | ✅ | ❌ | Custom stop sequences |
| `maxTokens` | ✅ | ⚠️ | Reasoning models use `maxCompletionTokens` |
| `stream` | ✅ | ✅ | All models support streaming |
| `functionCalling` | ✅ | ✅ | All models support function calling |

### Key Differences

1. **Temperature Control**: Reasoning models (o1, o3, etc.) do not support temperature, topP, or penalty parameters. They always use deterministic generation for consistent reasoning.

2. **Parameter Names**: 
   - GPT models: Use `max_tokens` parameter
   - Reasoning models: Use `max_completion_tokens` parameter

3. **Vision Support**: Only GPT models support image inputs. Reasoning models are text-only.

4. **Response Time**: Reasoning models typically take longer to respond due to their complex thinking process.

### Usage Example with Constraints

```swift
// GPT model - all parameters supported
let gptResponse = try await gptModel.generate(
    prompt: "Write a creative story",
    options: GenerationOptions(
        temperature: 0.9,        // ✅ Supported
        topP: 0.95,             // ✅ Supported
        maxTokens: 1000,        // ✅ Supported
        frequencyPenalty: 0.5   // ✅ Supported
    )
)

// Reasoning model - limited parameters
let reasoningResponse = try await reasoningModel.generate(
    prompt: "Solve this complex problem",
    options: GenerationOptions(
        temperature: 0.9,        // ❌ Ignored
        topP: 0.95,             // ❌ Ignored
        maxTokens: 2000,        // ⚠️ Converted to maxCompletionTokens
        frequencyPenalty: 0.5   // ❌ Ignored
    )
)
```

### Model Recommendations

- **GPT-4o**: Best for general-purpose tasks with vision support (standard tier)
- **GPT-4o Mini**: Cost-efficient option with vision capabilities (economy tier)
- **o3**: Advanced reasoning for complex problem-solving (standard tier)
- **o3-pro**: Highest reasoning capability for difficult tasks (premium tier)
- **o4-mini**: Cost-effective reasoning model (economy tier)

## Transcript-Based Architecture

OpenFoundationModels-OpenAI fully embraces the Transcript-centric design of OpenFoundationModels:

### How It Works

1. **LanguageModelSession** manages the conversation state via `Transcript`
2. **OpenAILanguageModel** receives the complete `Transcript` for each request
3. The provider converts `Transcript` entries to OpenAI's message format

### Transcript Entry Processing

```swift
// Internal conversion from Transcript to OpenAI messages
Transcript.Entry.instructions -> ChatMessage.system   // System instructions
Transcript.Entry.prompt -> ChatMessage.user          // User messages  
Transcript.Entry.response -> ChatMessage.assistant   // Assistant responses
Transcript.Entry.toolCalls -> ChatMessage.assistant  // Tool invocations
Transcript.Entry.toolOutput -> ChatMessage.system    // Tool results
```

### Direct Model Usage (Low-level)

```swift
// Create a Transcript manually (usually handled by LanguageModelSession)
var transcript = Transcript()

// Add instructions
transcript.entries.append(.instructions(
    Transcript.Instructions(
        segments: [.text(Transcript.TextSegment(content: "You are a helpful assistant."))]
    )
))

// Add user prompt
transcript.entries.append(.prompt(
    Transcript.Prompt(
        segments: [.text(Transcript.TextSegment(content: "What is Swift?"))]
    )
))

// Generate response using the transcript
let response = try await model.generate(
    transcript: transcript,
    options: GenerationOptions(maximumResponseTokens: 500)
)
```

### Benefits

- **Stateless Model**: OpenAILanguageModel doesn't maintain state between calls
- **Complete Context**: Every request includes the full conversation history
- **Provider Flexibility**: Clean separation between OpenFoundationModels and OpenAI APIs
- **Tool Support**: Automatic extraction of tool definitions from Instructions

## Usage Examples

### Text Generation with LanguageModelSession

```swift
// Create model
let model = OpenAILanguageModel(apiKey: apiKey, model: .gpt4o)

// Use with LanguageModelSession for automatic Transcript management
let session = LanguageModelSession(
    model: model,
    tools: [],
    instructions: "You are a helpful assistant."
)

// Generate response
let response = try await session.respond(to: "Explain quantum computing")
print(response.content)

// Reasoning model for complex problems
let reasoningModel = OpenAILanguageModel(apiKey: apiKey, model: .o3)
let reasoningSession = LanguageModelSession(model: reasoningModel)
let solution = try await reasoningSession.respond(
    to: "Solve this complex mathematical proof step by step...",
    options: GenerationOptions(maximumResponseTokens: 2000)
)
```

### Streaming

```swift
let model = OpenAILanguageModel(apiKey: apiKey, model: .gpt4o)
let session = LanguageModelSession(model: model)

// Stream response
let stream = session.streamResponse(to: "Write a story about AI")

for try await partial in stream {
    print(partial.content, terminator: "")
}
```

### Structured Generation

```swift
@Generable
struct BookReview {
    @Guide(description: "Book title")
    let title: String
    
    @Guide(description: "Rating from 1-5", .range(1...5))
    let rating: Int
    
    @Guide(description: "Review summary", .maxLength(200))
    let summary: String
}

// Create model and session
let model = OpenAILanguageModel(apiKey: apiKey, model: .gpt4o)
let session = LanguageModelSession(
    model: model,
    tools: [],
    instructions: "You are a literary critic."
)

// Generate structured response
let review = try await session.respond(
    to: "Review the book '1984' by George Orwell",
    generating: BookReview.self
)

print("Title: \(review.title)")
print("Rating: \(review.rating)/5")
print("Summary: \(review.summary)")
```

### Multimodal (Vision)

```swift
let imageData = // ... your image data
let prompt = Prompt.multimodal(
    text: "What's in this image?",
    image: imageData
)

let response = try await session.respond { prompt }
```

### Generation Options

```swift
// Creative writing (high temperature, diverse output)
let creative = GenerationOptions(
    temperature: 0.9,
    maxTokens: 2000,
    topP: 0.95
)

// Precise, factual responses (low temperature)
let precise = GenerationOptions(
    temperature: 0.1,
    maxTokens: 1000
)

// Code generation (structured, deterministic)
let coding = GenerationOptions(
    temperature: 0.0,
    maxTokens: 4000
)

// Conversational (balanced settings)
let chat = GenerationOptions(
    temperature: 0.7,
    maxTokens: 1500
)
```

## Rate Limiting

The provider includes built-in rate limiting with several predefined tiers:

```swift
// Tier 1: 500 RPM, 30K TPM
let config1 = OpenAIConfiguration(apiKey: apiKey, rateLimits: .tier1)

// Tier 2: 3,500 RPM, 90K TPM  
let config2 = OpenAIConfiguration(apiKey: apiKey, rateLimits: .tier2)

// Tier 3: 10,000 RPM, 150K TPM
let config3 = OpenAIConfiguration(apiKey: apiKey, rateLimits: .tier3)

// Custom rate limits
let custom = RateLimitConfiguration(
    requestsPerMinute: 1000,
    tokensPerMinute: 50000
)
```

## Error Handling

```swift
do {
    let response = try await openAI.generate(prompt: "Hello")
} catch let error as OpenAIModelError {
    switch error {
    case .rateLimitExceeded:
        print("Rate limited. Please try again later")
    case .contextLengthExceeded(let model, let maxTokens):
        print("Context too long for model \(model). Maximum: \(maxTokens) tokens")
    case .modelNotAvailable(let model):
        print("Model \(model) not available")
    case .parameterNotSupported(let parameter, let model):
        print("Parameter \(parameter) not supported by model \(model)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

## Requirements

- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+
- Swift 6.1+
- Xcode 16.0+

## Dependencies

- [OpenFoundationModels](https://github.com/1amageek/OpenFoundationModels) - Core framework (only dependency)

## Migration Guide

### From Prompt-based to Transcript-based Interface

The OpenFoundationModels framework has transitioned to a Transcript-centric design. Here's how to migrate:

#### Old Interface (Deprecated)
```swift
// Direct prompt-based calls
let response = try await model.generate(
    prompt: "Hello",
    options: options,
    tools: tools
)
```

#### New Interface (Transcript-based)
```swift
// Use LanguageModelSession for automatic Transcript management
let session = LanguageModelSession(model: model, tools: tools)
let response = try await session.respond(to: "Hello", options: options)

// Or use Transcript directly (low-level)
var transcript = Transcript()
transcript.entries.append(.prompt(/*...*/))
let response = try await model.generate(transcript: transcript, options: options)
```

### Key Changes

1. **LanguageModel Protocol**: Now accepts `Transcript` instead of `prompt` and `tools`
2. **Tool Management**: Tools are defined in `Transcript.Instructions.toolDefinitions`
3. **Conversation Context**: All history is contained in the `Transcript`
4. **Stateless Models**: Models no longer maintain conversation state

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📖 [Documentation](https://github.com/1amageek/OpenFoundationModels-OpenAI/wiki)
- 🐛 [Report Issues](https://github.com/1amageek/OpenFoundationModels-OpenAI/issues)
- 💬 [Discussions](https://github.com/1amageek/OpenFoundationModels-OpenAI/discussions)

## Related Projects

- [OpenFoundationModels](https://github.com/1amageek/OpenFoundationModels) - Core framework
- [OpenFoundationModels-Anthropic](https://github.com/1amageek/OpenFoundationModels-Anthropic) - Anthropic provider
- [OpenFoundationModels-Local](https://github.com/1amageek/OpenFoundationModels-Local) - Local model provider