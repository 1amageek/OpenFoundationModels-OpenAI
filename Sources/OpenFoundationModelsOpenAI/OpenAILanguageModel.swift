import Foundation
import OpenFoundationModels

/// OpenAI Language Model Provider for OpenFoundationModels
public final class OpenAILanguageModel: LanguageModel, @unchecked Sendable {
    
    // MARK: - Properties
    private let httpClient: OpenAIHTTPClient
    private let model: OpenAIModel
    private let requestBuilder: any RequestBuilder
    private let responseHandler: any ResponseHandler
    private let rateLimiter: RateLimiter
    
    // MARK: - Apple Foundation Models Protocol Compliance
    public var isAvailable: Bool {
        // For simplicity, return true - actual availability can be checked during request
        return true
    }
    
    // MARK: - Initialization
    public init(
        configuration: OpenAIConfiguration,
        model: OpenAIModel
    ) {
        self.httpClient = OpenAIHTTPClient(configuration: configuration)
        self.model = model
        // Direct instantiation based on model type
        switch model.modelType {
        case .gpt:
            self.requestBuilder = GPTRequestBuilder()
            self.responseHandler = GPTResponseHandler()
        case .reasoning:
            self.requestBuilder = ReasoningRequestBuilder()
            self.responseHandler = ReasoningResponseHandler()
        }
        self.rateLimiter = RateLimiter(configuration: configuration.rateLimits)
    }
    
    // MARK: - LanguageModel Protocol Implementation
    public func generate(prompt: String, options: GenerationOptions?) async throws -> String {
        try await withRateLimit { [self] in
            let messages = [ChatMessage].from(prompt: prompt)
            let request = try requestBuilder.buildChatRequest(
                model: model,
                messages: messages,
                options: options
            )
            
            do {
                let response: ChatCompletionResponse = try await httpClient.send(request)
                return try responseHandler.extractContent(from: response)
            } catch {
                throw responseHandler.handleError(error, for: model)
            }
        }
    }
    
    public func stream(prompt: String, options: GenerationOptions?) -> AsyncStream<String> {
        AsyncStream<String> { continuation in
            Task {
                do {
                    try await withRateLimit { [self] in
                        let messages = [ChatMessage].from(prompt: prompt)
                        let request = try requestBuilder.buildStreamRequest(
                            model: model,
                            messages: messages,
                            options: options
                        )
                        
                        let streamHandler = StreamingHandler()
                        
                        for try await data in await httpClient.stream(request) {
                            do {
                                if let chunks = try streamHandler.processStreamData(data) {
                                    for chunk in chunks {
                                        if let content = try responseHandler.extractStreamContent(from: chunk) {
                                            continuation.yield(content)
                                        }
                                    }
                                }
                            } catch {
                                continuation.finish()
                                return
                            }
                        }
                        
                        continuation.finish()
                    }
                } catch {
                    continuation.finish()
                }
            }
        }
    }
    
    public func supports(locale: Locale) -> Bool {
        // OpenAI models support most languages
        return true
    }
    
    // MARK: - Enhanced API
    
    /// Generate with Prompt object support
    public func generate(prompt: Prompt, options: GenerationOptions?) async throws -> String {
        try await withRateLimit { [self] in
            let messages = [ChatMessage].from(prompt: prompt)
            let request = try requestBuilder.buildChatRequest(
                model: model,
                messages: messages,
                options: options
            )
            
            do {
                let response: ChatCompletionResponse = try await httpClient.send(request)
                return try responseHandler.extractContent(from: response)
            } catch {
                throw responseHandler.handleError(error, for: model)
            }
        }
    }
    
    /// Stream with Prompt object support
    public func stream(prompt: Prompt, options: GenerationOptions?) -> AsyncStream<String> {
        AsyncStream<String> { continuation in
            Task {
                do {
                    try await withRateLimit { [self] in
                        let messages = [ChatMessage].from(prompt: prompt)
                        let request = try requestBuilder.buildStreamRequest(
                            model: model,
                            messages: messages,
                            options: options
                        )
                        
                        let streamHandler = StreamingHandler()
                        
                        for try await data in await httpClient.stream(request) {
                            do {
                                if let chunks = try streamHandler.processStreamData(data) {
                                    for chunk in chunks {
                                        if let content = try responseHandler.extractStreamContent(from: chunk) {
                                            continuation.yield(content)
                                        }
                                    }
                                }
                            } catch {
                                continuation.finish()
                                return
                            }
                        }
                        
                        continuation.finish()
                    }
                } catch {
                    continuation.finish()
                }
            }
        }
    }
    
