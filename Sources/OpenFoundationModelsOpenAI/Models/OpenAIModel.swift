import Foundation

// MARK: - Unified OpenAI Model
public enum OpenAIModel: String, CaseIterable, Sendable {
    // GPT Family Models
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4Turbo = "gpt-4-turbo"
    
    // Reasoning Family Models (o-series)
    case o1 = "o1"
    case o1Pro = "o1-pro"
    case o3 = "o3"
    case o3Pro = "o3-pro"
    case o4Mini = "o4-mini"
    
    // MARK: - Model Properties
    
    /// API name used in requests
    public var apiName: String {
        return rawValue
    }
    
    /// Context window size in tokens
    public var contextWindow: Int {
        switch self {
        case .gpt4o, .gpt4oMini, .gpt4Turbo:
            return 128_000
        case .o1, .o1Pro, .o3, .o3Pro, .o4Mini:
            return 200_000 // Reasoning models typically have larger context
        }
    }
    
    /// Maximum output tokens
    public var maxOutputTokens: Int {
        switch self {
        case .gpt4o, .gpt4oMini:
            return 16_384
        case .gpt4Turbo:
            return 4_096
        case .o1, .o3:
            return 32_768
        case .o1Pro, .o3Pro:
            return 65_536
        case .o4Mini:
            return 16_384
        }
    }
    
    /// Model capabilities
    public var capabilities: ModelCapabilities {
        switch modelType {
        case .gpt:
            switch self {
            case .gpt4o, .gpt4Turbo:
                return [.textGeneration, .vision, .functionCalling, .streaming, .toolAccess]
            case .gpt4oMini:
                return [.textGeneration, .vision, .functionCalling, .streaming]
            default:
                return [.textGeneration, .functionCalling, .streaming]
            }
        case .reasoning:
            return [.textGeneration, .reasoning, .functionCalling, .streaming, .toolAccess]
        }
    }
    
    /// Pricing tier
    public var pricingTier: PricingTier {
        switch self {
        case .gpt4oMini, .o4Mini:
            return .economy
        case .gpt4o, .gpt4Turbo, .o1, .o3:
            return .standard
        case .o1Pro, .o3Pro:
            return .premium
        }
    }
    
    /// Knowledge cutoff date
    public var knowledgeCutoff: String {
        switch self {
        case .gpt4o, .gpt4oMini:
            return "October 2023"
        case .gpt4Turbo:
            return "April 2024"
        case .o1, .o1Pro, .o3, .o3Pro, .o4Mini:
            return "October 2023"
        }
    }
    
    // MARK: - Internal Properties
    
    /// Internal model type for behavior switching
    internal var modelType: ModelType {
        switch self {
        case .gpt4o, .gpt4oMini, .gpt4Turbo:
            return .gpt
        case .o1, .o1Pro, .o3, .o3Pro, .o4Mini:
            return .reasoning
        }
    }
    
    /// Internal parameter constraints
    internal var constraints: ParameterConstraints {
        switch modelType {
        case .gpt:
            return ParameterConstraints(
                supportsTemperature: true,
                supportsTopP: true,
                supportsFrequencyPenalty: true,
                supportsPresencePenalty: true,
                supportsStop: true,
                maxTokensParameterName: "max_tokens",
                temperatureRange: 0.0...2.0,
                topPRange: 0.0...1.0
            )
        case .reasoning:
            return ParameterConstraints(
                supportsTemperature: false,
                supportsTopP: false,
                supportsFrequencyPenalty: false,
                supportsPresencePenalty: false,
                supportsStop: false,
                maxTokensParameterName: "max_completion_tokens",
                temperatureRange: nil,
                topPRange: nil
            )
        }
    }
    
    /// Check if model supports vision
    public var supportsVision: Bool {
        return capabilities.contains(.vision)
    }
    
    /// Check if model supports function calling
    public var supportsFunctionCalling: Bool {
        return capabilities.contains(.functionCalling)
    }
    
    /// Check if model supports streaming
    public var supportsStreaming: Bool {
        return capabilities.contains(.streaming)
    }
    
    /// Check if model is a reasoning model
    public var isReasoningModel: Bool {
        return capabilities.contains(.reasoning)
    }
}

// MARK: - Supporting Types

/// Internal model type for implementation switching
internal enum ModelType: Sendable {
    case gpt
    case reasoning
}

/// Model capabilities using OptionSet
public struct ModelCapabilities: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let textGeneration = ModelCapabilities(rawValue: 1 << 0)
    public static let vision = ModelCapabilities(rawValue: 1 << 1)
    public static let functionCalling = ModelCapabilities(rawValue: 1 << 2)
    public static let reasoning = ModelCapabilities(rawValue: 1 << 3)
    public static let toolAccess = ModelCapabilities(rawValue: 1 << 4)
    public static let streaming = ModelCapabilities(rawValue: 1 << 5)
}

/// Parameter constraints for different model types
internal struct ParameterConstraints: Sendable {
    let supportsTemperature: Bool
    let supportsTopP: Bool
    let supportsFrequencyPenalty: Bool
    let supportsPresencePenalty: Bool
    let supportsStop: Bool
    let maxTokensParameterName: String
    let temperatureRange: ClosedRange<Double>?
    let topPRange: ClosedRange<Double>?
}

/// Pricing tiers
public enum PricingTier: String, CaseIterable, Sendable {
    case economy = "economy"
    case standard = "standard"
    case premium = "premium"
    
    public var description: String {
        switch self {
        case .economy:
            return "Cost-efficient models for basic tasks"
        case .standard:
            return "Balanced performance and cost"
        case .premium:
            return "Highest capability models with advanced features"
        }
    }
}

// MARK: - Model Extensions

extension OpenAIModel {
    /// Get all models of a specific type
    internal static func models(ofType type: ModelType) -> [OpenAIModel] {
        return allCases.filter { $0.modelType == type }
    }
    
    /// Get all GPT models
    public static var gptModels: [OpenAIModel] {
        return models(ofType: .gpt)
    }
    
    /// Get all reasoning models
    public static var reasoningModels: [OpenAIModel] {
        return models(ofType: .reasoning)
    }
    
    /// Get models by pricing tier
    public static func models(withPricingTier tier: PricingTier) -> [OpenAIModel] {
        return allCases.filter { $0.pricingTier == tier }
    }
    
    /// Get models with specific capability
    public static func models(withCapability capability: ModelCapabilities) -> [OpenAIModel] {
        return allCases.filter { $0.capabilities.contains(capability) }
    }
}

extension OpenAIModel: CustomStringConvertible {
    public var description: String {
        return "\(rawValue) (\(modelType), \(pricingTier.rawValue))"
    }
}

extension OpenAIModel: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        OpenAIModel(
            name: \(rawValue),
            type: \(modelType),
            contextWindow: \(contextWindow),
            maxOutput: \(maxOutputTokens),
            capabilities: \(capabilities),
            pricingTier: \(pricingTier),
            knowledgeCutoff: \(knowledgeCutoff)
        )
        """
    }
}