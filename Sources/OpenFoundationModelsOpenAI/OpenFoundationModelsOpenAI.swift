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
    /// Initialize with API key and model
    public convenience init(
        apiKey: String,
        model: OpenAIModel = .gpt4o
    ) {
        let configuration = OpenAIConfiguration(apiKey: apiKey)
        self.init(configuration: configuration, model: model)
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
}

// MARK: - Model Information and Utilities
public struct OpenAIModelInfo {
    
    /// Get all available models
    public static var allModels: [OpenAIModel] {
        return OpenAIModel.allCases
    }
    
    /// Get GPT models only
    public static var gptModels: [OpenAIModel] {
        return OpenAIModel.gptModels
    }
    
    /// Get reasoning models only
    public static var reasoningModels: [OpenAIModel] {
        return OpenAIModel.reasoningModels
    }
    
    /// Get models by pricing tier
    public static func models(withPricingTier tier: PricingTier) -> [OpenAIModel] {
        return OpenAIModel.models(withPricingTier: tier)
    }
    
    /// Get models with specific capability
    public static func models(withCapability capability: ModelCapabilities) -> [OpenAIModel] {
        return OpenAIModel.models(withCapability: capability)
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
    public static let version = "2.0.0"
    public static let buildDate = "2025-01-12"
    
    public static var supportedModels: [OpenAIModel] {
        return OpenAIModel.allCases
    }
    
    public static var frameworkInfo: String {
        return """
        OpenFoundationModels-OpenAI v\(version)
        Built: \(buildDate)
        Architecture: Self-contained HTTP client
        Supported Models: \(supportedModels.count) models including GPT and Reasoning families
        Dependencies: OpenFoundationModels only
        """
    }
    
    public static var capabilities: [String] {
        return [
            "Unified model interface",
            "Automatic constraint handling",
            "Built-in rate limiting",
            "Streaming support",
            "Multimodal input (vision, audio)",
            "Function calling",
            "Reasoning model support",
            "Retry logic with exponential backoff",
            "Type-safe model selection"
        ]
    }
}

// MARK: - Migration Helpers (for backward compatibility)
@available(*, deprecated, message: "Use OpenAILanguageModel(apiKey:model:) instead")
public func createOpenAIProvider(apiKey: String, model: OpenAIModel) -> OpenAILanguageModel {
    return OpenAILanguageModel(apiKey: apiKey, model: model)
}