    /// Get model information
    public var modelInfo: ModelInfo {
        return ModelInfo(
            name: model.apiName,
            contextWindow: model.contextWindow,
            maxOutputTokens: model.maxOutputTokens,
            capabilities: model.capabilities,
            pricingTier: model.pricingTier,
            knowledgeCutoff: model.knowledgeCutoff,
            supportsVision: model.supportsVision,
            supportsFunctionCalling: model.supportsFunctionCalling,
            isReasoningModel: model.isReasoningModel
        )
    }
    
    // MARK: - Private Methods
    
    private func checkAvailability() async -> Bool {
        do {
            // Simple health check by making a minimal request
            let request = try requestBuilder.buildChatRequest(
                model: model,
                messages: [ChatMessage.user("test")],
                options: GenerationOptions(maxTokens: 1)
            )
            
            let _: ChatCompletionResponse = try await httpClient.send(request)
            return true
        } catch {
            return false
        }
    }
    
    private func withRateLimit<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await rateLimiter.execute(operation)
    }
}

// MARK: - Model Information
public struct ModelInfo: Sendable {
    public let name: String
    public let contextWindow: Int
    public let maxOutputTokens: Int
    public let capabilities: ModelCapabilities
    public let pricingTier: PricingTier
    public let knowledgeCutoff: String
    public let supportsVision: Bool
    public let supportsFunctionCalling: Bool
    public let isReasoningModel: Bool
}

// MARK: - Rate Limiter
public actor RateLimiter {
    private let configuration: RateLimitConfiguration
    private var requestTimestamps: [Date] = []
    private var tokenCount: Int = 0
    private var lastReset: Date = Date()
    
    internal init(configuration: RateLimitConfiguration) {
        self.configuration = configuration
    }
    
    internal func execute<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        if configuration.enableBackoff {
            try await waitIfNeeded()
        }
        
        let result = try await operation()
        recordRequest()
        return result
    }
    
    private func waitIfNeeded() async throws {
        let now = Date()
        
        // Clean up timestamps older than 1 minute
        let oneMinuteAgo = now.addingTimeInterval(-60)
        requestTimestamps = requestTimestamps.filter { $0 > oneMinuteAgo }
        
        // Check if we're at the rate limit
        if requestTimestamps.count >= configuration.requestsPerMinute {
            // Calculate wait time
            if let oldestTimestamp = requestTimestamps.first {
                let waitTime = oldestTimestamp.addingTimeInterval(60).timeIntervalSince(now)
                if waitTime > 0 {
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }
    }
    
    private func recordRequest() {
        requestTimestamps.append(Date())
    }
}


// MARK: - Convenience Extensions
extension OpenAILanguageModel {
    
    /// Estimate token count for text (rough estimation)
    public func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token for English
        return max(1, text.count / 4)
    }
    
    /// Check if prompt would exceed context window
    public func wouldExceedContext(_ prompt: String) -> Bool {
        let estimatedTokens = estimateTokenCount(prompt)
        return estimatedTokens > model.contextWindow
    }
    
    /// Truncate text to fit within context window
    public func truncateToContext(_ text: String, reserveTokens: Int = 1000) -> String {
        let maxTokens = model.contextWindow - reserveTokens
        let maxCharacters = maxTokens * 4 // Rough estimation
        
        if text.count <= maxCharacters {
            return text
        }
        
        let truncated = String(text.prefix(maxCharacters))
        
        // Try to truncate at a word boundary
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace])
        }
        
        return truncated
    }
    
    /// Execute with retry logic
    public func withRetry<T>(
        maxAttempts: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as OpenAIModelError {
                lastError = error
                
                // Check if error is retryable
                switch error {
                case .rateLimitExceeded:
                    if attempt < maxAttempts {
                        let delay = TimeInterval(attempt * attempt) // Exponential backoff
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                case .modelNotAvailable, .parameterNotSupported, .contextLengthExceeded, .quotaExceeded:
                    // Non-retryable errors
                    throw error
                default:
                    if attempt < maxAttempts {
                        let delay = TimeInterval(attempt)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }
                
                throw error
            } catch {
                lastError = error
                
                // For other errors, retry if network-related
                if error is URLError && attempt < maxAttempts {
                    let delay = TimeInterval(attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw error
            }
        }
        
        throw lastError ?? OpenAIModelError.apiError(
            OpenAIAPIError(message: "Max retry attempts exceeded", type: nil, param: nil, code: nil)
        )
    }
}