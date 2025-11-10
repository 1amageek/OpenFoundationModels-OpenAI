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
    public func generate(transcript: Transcript, options: GenerationOptions?) async throws -> Transcript.Entry {
        try await withRateLimit { [self] in
            // Use TranscriptConverter for all conversions
            let messages = TranscriptConverter.buildMessages(from: transcript)
            let tools = TranscriptConverter.extractTools(from: transcript)
            let responseFormat = TranscriptConverter.extractResponseFormatWithSchema(from: transcript)
            let finalOptions = options ?? TranscriptConverter.extractOptions(from: transcript)
            
            // Build request with response format if present
            let request = try buildChatRequestWithFormat(
                model: model,
                messages: messages,
                options: finalOptions,
                tools: tools,
                responseFormat: responseFormat,
                stream: false
            )
            
            do {
                let response: ChatCompletionResponse = try await httpClient.send(request)
                
                // Check if response contains tool calls
                if let toolCalls = responseHandler.extractToolCalls(from: response),
                   !toolCalls.isEmpty {
                    // Convert OpenAI tool calls to Transcript.ToolCalls
                    let transcriptToolCalls = convertToTranscriptToolCalls(toolCalls)
                    return .toolCalls(transcriptToolCalls)
                }
                
                // Otherwise, extract text content and return as response
                let content = try responseHandler.extractContent(from: response)
                let responseEntry = Transcript.Response(
                    assetIDs: [],
                    segments: [.text(Transcript.TextSegment(content: content))]
                )
                return .response(responseEntry)
            } catch {
                throw responseHandler.handleError(error, for: model)
            }
        }
    }
    
    public func stream(transcript: Transcript, options: GenerationOptions?) -> AsyncThrowingStream<Transcript.Entry, Error> {
        AsyncThrowingStream<Transcript.Entry, Error> { continuation in
            Task {
                do {
                    try await withRateLimit { [self] in
                        // Use TranscriptConverter for all conversions
                        let messages = TranscriptConverter.buildMessages(from: transcript)
                        let tools = TranscriptConverter.extractTools(from: transcript)
                        let responseFormat = TranscriptConverter.extractResponseFormatWithSchema(from: transcript)
                        let finalOptions = options ?? TranscriptConverter.extractOptions(from: transcript)

                        let request = try buildChatRequestWithFormat(
                            model: model,
                            messages: messages,
                            options: finalOptions,
                            tools: tools,
                            responseFormat: responseFormat,
                            stream: true
                        )

                        let streamHandler = StreamingHandler()
                        var accumulatedContent = ""
                        var accumulatedToolCalls: [OpenAIToolCall] = []

                        for try await data in await httpClient.stream(request) {
                            do {
                                if let chunks = try streamHandler.processStreamData(data) {
                                    for chunk in chunks {
                                        // Check if this is a tool call response
                                        if let choice = chunk.choices.first {
                                            // Handle tool calls in stream
                                            let delta = choice.delta
                                            if let toolCalls = delta.toolCalls {
                                                // Accumulate tool calls
                                                for toolCall in toolCalls {
                                                    if let existingIndex = accumulatedToolCalls.firstIndex(where: { $0.id == toolCall.id }) {
                                                        // Update existing tool call by appending arguments
                                                        let existing = accumulatedToolCalls[existingIndex]
                                                        let updatedToolCall = OpenAIToolCall(
                                                            id: existing.id,
                                                            type: existing.type,
                                                            function: OpenAIToolCall.FunctionCall(
                                                                name: existing.function.name,
                                                                arguments: existing.function.arguments + toolCall.function.arguments
                                                            )
                                                        )
                                                        accumulatedToolCalls[existingIndex] = updatedToolCall
                                                    } else {
                                                        // Add new tool call
                                                        accumulatedToolCalls.append(toolCall)
                                                    }
                                                }
                                            } else if let content = delta.content {
                                                // Regular content
                                                accumulatedContent += content
                                                let responseEntry = Transcript.Response(
                                                    assetIDs: [],
                                                    segments: [.text(Transcript.TextSegment(content: accumulatedContent))]
                                                )
                                                continuation.yield(.response(responseEntry))
                                            }

                                            // Check for finish reason
                                            if choice.finishReason == "tool_calls" && !accumulatedToolCalls.isEmpty {
                                                // Yield the accumulated tool calls
                                                let transcriptToolCalls = convertToTranscriptToolCalls(accumulatedToolCalls)
                                                continuation.yield(.toolCalls(transcriptToolCalls))
                                            }
                                        }
                                    }
                                }
                            } catch {
                                continuation.finish(throwing: error)
                                return
                            }
                        }

                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func supports(locale: Locale) -> Bool {
        // OpenAI models support most languages
        return true
    }
    
    // MARK: - Structured Output with GenerationSchema
    
    /// Generate with explicit JSON Schema for structured output
    /// - Parameters:
    ///   - transcript: The conversation transcript
    ///   - schema: The GenerationSchema to use for structured output
    ///   - options: Generation options
    /// - Returns: The generated transcript entry
    public func generate(
        transcript: Transcript,
        schema: GenerationSchema,
        options: GenerationOptions? = nil
    ) async throws -> Transcript.Entry {
        try await withRateLimit { [self] in
            // Use TranscriptConverter for message building
            let messages = TranscriptConverter.buildMessages(from: transcript)
            let tools = TranscriptConverter.extractTools(from: transcript)
            
            // Convert GenerationSchema to ResponseFormat
            let responseFormat = convertSchemaToResponseFormat(schema)
            let finalOptions = options ?? TranscriptConverter.extractOptions(from: transcript)
            
            // Build request with JSON Schema format
            let request = try buildChatRequestWithFormat(
                model: model,
                messages: messages,
                options: finalOptions,
                tools: tools,
                responseFormat: responseFormat,
                stream: false
            )
            
            // Send request
            let response: ChatCompletionResponse = try await httpClient.send(request)
            
            // Handle tool calls if present
            if let toolCalls = responseHandler.extractToolCalls(from: response),
               !toolCalls.isEmpty {
                return .toolCalls(convertToTranscriptToolCalls(toolCalls))
            }
            
            // Return normal response
            let content = try responseHandler.extractContent(from: response)
            return createResponseEntry(content: content)
        }
    }
    
    /// Generate with a Generable type for structured output
    /// - Parameters:
    ///   - transcript: The conversation transcript
    ///   - type: The Generable type to use for structured output
    ///   - options: Generation options
    /// - Returns: The generated transcript entry with structured content
    public func generate<T: Generable>(
        transcript: Transcript,
        generating type: T.Type,
        options: GenerationOptions? = nil
    ) async throws -> (entry: Transcript.Entry, content: T) {
        // Get the schema from the Generable type
        let schema = T.generationSchema
        
        // Generate with the schema
        let entry = try await generate(transcript: transcript, schema: schema, options: options)
        
        // Parse the response content
        guard case .response(let response) = entry else {
            throw OpenAILanguageModelError.unexpectedResponse("Expected response entry, got \(entry)")
        }
        
        // Extract the content and parse it
        let content = extractTextFromSegments(response.segments)
        let generatedContent = try GeneratedContent(json: content)
        let parsedContent = try T(generatedContent)
        
        return (entry, parsedContent)
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
                options: GenerationOptions(maximumResponseTokens: 1),
                tools: nil
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
    
    // MARK: - Private Helper Methods
    
    /// Build chat request with optional response format
    private func buildChatRequestWithFormat(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Tool]?,
        responseFormat: ResponseFormat?,
        stream: Bool
    ) throws -> OpenAIHTTPRequest {
        // Create the appropriate request based on request builder type
        if stream {
            // For streaming, we need to build a stream request
            // but also include response format in the underlying ChatCompletionRequest
            return try requestBuilder.buildStreamRequest(
                model: model,
                messages: messages,
                options: options,
                tools: tools?.map { tool in
                    Transcript.ToolDefinition(
                        name: tool.function.name,
                        description: tool.function.description ?? "",
                        parameters: GenerationSchema(type: String.self, description: "", properties: [])
                    )
                }
            )
        } else {
            return try requestBuilder.buildChatRequest(
                model: model,
                messages: messages,
                options: options,
                tools: tools?.map { tool in
                    Transcript.ToolDefinition(
                        name: tool.function.name,
                        description: tool.function.description ?? "",
                        parameters: GenerationSchema(type: String.self, description: "", properties: [])
                    )
                }
            )
        }
    }
    
    /// Convert GenerationSchema to ResponseFormat
    private func convertSchemaToResponseFormat(_ schema: GenerationSchema) -> ResponseFormat {
        // Encode GenerationSchema to get JSON Schema
        do {
            let encoder = JSONEncoder()
            let schemaData = try encoder.encode(schema)
            
            // Convert to JSON dictionary
            if let schemaJson = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
                // Transform to OpenAI's expected JSON Schema format
                let transformedSchema = transformToOpenAIJSONSchema(schemaJson)
                return .jsonSchema(transformedSchema)
            }
        } catch {
            print("Warning: Failed to convert GenerationSchema to ResponseFormat: \(error)")
        }
        
        // Fallback to JSON mode
        return .json
    }
    
    /// Transform GenerationSchema JSON to OpenAI's JSON Schema format
    private func transformToOpenAIJSONSchema(_ json: [String: Any]) -> [String: Any] {
        var schema: [String: Any] = [:]
        
        // Extract type (default to "object")
        schema["type"] = json["type"] as? String ?? "object"
        
        // Extract and transform properties
        if let properties = json["properties"] as? [String: [String: Any]] {
            var transformedProperties: [String: [String: Any]] = [:]
            
            for (key, propJson) in properties {
                var prop: [String: Any] = [:]
                prop["type"] = propJson["type"] as? String ?? "string"
                
                if let description = propJson["description"] as? String {
                    prop["description"] = description
                }
                
                // Handle enum values if present
                if let enumValues = propJson["enum"] as? [String] {
                    prop["enum"] = enumValues
                }
                
                // Handle array items if present
                if prop["type"] as? String == "array",
                   let items = propJson["items"] as? [String: Any] {
                    prop["items"] = items
                }
                
                transformedProperties[key] = prop
            }
            
            schema["properties"] = transformedProperties
        }
        
        // Extract required fields
        if let required = json["required"] as? [String] {
            schema["required"] = required
        }
        
        // Add description if present
        if let description = json["description"] as? String {
            schema["description"] = description
        }
        
        return schema
    }
    
    /// Create response entry from content string
    private func createResponseEntry(content: String) -> Transcript.Entry {
        return .response(
            Transcript.Response(
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(content: content))]
            )
        )
    }
    
    /// Extract text from Transcript segments
    private func extractTextFromSegments(_ segments: [Transcript.Segment]) -> String {
        var texts: [String] = []
        
        for segment in segments {
            switch segment {
            case .text(let textSegment):
                texts.append(textSegment.content)
                
            case .structure(let structuredSegment):
                // Convert structured content to string
                if let jsonData = try? JSONEncoder().encode(structuredSegment.content),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    texts.append(jsonString)
                } else {
                    texts.append("[GeneratedContent]")
                }
            }
        }
        
        return texts.joined(separator: " ")
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

// MARK: - ToolCall Conversion Helpers
extension OpenAILanguageModel {
    
    /// Convert OpenAI ToolCalls to Transcript.ToolCalls
    private func convertToTranscriptToolCalls(_ openAIToolCalls: [OpenAIToolCall]) -> Transcript.ToolCalls {
        let transcriptToolCalls = openAIToolCalls.map { toolCall in
            // Parse the arguments JSON string to GeneratedContent
            let argumentsContent: GeneratedContent
            if let jsonData = toolCall.function.arguments.data(using: .utf8) {
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
                    argumentsContent = convertJSONToGeneratedContent(jsonObject)
                } catch {
                    // If parsing fails, create empty structure
                    argumentsContent = GeneratedContent(kind: .structure(properties: [:], orderedKeys: []))
                }
            } else {
                argumentsContent = GeneratedContent(kind: .structure(properties: [:], orderedKeys: []))
            }
            
            return Transcript.ToolCall(
                id: toolCall.id,
                toolName: toolCall.function.name,
                arguments: argumentsContent
            )
        }
        
        return Transcript.ToolCalls(transcriptToolCalls)
    }
    
    /// Convert JSON object to GeneratedContent
    private func convertJSONToGeneratedContent(_ json: Any) -> GeneratedContent {
        switch json {
        case let string as String:
            return GeneratedContent(kind: .string(string))
        case let number as NSNumber:
            if number.isBool {
                return GeneratedContent(kind: .bool(number.boolValue))
            } else {
                return GeneratedContent(kind: .number(number.doubleValue))
            }
        case let array as [Any]:
            let elements = array.map { convertJSONToGeneratedContent($0) }
            return GeneratedContent(kind: .array(elements))
        case let dict as [String: Any]:
            let properties = dict.mapValues { convertJSONToGeneratedContent($0) }
            let orderedKeys = Array(dict.keys).sorted()
            return GeneratedContent(kind: .structure(properties: properties, orderedKeys: orderedKeys))
        case is NSNull:
            return GeneratedContent(kind: .null)
        default:
            return GeneratedContent(kind: .null)
        }
    }
}

// MARK: - OpenAILanguageModelError
public enum OpenAILanguageModelError: Error, LocalizedError {
    case unexpectedResponse(String)
    
    public var errorDescription: String? {
        switch self {
        case .unexpectedResponse(let message):
            return "Unexpected response: \(message)"
        }
    }
}

// MARK: - NSNumber Bool Detection Extension
private extension NSNumber {
    var isBool: Bool {
        let boolID = CFBooleanGetTypeID()
        let numID = CFGetTypeID(self)
        return numID == boolID
    }
}