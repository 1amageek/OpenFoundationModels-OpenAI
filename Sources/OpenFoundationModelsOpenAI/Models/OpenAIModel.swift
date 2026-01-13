import Foundation

// MARK: - String-based OpenAI Model

/// OpenAI Model identifier supporting both predefined and custom models
public struct OpenAIModel: Sendable, Hashable, ExpressibleByStringLiteral {

    /// The model identifier string used in API requests
    public let id: String

    /// Model type hint for parameter handling
    public let modelType: ModelType

    // MARK: - Initialization

    /// Initialize with a model ID string and optional type hint
    public init(_ id: String, type: ModelType? = nil) {
        self.id = id
        self.modelType = type ?? Self.inferModelType(from: id)
    }

    /// Initialize from string literal
    public init(stringLiteral value: String) {
        self.init(value)
    }

    // MARK: - Predefined Models

    // GPT-4.1 Family (Latest)
    public static let gpt41 = OpenAIModel("gpt-4.1", type: .gpt)
    public static let gpt41Mini = OpenAIModel("gpt-4.1-mini", type: .gpt)
    public static let gpt41Nano = OpenAIModel("gpt-4.1-nano", type: .gpt)

    // GPT-4o Family
    public static let gpt4o = OpenAIModel("gpt-4o", type: .gpt)
    public static let gpt4oMini = OpenAIModel("gpt-4o-mini", type: .gpt)

    // GPT-4 Turbo
    public static let gpt4Turbo = OpenAIModel("gpt-4-turbo", type: .gpt)

    // Reasoning Family Models (o-series)
    public static let o1 = OpenAIModel("o1", type: .reasoning)
    public static let o1Pro = OpenAIModel("o1-pro", type: .reasoning)
    public static let o3 = OpenAIModel("o3", type: .reasoning)
    public static let o3Pro = OpenAIModel("o3-pro", type: .reasoning)
    public static let o3Mini = OpenAIModel("o3-mini", type: .reasoning)
    public static let o4Mini = OpenAIModel("o4-mini", type: .reasoning)

    // MARK: - Model Properties

    /// API name used in requests (same as id)
    public var apiName: String {
        return id
    }

    /// Context window size in tokens (estimated based on model type)
    public var contextWindow: Int {
        // GPT-4.1 series has larger context
        if id.hasPrefix("gpt-4.1") {
            return 1_047_576  // ~1M tokens
        }

        switch modelType {
        case .gpt:
            return 128_000
        case .reasoning:
            return 200_000
        }
    }

    /// Maximum output tokens (estimated based on model type)
    public var maxOutputTokens: Int {
        // GPT-4.1 series has larger output
        if id.hasPrefix("gpt-4.1") {
            return 32_768
        }

        switch modelType {
        case .gpt:
            return 16_384
        case .reasoning:
            return 100_000
        }
    }

    /// Model capabilities
    public var capabilities: ModelCapabilities {
        switch modelType {
        case .gpt:
            return [.textGeneration, .vision, .functionCalling, .streaming, .toolAccess]
        case .reasoning:
            return [.textGeneration, .reasoning, .functionCalling, .streaming, .toolAccess]
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
        return modelType == .reasoning
    }

    // MARK: - Model Type Inference

    /// Infer model type from model ID string
    private static func inferModelType(from id: String) -> ModelType {
        let lowercased = id.lowercased()

        // Reasoning models: o1, o3, o4 series
        if lowercased.hasPrefix("o1") ||
           lowercased.hasPrefix("o3") ||
           lowercased.hasPrefix("o4") {
            return .reasoning
        }

        // Default to GPT for all other models
        return .gpt
    }
}

// MARK: - Supporting Types

/// Model type for implementation switching
public enum ModelType: String, Sendable, Hashable {
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

// MARK: - CustomStringConvertible

extension OpenAIModel: CustomStringConvertible {
    public var description: String {
        return "\(id) (\(modelType.rawValue))"
    }
}

extension OpenAIModel: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        OpenAIModel(
            id: \(id),
            type: \(modelType.rawValue),
            contextWindow: \(contextWindow),
            maxOutput: \(maxOutputTokens)
        )
        """
    }
}

// MARK: - Codable Support

extension OpenAIModel: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        self.init(id)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

// MARK: - Equatable (based on id only)

extension OpenAIModel {
    public static func == (lhs: OpenAIModel, rhs: OpenAIModel) -> Bool {
        return lhs.id == rhs.id
    }
}
