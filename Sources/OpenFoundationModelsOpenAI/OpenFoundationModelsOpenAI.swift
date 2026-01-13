import Foundation

// MARK: - OpenFoundationModels-OpenAI
// OpenAI Provider for OpenFoundationModels Framework

/// OpenFoundationModels-OpenAI provides an OpenAI implementation of the LanguageModel protocol
/// from the OpenFoundationModels framework, enabling the use of OpenAI's GPT and Reasoning models
/// through Apple's Foundation Models API interface.

// MARK: - Public Exports

// Core Components
@_exported import OpenFoundationModels

// MARK: - Type Aliases for User Convenience
public typealias OpenAIProvider = OpenAILanguageModel
public typealias OpenAIConfig = OpenAIConfiguration

// MARK: - Convenience Initializers
extension OpenAILanguageModel {
    /// Initialize with API key and model (default: gpt-4.1)
    public convenience init(
        apiKey: String,
        model: OpenAIModel = .gpt41
    ) {
        let configuration = OpenAIConfiguration(apiKey: apiKey)
        self.init(configuration: configuration, model: model)
    }

    /// Initialize with API key and model ID string
    public convenience init(
        apiKey: String,
        model: String
    ) {
        let configuration = OpenAIConfiguration(apiKey: apiKey)
        self.init(configuration: configuration, model: OpenAIModel(model))
    }

    /// Initialize with API key, model, and custom base URL
    public convenience init(
        apiKey: String,
        model: OpenAIModel,
        baseURL: URL
    ) {
        let configuration = OpenAIConfiguration(
            apiKey: apiKey,
            baseURL: baseURL
        )
        self.init(configuration: configuration, model: model)
    }

    /// Initialize with API key, model ID string, and custom base URL
    public convenience init(
        apiKey: String,
        model: String,
        baseURL: URL
    ) {
        let configuration = OpenAIConfiguration(
            apiKey: apiKey,
            baseURL: baseURL
        )
        self.init(configuration: configuration, model: OpenAIModel(model))
    }
}

// MARK: - Model Information and Utilities
public struct OpenAIModelInfo {

    /// Predefined GPT models
    public static var gptModels: [OpenAIModel] {
        return [.gpt41, .gpt41Mini, .gpt41Nano, .gpt4o, .gpt4oMini, .gpt4Turbo]
    }

    /// Predefined reasoning models
    public static var reasoningModels: [OpenAIModel] {
        return [.o1, .o1Pro, .o3, .o3Pro, .o3Mini, .o4Mini]
    }

    /// All predefined models
    public static var allModels: [OpenAIModel] {
        return gptModels + reasoningModels
    }

    /// Get models with specific capability
    public static func models(withCapability capability: ModelCapabilities) -> [OpenAIModel] {
        return allModels.filter { $0.capabilities.contains(capability) }
    }

    /// Get vision-capable models
    public static var visionModels: [OpenAIModel] {
        return models(withCapability: .vision)
    }

    /// Get function calling capable models
    public static var functionCallingModels: [OpenAIModel] {
        return models(withCapability: .functionCalling)
    }
}

// MARK: - Version Information
public struct OpenFoundationModelsOpenAI {
    public static let version = "2.1.0"
    public static let buildDate = "2025-01-13"

    public static var supportedModels: [OpenAIModel] {
        return OpenAIModelInfo.allModels
    }

    public static var frameworkInfo: String {
        return """
        OpenFoundationModels-OpenAI v\(version)
        Built: \(buildDate)
        Architecture: Self-contained HTTP client
        Supported Models: Predefined + any custom model via string
        Dependencies: OpenFoundationModels only
        """
    }

    public static var capabilities: [String] {
        return [
            "Unified model interface",
            "String-based model selection",
            "Automatic constraint handling",
            "Built-in rate limiting",
            "Streaming support",
            "Multimodal input (vision, audio)",
            "Function calling",
            "Reasoning model support",
            "Retry logic with exponential backoff"
        ]
    }
}

// MARK: - Migration Helpers (for backward compatibility)
@available(*, deprecated, message: "Use OpenAILanguageModel(apiKey:model:) instead")
public func createOpenAIProvider(apiKey: String, model: OpenAIModel) -> OpenAILanguageModel {
    return OpenAILanguageModel(apiKey: apiKey, model: model)
}