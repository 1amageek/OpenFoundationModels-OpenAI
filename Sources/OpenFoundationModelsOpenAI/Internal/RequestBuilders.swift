import Foundation
import OpenFoundationModels

// MARK: - Request Builder Protocol
internal protocol RequestBuilder: Sendable {
    func buildChatRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?
    ) throws -> OpenAIHTTPRequest
    
    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?
    ) throws -> OpenAIHTTPRequest
}

// MARK: - GPT Request Builder
internal struct GPTRequestBuilder: RequestBuilder {
    
    func buildChatRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            stream: false
        )
        
        return try buildHTTPRequest(from: request)
    }
    
    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            stream: true
        )
        
        return try buildHTTPRequest(from: request)
    }
    
    private func createChatCompletionRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        stream: Bool
    ) throws -> ChatCompletionRequest {
        _ = model.constraints  // For future constraint validation
        let validatedOptions = validateOptions(options, for: model)
        
        return ChatCompletionRequest(
            model: model.apiName,
            messages: messages,
            temperature: validatedOptions?.temperature,
            stream: stream ? true : nil
        )
    }
    
    private func validateOptions(_ options: GenerationOptions?, for model: OpenAIModel) -> GenerationOptions? {
        // OpenFoundationModels GenerationOptions are immutable, return as-is
        return options
    }
    
    private func buildHTTPRequest(from chatRequest: ChatCompletionRequest) throws -> OpenAIHTTPRequest {
        let encoder = JSONEncoder()
        let body = try encoder.encode(chatRequest)
        
        return OpenAIHTTPRequest(
            endpoint: "chat/completions",
            method: .POST,
            headers: [:],
            body: body
        )
    }
}

// MARK: - Reasoning Request Builder
internal struct ReasoningRequestBuilder: RequestBuilder {
    
    func buildChatRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            stream: false
        )
        
        return try buildHTTPRequest(from: request)
    }
    
    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            stream: true
        )
        
        return try buildHTTPRequest(from: request)
    }
    
    private func createChatCompletionRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        stream: Bool
    ) throws -> ChatCompletionRequest {
        // Reasoning models use max_completion_tokens instead of max_tokens
        return ChatCompletionRequest(
            model: model.apiName,
            messages: messages,
            stream: stream ? true : nil
        )
    }
    
    private func validateOptions(_ options: GenerationOptions?, for model: OpenAIModel) -> GenerationOptions? {
        // Reasoning models only use maxTokens, return as-is
        return options
    }
    
    private func buildHTTPRequest(from chatRequest: ChatCompletionRequest) throws -> OpenAIHTTPRequest {
        let encoder = JSONEncoder()
        let body = try encoder.encode(chatRequest)
        
        return OpenAIHTTPRequest(
            endpoint: "chat/completions",
            method: .POST,
            headers: [:],
            body: body
        )
    }
}


// MARK: - Prompt to ChatMessage Conversion
internal extension Array where Element == ChatMessage {
    static func from(prompt: String) -> [ChatMessage] {
        return [ChatMessage.user(prompt)]
    }
    
    static func from(prompt: Prompt) -> [ChatMessage] {
        // OpenFoundationModels Prompt has a content property accessible via description
        // Currently supports text-only content (multimodal support planned)
        let combinedText = prompt.description
        return [ChatMessage.user(combinedText)]
    }
}
