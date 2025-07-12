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
        let constraints = model.constraints
        let validatedOptions = validateOptions(options, for: model)
        
        return ChatCompletionRequest(
            model: model.apiName,
            messages: messages,
            temperature: validatedOptions?.temperature,
            topP: validatedOptions?.topP,
            maxTokens: validatedOptions?.maxTokens,
            stop: validatedOptions?.stopSequences,
            stream: stream ? true : nil,
            frequencyPenalty: validatedOptions?.frequencyPenalty,
            presencePenalty: validatedOptions?.presencePenalty
        )
    }
    
    private func validateOptions(_ options: GenerationOptions?, for model: OpenAIModel) -> GenerationOptions? {
        guard let options = options else { return nil }
        
        var validated = options
        let constraints = model.constraints
        
        // Apply constraints
        if !constraints.supportsTemperature {
            validated.temperature = nil
        } else if let temp = validated.temperature, let range = constraints.temperatureRange {
            validated.temperature = max(range.lowerBound, min(range.upperBound, temp))
        }
        
        if !constraints.supportsTopP {
            validated.topP = nil
        } else if let topP = validated.topP, let range = constraints.topPRange {
            validated.topP = max(range.lowerBound, min(range.upperBound, topP))
        }
        
        if !constraints.supportsFrequencyPenalty {
            validated.frequencyPenalty = nil
        }
        
        if !constraints.supportsPresencePenalty {
            validated.presencePenalty = nil
        }
        
        if !constraints.supportsStop {
            validated.stopSequences = nil
        }
        
        // Validate max tokens
        if let maxTokens = validated.maxTokens {
            validated.maxTokens = min(maxTokens, model.maxOutputTokens)
        }
        
        return validated
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
        let validatedOptions = validateOptions(options, for: model)
        
        // Reasoning models use max_completion_tokens instead of max_tokens
        return ChatCompletionRequest(
            model: model.apiName,
            messages: messages,
            maxCompletionTokens: validatedOptions?.maxTokens,
            stream: stream ? true : nil
        )
    }
    
    private func validateOptions(_ options: GenerationOptions?, for model: OpenAIModel) -> GenerationOptions? {
        guard let options = options else { return nil }
        
        var validated = options
        let constraints = model.constraints
        
        // Reasoning models don't support most parameters
        validated.temperature = nil
        validated.topP = nil
        validated.frequencyPenalty = nil
        validated.presencePenalty = nil
        validated.stopSequences = nil
        
        // Only max tokens is supported (as max_completion_tokens)
        if let maxTokens = validated.maxTokens {
            validated.maxTokens = min(maxTokens, model.maxOutputTokens)
        }
        
        return validated
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

// MARK: - Request Builder Factory
internal struct RequestBuilderFactory {
    static func createRequestBuilder(for model: OpenAIModel) -> any RequestBuilder {
        switch model.modelType {
        case .gpt:
            return GPTRequestBuilder()
        case .reasoning:
            return ReasoningRequestBuilder()
        }
    }
}

// MARK: - Prompt to ChatMessage Conversion
internal extension Array where Element == ChatMessage {
    static func from(prompt: String) -> [ChatMessage] {
        return [ChatMessage.user(prompt)]
    }
    
    static func from(prompt: Prompt) -> [ChatMessage] {
        // Handle simple text prompts
        if prompt.segments.count == 1,
           case .text(let content) = prompt.segments.first! {
            return [ChatMessage.user(content)]
        }
        
        // Handle multimodal prompts
        var parts: [ContentPart] = []
        
        for segment in prompt.segments {
            switch segment {
            case .text(let content):
                parts.append(.text(ContentPart.TextPart(text: content)))
            case .image(let imageData):
                let base64String = imageData.base64EncodedString()
                let dataURL = "data:image/jpeg;base64,\(base64String)"
                parts.append(.image(ContentPart.ImagePart(
                    imageUrl: ContentPart.ImagePart.ImageURL(url: dataURL, detail: .auto)
                )))
            case .audio(let audioData):
                let base64String = audioData.base64EncodedString()
                parts.append(.audio(ContentPart.AudioPart(
                    inputAudio: ContentPart.AudioPart.InputAudio(data: base64String, format: .mp3)
                )))
            }
        }
        
        if parts.isEmpty {
            return [ChatMessage.user("")]
        } else if parts.count == 1, case .text(let textPart) = parts.first! {
            return [ChatMessage.user(textPart.text)]
        } else {
            return [ChatMessage(role: .user, content: .multimodal(parts))]
        }
    }
}