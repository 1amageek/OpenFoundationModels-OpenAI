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

// MARK: - Factory Methods
public struct OpenAIModelFactory {
    
    /// Create a language model with API key and model
    public static func create(
        apiKey: String,
        model: OpenAIModel,
        baseURL: URL? = nil,
        organization: String? = nil
    ) -> OpenAILanguageModel {
        return OpenAILanguageModel.create(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            organization: organization
        )
    }
    
    /// Create GPT-4o instance (recommended for general use)
    public static func gpt4o(apiKey: String) -> OpenAILanguageModel {
        return OpenAILanguageModel.gpt4o(apiKey: apiKey)
    }
    
    /// Create GPT-4o Mini instance (cost-effective)
    public static func gpt4oMini(apiKey: String) -> OpenAILanguageModel {
        return OpenAILanguageModel.gpt4oMini(apiKey: apiKey)
    }
    
    /// Create o3 reasoning model instance
    public static func o3(apiKey: String) -> OpenAILanguageModel {
        return OpenAILanguageModel.o3(apiKey: apiKey)
    }
    
    /// Create o3 Pro reasoning model instance (highest capability)
    public static func o3Pro(apiKey: String) -> OpenAILanguageModel {
        return OpenAILanguageModel.o3Pro(apiKey: apiKey)
    }
    
    /// Create o4 Mini reasoning model instance
    public static func o4Mini(apiKey: String) -> OpenAILanguageModel {
        return OpenAILanguageModel.o4Mini(apiKey: apiKey)
    }
    
    /// Create with custom configuration
    public static func create(
        apiKey: String,
        model: OpenAIModel,
        configure: (inout OpenAIConfiguration) -> Void
    ) -> OpenAILanguageModel {
        return OpenAILanguageModel.create(
            apiKey: apiKey,
            model: model,
            configuration: configure
        )
    }
}

// MARK: - Preset Configurations
extension OpenAIModelFactory {
    
    /// Development configuration with conservative settings
    public static func development(apiKey: String, model: OpenAIModel = .gpt4oMini) -> OpenAILanguageModel {
        return create(apiKey: apiKey, model: model) { config in
            config = OpenAIConfiguration(
                apiKey: apiKey,
                rateLimits: .tier1,
                timeout: 60.0
            )
        }
    }
    
    /// Production configuration with optimized settings
    public static func production(apiKey: String, model: OpenAIModel = .gpt4o) -> OpenAILanguageModel {
        return create(apiKey: apiKey, model: model) { config in
            config = OpenAIConfiguration(
                apiKey: apiKey,
                rateLimits: .tier3,
                timeout: 120.0,
                retryPolicy: .exponentialBackoff(maxAttempts: 3)
            )
        }
    }
    
    /// High-performance configuration for reasoning tasks
    public static func reasoning(apiKey: String, model: OpenAIModel = .o3) -> OpenAILanguageModel {
        return create(apiKey: apiKey, model: model) { config in
            config = OpenAIConfiguration(
                apiKey: apiKey,
                rateLimits: .tier2,
                timeout: 180.0, // Reasoning models may take longer
                retryPolicy: .exponentialBackoff(maxAttempts: 2)
            )
        }
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
@available(*, deprecated, message: "Use OpenAIModelFactory.create(apiKey:model:) instead")
public func createOpenAIProvider(apiKey: String, model: OpenAIModel) -> OpenAILanguageModel {
    return OpenAIModelFactory.create(apiKey: apiKey, model: model)
}