import Foundation
import OpenFoundationModels

// MARK: - Schema Conversion Helper
internal func convertToJSONSchema(_ schema: GenerationSchema) -> JSONSchema {
    // Since GenerationSchema properties are not directly accessible,
    // we'll create a basic object schema. This is a placeholder implementation
    // that would need to be expanded based on actual schema introspection capabilities.
    
    // For now, return a generic object schema
    // In a real implementation, we'd need to parse the schema's debug description
    // or use reflection to extract the actual properties
    return JSONSchema(
        type: "object",
        properties: [:],
        required: nil
    )
}

// MARK: - Request Builder Protocol
internal protocol RequestBuilder: Sendable {
    func buildChatRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Transcript.ToolDefinition]?
    ) throws -> OpenAIHTTPRequest
    
    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Transcript.ToolDefinition]?
    ) throws -> OpenAIHTTPRequest
}

// MARK: - GPT Request Builder
internal struct GPTRequestBuilder: RequestBuilder {
    
    func buildChatRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Transcript.ToolDefinition]?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            tools: tools,
            stream: false
        )
        
        return try buildHTTPRequest(from: request)
    }
    
    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Transcript.ToolDefinition]?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            tools: tools,
            stream: true
        )
        
        return try buildHTTPRequest(from: request)
    }
    
    private func createChatCompletionRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Transcript.ToolDefinition]?,
        stream: Bool
    ) throws -> ChatCompletionRequest {
        _ = model.constraints  // For future constraint validation
        let validatedOptions = validateOptions(options, for: model)
        
        // Convert ToolDefinitions to OpenAI Tool format
        let openAITools = tools?.map { toolDef in
            Tool(function: Tool.Function(
                name: toolDef.name,
                description: toolDef.description,
                parameters: convertToJSONSchema(toolDef.parameters)
            ))
        }
        
        return ChatCompletionRequest(
            model: model.apiName,
            messages: messages,
            temperature: validatedOptions?.temperature,
            stream: stream ? true : nil,
            tools: openAITools
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
        options: GenerationOptions?,
        tools: [Transcript.ToolDefinition]?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            tools: tools,
            stream: false
        )
        
        return try buildHTTPRequest(from: request)
    }
    
    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Transcript.ToolDefinition]?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            tools: tools,
            stream: true
        )
        
        return try buildHTTPRequest(from: request)
    }
    
    private func createChatCompletionRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Transcript.ToolDefinition]?,
        stream: Bool
    ) throws -> ChatCompletionRequest {
        // Reasoning models use max_completion_tokens instead of max_tokens
        // Note: Reasoning models typically don't support tools/function calling
        let openAITools = tools?.map { toolDef in
            Tool(function: Tool.Function(
                name: toolDef.name,
                description: toolDef.description,
                parameters: convertToJSONSchema(toolDef.parameters)
            ))
        }
        
        return ChatCompletionRequest(
            model: model.apiName,
            messages: messages,
            stream: stream ? true : nil,
            tools: openAITools
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


// MARK: - Transcript to ChatMessage Conversion
internal extension Array where Element == ChatMessage {
    static func from(transcript: Transcript) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        
        for entry in transcript.entries {
            switch entry {
            case .instructions(let instructions):
                // Convert instructions to system message
                let content = extractText(from: instructions.segments)
                messages.append(ChatMessage.system(content))
                
            case .prompt(let prompt):
                // Convert prompt to user message
                let content = extractText(from: prompt.segments)
                messages.append(ChatMessage.user(content))
                
            case .response(let response):
                // Convert response to assistant message
                let content = extractText(from: response.segments)
                messages.append(ChatMessage.assistant(content))
                
            case .toolCalls:
                // Convert tool calls to assistant message with function calls
                // This would need proper implementation based on OpenAI's tool calling format
                // For now, we'll create a placeholder message
                let content = "Tool calls executed"
                messages.append(ChatMessage.assistant(content))
                
            case .toolOutput(let toolOutput):
                // Convert tool output to system/tool message
                // The tool output contains the result of a tool execution
                let content = "Tool output: \(toolOutput.toolName)"
                messages.append(ChatMessage.system(content))
            }
        }
        
        return messages
    }
    
    private static func extractText(from segments: [Transcript.Segment]) -> String {
        return segments.compactMap { segment in
            // Extract text from each segment
            switch segment {
            case .text(let textSegment):
                return textSegment.content
            case .structure:
                // Handle structured content if needed
                // For now, return nil to skip structured segments
                return nil
            }
        }.joined(separator: " ")
    }
    
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
