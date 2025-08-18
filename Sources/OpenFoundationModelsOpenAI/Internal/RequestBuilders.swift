import Foundation
import OpenFoundationModels

// MARK: - Schema Conversion Helper
internal func convertToJSONSchema(_ schema: GenerationSchema) -> JSONSchema {
    // Parse the schema's debug description to extract structure
    // This is necessary because GenerationSchema's internal structure is not publicly accessible
    let debugDesc = schema.debugDescription
    
    // Parse different schema types from debugDescription
    if debugDesc.contains("GenerationSchema(object:") {
        return parseObjectSchema(from: debugDesc)
    } else if debugDesc.contains("GenerationSchema(enum:") {
        return parseEnumSchema(from: debugDesc)
    } else if debugDesc.contains("GenerationSchema(array") {
        return parseArraySchema(from: debugDesc)
    } else if let primitiveType = extractPrimitiveType(from: debugDesc) {
        return JSONSchema(
            type: mapSwiftTypeToJSONType(primitiveType),
            properties: nil,
            required: nil
        )
    } else {
        // Fallback to generic object schema
        return JSONSchema(
            type: "object",
            properties: [:],
            required: nil
        )
    }
}

// MARK: - Schema Parsing Helpers

private func parseObjectSchema(from debugDesc: String) -> JSONSchema {
    var properties: [String: JSONSchemaProperty] = [:]
    var required: [String] = []
    
    // Extract properties from debug description
    // Format: "GenerationSchema(object: [property1: Type1, property2: Type2])"
    if let startIdx = debugDesc.range(of: "[")?.upperBound,
       let endIdx = debugDesc.range(of: "]", range: startIdx..<debugDesc.endIndex)?.lowerBound {
        
        let propertiesStr = String(debugDesc[startIdx..<endIdx])
        let propertyPairs = propertiesStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for pair in propertyPairs {
            let components = pair.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count == 2 {
                let propertyName = components[0]
                let propertyType = components[1]
                
                // Add to required list (in OpenAI, all properties are required by default)
                required.append(propertyName)
                
                // Create property schema
                properties[propertyName] = JSONSchemaProperty(
                    type: mapSwiftTypeToJSONType(propertyType),
                    description: nil
                )
            }
        }
    }
    
    return JSONSchema(
        type: "object",
        properties: properties.isEmpty ? nil : properties,
        required: required.isEmpty ? nil : required
    )
}

private func parseEnumSchema(from debugDesc: String) -> JSONSchema {
    // Extract enum values from debug description
    // Format: "GenerationSchema(enum: [\"value1\", \"value2\"])"
    var enumValues: [String] = []
    
    if let startIdx = debugDesc.range(of: "[")?.upperBound,
       let endIdx = debugDesc.range(of: "]", range: startIdx..<debugDesc.endIndex)?.lowerBound {
        
        let valuesStr = String(debugDesc[startIdx..<endIdx])
        enumValues = valuesStr
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }
    
    // Create property with enum values
    let property = JSONSchemaProperty(
        type: "string",
        enumValues: enumValues.isEmpty ? nil : enumValues
    )
    
    // Return as string schema with enum constraint
    return JSONSchema(
        type: "string",
        properties: ["value": property],
        required: nil
    )
}

private func parseArraySchema(from debugDesc: String) -> JSONSchema {
    // Extract array item type from debug description
    // Format: "GenerationSchema(array of: GenerationSchema(Type))"
    return JSONSchema(
        type: "array",
        properties: nil,
        required: nil
    )
}

private func extractPrimitiveType(from debugDesc: String) -> String? {
    // Match pattern like "GenerationSchema(String)" or "GenerationSchema(Int)"
    let pattern = "GenerationSchema\\(([A-Za-z]+)\\)"
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: debugDesc, range: NSRange(debugDesc.startIndex..., in: debugDesc)) {
        let range = Range(match.range(at: 1), in: debugDesc)
        if let range = range {
            return String(debugDesc[range])
        }
    }
    return nil
}

private func mapSwiftTypeToJSONType(_ swiftType: String) -> String {
    switch swiftType.lowercased() {
    case "string":
        return "string"
    case "int", "int32", "int64", "uint", "uint32", "uint64":
        return "integer"
    case "float", "double", "decimal":
        return "number"
    case "bool", "boolean":
        return "boolean"
    case "array":
        return "array"
    case "dictionary", "object":
        return "object"
    default:
        return "string" // Default to string for unknown types
    }
}

// MARK: - GeneratedContent to JSON Conversion Helper

private func convertGeneratedContentToJSON(_ content: GeneratedContent) -> String {
    // GeneratedContent is Codable, so we can encode it to JSON
    do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)
        return String(data: data, encoding: .utf8) ?? "{}"
    } catch {
        // If encoding fails, return empty JSON object
        return "{}"
    }
}

// MARK: - Testing Support

#if DEBUG
/// Testing support: Make conversion functions accessible for testing
public enum SchemaConversionTesting {
    public static func convertSchemaToJSON(_ schema: GenerationSchema) -> JSONSchema {
        // Call the internal function directly within same file
        return convertToJSONSchema(schema)
    }
    
    public static func mapTypeToJSON(_ swiftType: String) -> String {
        return mapSwiftTypeToJSONType(swiftType)
    }
    
    public static func extractType(from debugDesc: String) -> String? {
        return extractPrimitiveType(from: debugDesc)
    }
    
    public static func parseObject(from debugDesc: String) -> JSONSchema {
        return parseObjectSchema(from: debugDesc)
    }
    
    public static func parseEnum(from debugDesc: String) -> JSONSchema {
        return parseEnumSchema(from: debugDesc)
    }
    
    public static func parseArray(from debugDesc: String) -> JSONSchema {
        return parseArraySchema(from: debugDesc)
    }
}
#endif

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
        
        for entry in transcript {
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
                
            case .toolCalls(let toolCalls):
                // Convert tool calls to assistant message with function calls
                var openAIToolCalls: [OpenAIToolCall] = []
                for toolCall in toolCalls {
                    // Convert GeneratedContent to JSON string
                    let argumentsJson = convertGeneratedContentToJSON(toolCall.arguments)
                    
                    openAIToolCalls.append(OpenAIToolCall(
                        id: toolCall.id,
                        type: "function",
                        function: OpenAIToolCall.FunctionCall(
                            name: toolCall.toolName,
                            arguments: argumentsJson
                        )
                    ))
                }
                
                // Create assistant message with tool calls
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: nil,
                    toolCalls: openAIToolCalls
                )
                messages.append(assistantMessage)
                
            case .toolOutput(let toolOutput):
                // Convert tool output to tool message
                let content = extractText(from: toolOutput.segments)
                let toolMessage = ChatMessage.tool(
                    content: content,
                    toolCallId: toolOutput.id
                )
                messages.append(toolMessage)
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
