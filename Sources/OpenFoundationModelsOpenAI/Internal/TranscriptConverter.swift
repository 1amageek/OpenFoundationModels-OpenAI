import Foundation
import OpenFoundationModels

/// Converts OpenFoundationModels Transcript to OpenAI API formats
internal struct TranscriptConverter {
    
    // MARK: - Message Building
    
    /// Build OpenAI messages from Transcript
    static func buildMessages(from transcript: Transcript) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        
        for entry in transcript {
            switch entry {
            case .instructions(let instructions):
                // Convert instructions to system message
                let content = extractText(from: instructions.segments)
                if !content.isEmpty {
                    messages.append(ChatMessage.system(content))
                }
                
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
                let openAIToolCalls = convertToolCalls(toolCalls)
                messages.append(ChatMessage(
                    role: .assistant,
                    content: nil,
                    toolCalls: openAIToolCalls
                ))
                
            case .toolOutput(let toolOutput):
                // Convert tool output to tool message
                let content = extractText(from: toolOutput.segments)
                messages.append(ChatMessage.tool(
                    content: content,
                    toolCallId: toolOutput.id
                ))
            }
        }
        
        return messages
    }
    
    // MARK: - Tool Extraction
    
    /// Extract tool definitions from Transcript
    static func extractTools(from transcript: Transcript) -> [Tool]? {
        for entry in transcript {
            if case .instructions(let instructions) = entry,
               !instructions.toolDefinitions.isEmpty {
                return instructions.toolDefinitions.map { convertToolDefinition($0) }
            }
        }
        return nil
    }
    
    // MARK: - Response Format Extraction
    
    /// Extract response format from the most recent prompt
    static func extractResponseFormat(from transcript: Transcript) -> ResponseFormat? {
        // Look for the most recent prompt with a response format
        for entry in transcript.reversed() {
            if case .prompt(let prompt) = entry,
               let responseFormat = prompt.responseFormat {
                return extractResponseFormatFromPrompt(responseFormat)
            }
        }
        return nil
    }
    
    /// Extract response format with full JSON Schema from the most recent prompt
    static func extractResponseFormatWithSchema(from transcript: Transcript) -> ResponseFormat? {
        // Look for the most recent prompt with response format
        for entry in transcript.reversed() {
            if case .prompt(let prompt) = entry,
               let _ = prompt.responseFormat {
                // Unfortunately, ResponseFormat.schema is private in OpenFoundationModels
                // We can only detect that a response format exists and enable JSON mode
                // This is a limitation of the current OpenFoundationModels API
                return .json
            }
        }
        return nil
    }
    
    // MARK: - Generation Options Extraction
    
    /// Extract generation options from the most recent prompt
    static func extractOptions(from transcript: Transcript) -> GenerationOptions? {
        for entry in transcript.reversed() {
            if case .prompt(let prompt) = entry {
                return prompt.options
            }
        }
        return nil
    }
    
    // MARK: - Private Helper Methods
    
    /// Extract text from segments
    private static func extractText(from segments: [Transcript.Segment]) -> String {
        var texts: [String] = []
        
        for segment in segments {
            switch segment {
            case .text(let textSegment):
                texts.append(textSegment.content)
                
            case .structure(let structuredSegment):
                // Convert structured content to string
                let content = structuredSegment.content
                texts.append(formatGeneratedContent(content))
            }
        }
        
        return texts.joined(separator: " ")
    }
    
    /// Format GeneratedContent as string
    private static func formatGeneratedContent(_ content: GeneratedContent) -> String {
        // Try to get JSON representation first
        if let jsonData = try? JSONEncoder().encode(content),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        // Fallback to string representation
        return "[GeneratedContent]"
    }
    
    /// Convert Transcript.ToolDefinition to OpenAI Tool
    private static func convertToolDefinition(_ definition: Transcript.ToolDefinition) -> Tool {
        return Tool(
            function: Tool.Function(
                name: definition.name,
                description: definition.description,
                parameters: convertSchemaToJSONSchema(definition.parameters)
            )
        )
    }
    
    /// Convert GenerationSchema to JSONSchema
    private static func convertSchemaToJSONSchema(_ schema: GenerationSchema) -> JSONSchema {
        // Encode GenerationSchema to JSON and extract properties
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(schema)
            
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return parseSchemaJSON(json)
            }
        } catch {
            // If encoding fails, return empty schema
            print("Warning: Failed to encode GenerationSchema to JSON: \(error)")
        }
        
        // Fallback: return empty object schema
        return JSONSchema(
            type: "object",
            properties: [:],
            required: []
        )
    }
    
    /// Convert GenerationSchema to JSON dictionary for ResponseFormat
    private static func convertGenerationSchemaToJSONSchema(_ schema: GenerationSchema) -> [String: Any]? {
        // Encode GenerationSchema to JSON dictionary
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(schema)
            
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Transform to OpenAI's expected JSON Schema format
                return transformToOpenAIJSONSchema(json)
            }
        } catch {
            print("Warning: Failed to encode GenerationSchema to JSON: \(error)")
        }
        
        return nil
    }
    
    /// Transform GenerationSchema JSON to OpenAI's JSON Schema format
    private static func transformToOpenAIJSONSchema(_ json: [String: Any]) -> [String: Any] {
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
    
    /// Parse schema JSON to create JSONSchema
    private static func parseSchemaJSON(_ json: [String: Any]) -> JSONSchema {
        // Extract type (default to "object")
        let type = json["type"] as? String ?? "object"
        
        // Extract properties if available
        var schemaProperties: [String: JSONSchemaProperty] = [:]
        if let properties = json["properties"] as? [String: [String: Any]] {
            for (key, propJson) in properties {
                let propType = propJson["type"] as? String ?? "string"
                let propDescription = propJson["description"] as? String
                let enumValues = propJson["enum"] as? [String]
                
                // Handle array items
                var items: JSONSchemaProperty? = nil
                if propType == "array",
                   let itemsJson = propJson["items"] as? [String: Any] {
                    let itemType = itemsJson["type"] as? String ?? "string"
                    items = JSONSchemaProperty(
                        type: itemType,
                        description: itemsJson["description"] as? String
                    )
                }
                
                schemaProperties[key] = JSONSchemaProperty(
                    type: propType,
                    description: propDescription,
                    enumValues: enumValues,
                    items: items
                )
            }
        }
        
        // Extract required fields
        let required = json["required"] as? [String]
        
        return JSONSchema(
            type: type,
            properties: schemaProperties.isEmpty ? nil : schemaProperties,
            required: required,
            description: json["description"] as? String
        )
    }
    
    /// Convert ResponseFormat from OpenFoundationModels format
    private static func extractResponseFormatFromPrompt(_ responseFormat: Transcript.ResponseFormat) -> ResponseFormat? {
        // Unfortunately, OpenFoundationModels' ResponseFormat doesn't expose its internal schema
        // due to the Codable implementation setting schema to nil during encoding.
        // The best we can do is detect that a ResponseFormat exists and enable JSON mode.
        
        // Check if there's a schema attached (even though we can't access it directly)
        // For now, we'll return .json to enable structured output mode in OpenAI
        return .json
    }
    
    /// Convert Transcript.ToolCalls to OpenAI ToolCalls
    private static func convertToolCalls(_ toolCalls: Transcript.ToolCalls) -> [OpenAIToolCall] {
        var openAIToolCalls: [OpenAIToolCall] = []
        
        for toolCall in toolCalls {
            let argumentsDict = convertGeneratedContentToDict(toolCall.arguments)
            let jsonData = (try? JSONSerialization.data(withJSONObject: argumentsDict)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            openAIToolCalls.append(
                OpenAIToolCall(
                    id: toolCall.id,
                    type: "function",
                    function: OpenAIToolCall.FunctionCall(
                        name: toolCall.toolName,
                        arguments: jsonString
                    )
                )
            )
        }
        
        return openAIToolCalls
    }
    
    /// Convert GeneratedContent to dictionary for tool arguments
    private static func convertGeneratedContentToDict(_ content: GeneratedContent) -> [String: Any] {
        switch content.kind {
        case .structure(let properties, _):
            var dict: [String: Any] = [:]
            for (key, value) in properties {
                dict[key] = convertGeneratedContentToAny(value)
            }
            return dict
            
        default:
            // If not a structure, return empty dictionary
            return [:]
        }
    }
    
    /// Convert GeneratedContent to Any type
    private static func convertGeneratedContentToAny(_ content: GeneratedContent) -> Any {
        switch content.kind {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .number(let value):
            return value
        case .string(let value):
            return value
        case .array(let elements):
            return elements.map { convertGeneratedContentToAny($0) }
        case .structure(let properties, _):
            var dict: [String: Any] = [:]
            for (key, value) in properties {
                dict[key] = convertGeneratedContentToAny(value)
            }
            return dict
        }
    }
}