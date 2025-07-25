# OpenFoundationModels-OpenAI

OpenAI provider for the [OpenFoundationModels](https://github.com/1amageek/OpenFoundationModels) framework, enabling the use of OpenAI's latest GPT and Reasoning models through Apple's Foundation Models API interface. Features a unified model interface with automatic constraint handling and self-contained architecture.

## Features

- 🤖 **Complete Model Support**: GPT-4o, GPT-4o Mini, GPT-4 Turbo, and all Reasoning models (o1, o1-pro, o3, o3-pro, o4-mini)
- 🧠 **Reasoning Models**: Native support for o1, o1-pro, o3, o3-pro, and o4-mini with automatic constraint handling
- 🔄 **Streaming Support**: Real-time response streaming with Server-Sent Events
- 🎯 **Unified Interface**: Single API for all models with automatic parameter validation
- 🔧 **Multimodal Support**: Text, image, and audio input support (GPT models only)
- 🚦 **Self-Contained**: No external dependencies beyond OpenFoundationModels
- ⚡ **Performance Optimized**: Custom HTTP client with actor-based concurrency
- 🛡️ **Type Safety**: Compile-time model validation and constraint checking

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

// Use with Apple's Foundation Models API
let session = LanguageModelSession(
    model: gptModel, // or reasoningModel
    guardrails: .default,
    tools: [],
    instructions: nil
)

// Generate text (parameters automatically validated for model type)
let response = try await session.respond {
    Prompt("Tell me about Swift programming")
}

print(response.content)
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

## Usage Examples

### Text Generation

```swift
// GPT model for general tasks
let gptModel = OpenAIModelFactory.gpt4o(apiKey: apiKey)
let response = try await gptModel.generate(
    prompt: "Explain quantum computing",
    options: GenerationOptions(
        temperature: 0.7,
        maxTokens: 1000
    )
)

// Reasoning model for complex problems (temperature automatically ignored)
let reasoningModel = OpenAIModelFactory.o3(apiKey: apiKey)
let solution = try await reasoningModel.generate(
    prompt: "Solve this complex mathematical proof step by step...",
    options: GenerationOptions(maxTokens: 2000)
)
```

### Streaming

```swift
let model = OpenAIModelFactory.gpt4o(apiKey: apiKey)
let stream = model.stream(prompt: "Write a story about AI")

for try await chunk in stream {
    print(chunk, terminator: "")
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

// Note: Structured generation requires OpenFoundationModels framework integration
let session = LanguageModelSession(
    model: OpenAIModelFactory.gpt4o(apiKey: apiKey),
    guardrails: .default,
    tools: [],
    instructions: nil
)

let review = try await session.generate(
    prompt: "Review the book '1984' by George Orwell",
    as: BookReview.self
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