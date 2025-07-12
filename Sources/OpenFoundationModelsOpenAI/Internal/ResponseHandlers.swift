import Foundation

// MARK: - Response Handler Protocol
internal protocol ResponseHandler: Sendable {
    func extractContent(from response: ChatCompletionResponse) throws -> String
    func extractStreamContent(from chunk: ChatCompletionStreamResponse) throws -> String?
    func handleError(_ error: Error, for model: OpenAIModel) -> Error
}

// MARK: - GPT Response Handler
internal struct GPTResponseHandler: ResponseHandler {
    
    func extractContent(from response: ChatCompletionResponse) throws -> String {
        guard let choice = response.choices.first else {
            throw OpenAIResponseError.emptyResponse
        }
        
        guard let content = choice.message.content?.text else {
            throw OpenAIResponseError.noContent
        }
        
        return content
    }
    
    func extractStreamContent(from chunk: ChatCompletionStreamResponse) throws -> String? {
        guard let choice = chunk.choices.first else {
            return nil
        }
        
        return choice.delta.content
    }
    
    func handleError(_ error: Error, for model: OpenAIModel) -> Error {
        // GPT models have standard error handling
        return mapStandardError(error, for: model)
    }
}

// MARK: - Reasoning Response Handler
internal struct ReasoningResponseHandler: ResponseHandler {
    
    func extractContent(from response: ChatCompletionResponse) throws -> String {
        guard let choice = response.choices.first else {
            throw OpenAIResponseError.emptyResponse
        }
        
        guard let content = choice.message.content?.text else {
            throw OpenAIResponseError.noContent
        }
        
        return content
    }
    
    func extractStreamContent(from chunk: ChatCompletionStreamResponse) throws -> String? {
        guard let choice = chunk.choices.first else {
            return nil
        }
        
        return choice.delta.content
    }
    
    func handleError(_ error: Error, for model: OpenAIModel) -> Error {
        // Reasoning models may have specific error handling
        return mapReasoningError(error, for: model)
    }
    
    private func mapReasoningError(_ error: Error, for model: OpenAIModel) -> Error {
        // Handle reasoning-specific errors
        if let apiError = error as? OpenAIAPIError {
            switch apiError.code {
            case "reasoning_failed":
                return OpenAIResponseError.reasoningFailed(message: apiError.message)
            case "context_too_complex":
                return OpenAIResponseError.contextTooComplex(model: model.apiName)
            default:
                break
            }
        }
        
        return mapStandardError(error, for: model)
    }
}

// MARK: - Response Error Types
internal enum OpenAIResponseError: Error, LocalizedError, Sendable {
    case emptyResponse
    case noContent
    case invalidFormat
    case reasoningFailed(message: String)
    case contextTooComplex(model: String)
    case streamingError(String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Received empty response from OpenAI"
        case .noContent:
            return "Response contains no content"
        case .invalidFormat:
            return "Response format is invalid"
        case .reasoningFailed(let message):
            return "Reasoning failed: \(message)"
        case .contextTooComplex(let model):
            return "Context too complex for model \(model)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Handler Factory
internal struct ResponseHandlerFactory {
    static func createResponseHandler(for model: OpenAIModel) -> any ResponseHandler {
        switch model.modelType {
        case .gpt:
            return GPTResponseHandler()
        case .reasoning:
            return ReasoningResponseHandler()
        }
    }
}

// MARK: - Common Error Mapping
internal func mapStandardError(_ error: Error, for model: OpenAIModel) -> Error {
    if let httpError = error as? OpenAIHTTPError {
        return mapHTTPError(httpError, for: model)
    }
    
    if let apiError = error as? OpenAIAPIError {
        return mapAPIError(apiError, for: model)
    }
    
    return error
}

private func mapHTTPError(_ error: OpenAIHTTPError, for model: OpenAIModel) -> Error {
    switch error {
    case .statusError(_, let data):
        // Try to extract API error from response data
        if let data = data,
           let apiError = try? JSONDecoder().decode(OpenAIAPIError.ErrorResponse.self, from: data) {
            return mapAPIError(apiError.error, for: model)
        }
        return error
    default:
        return error
    }
}

private func mapAPIError(_ error: OpenAIAPIError, for model: OpenAIModel) -> Error {
    switch error.code {
    case "model_not_found":
        return OpenAIModelError.modelNotAvailable(model.apiName)
    case "context_length_exceeded":
        return OpenAIModelError.contextLengthExceeded(
            model: model.apiName,
            maxTokens: model.contextWindow
        )
    case "invalid_request_error":
        if error.message.contains("temperature") && !model.constraints.supportsTemperature {
            return OpenAIModelError.parameterNotSupported(
                parameter: "temperature",
                model: model.apiName
            )
        }
        if error.message.contains("top_p") && !model.constraints.supportsTopP {
            return OpenAIModelError.parameterNotSupported(
                parameter: "top_p",
                model: model.apiName
            )
        }
        return OpenAIModelError.invalidRequest(error.message)
    case "rate_limit_exceeded":
        return OpenAIModelError.rateLimitExceeded
    case "insufficient_quota":
        return OpenAIModelError.quotaExceeded
    default:
        return OpenAIModelError.apiError(error)
    }
}

// MARK: - Model-Specific Errors
public enum OpenAIModelError: Error, LocalizedError, Sendable {
    case modelNotAvailable(String)
    case parameterNotSupported(parameter: String, model: String)
    case contextLengthExceeded(model: String, maxTokens: Int)
    case invalidRequest(String)
    case rateLimitExceeded
    case quotaExceeded
    case apiError(OpenAIAPIError)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotAvailable(let model):
            return "Model '\(model)' is not available or you don't have access to it"
        case .parameterNotSupported(let parameter, let model):
            return "Parameter '\(parameter)' is not supported by model '\(model)'"
        case .contextLengthExceeded(let model, let maxTokens):
            return "Context length exceeded for model '\(model)'. Maximum: \(maxTokens) tokens"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .quotaExceeded:
            return "API quota exceeded. Please check your billing"
        case .apiError(let apiError):
            return "API error: \(apiError.message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .modelNotAvailable:
            return "Check available models in your OpenAI account or use a different model"
        case .parameterNotSupported:
            return "Remove the unsupported parameter or use a compatible model"
        case .contextLengthExceeded:
            return "Reduce the prompt length or use a model with a larger context window"
        case .rateLimitExceeded:
            return "Implement exponential backoff or upgrade your API plan"
        case .quotaExceeded:
            return "Add credits to your OpenAI account or upgrade your plan"
        default:
            return nil
        }
    }
}