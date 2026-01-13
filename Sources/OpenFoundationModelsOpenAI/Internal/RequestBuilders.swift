import Foundation
import OpenFoundationModels

// MARK: - Schema Conversion Helper
internal func convertToJSONSchema(_ schema: GenerationSchema) -> JSONSchema {
    // Encode GenerationSchema to JSON and extract properties
    do {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(schema)
        
        if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            return parseSchemaJSON(json)
        }
    } catch {
        // If encoding fails, try parsing debug description as fallback
        print("Warning: Failed to encode GenerationSchema to JSON: \(error)")
        return parseSchemaFromDebugDescription(schema)
    }
    
    // Final fallback: return empty object schema
    return JSONSchema(
        type: "object",
        properties: [:],
        required: nil
    )
}

// MARK: - Schema Parsing from Debug Description (Fallback)
internal func parseSchemaFromDebugDescription(_ schema: GenerationSchema) -> JSONSchema {
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

// MARK: - Schema Parsing from JSON

private func parseSchemaJSON(_ json: [String: Any]) -> JSONSchema {
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
        tools: [Tool]?,
        responseFormat: ResponseFormat?
    ) throws -> OpenAIHTTPRequest

    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Tool]?,
        responseFormat: ResponseFormat?
    ) throws -> OpenAIHTTPRequest
}

// MARK: - GPT Request Builder
internal struct GPTRequestBuilder: RequestBuilder {

    func buildChatRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Tool]?,
        responseFormat: ResponseFormat?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            tools: tools,
            stream: false,
            responseFormat: responseFormat
        )

        return try buildHTTPRequest(from: request)
    }

    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Tool]?,
        responseFormat: ResponseFormat?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            tools: tools,
            stream: true,
            responseFormat: responseFormat
        )

        return try buildHTTPRequest(from: request)
    }

    private func createChatCompletionRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Tool]?,
        stream: Bool,
        responseFormat: ResponseFormat?
    ) throws -> ChatCompletionRequest {
        _ = model.constraints  // For future constraint validation
        let validatedOptions = validateOptions(options, for: model)

        return ChatCompletionRequest(
            model: model.apiName,
            messages: messages,
            temperature: validatedOptions?.temperature,
            maxTokens: validatedOptions?.maximumResponseTokens,
            stream: stream ? true : nil,
            tools: tools,
            responseFormat: responseFormat
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
        tools: [Tool]?,
        responseFormat: ResponseFormat?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            tools: tools,
            stream: false,
            responseFormat: responseFormat
        )

        return try buildHTTPRequest(from: request)
    }

    func buildStreamRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Tool]?,
        responseFormat: ResponseFormat?
    ) throws -> OpenAIHTTPRequest {
        let request = try createChatCompletionRequest(
            model: model,
            messages: messages,
            options: options,
            tools: tools,
            stream: true,
            responseFormat: responseFormat
        )

        return try buildHTTPRequest(from: request)
    }

    private func createChatCompletionRequest(
        model: OpenAIModel,
        messages: [ChatMessage],
        options: GenerationOptions?,
        tools: [Tool]?,
        stream: Bool,
        responseFormat: ResponseFormat?
    ) throws -> ChatCompletionRequest {
        // Reasoning models use max_completion_tokens instead of max_tokens
        // Note: Reasoning models typically don't support tools/function calling

        return ChatCompletionRequest(
            model: model.apiName,
            messages: messages,
            maxCompletionTokens: options?.maximumResponseTokens,
            stream: stream ? true : nil,
            tools: tools,
            responseFormat: responseFormat
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
        // Use TranscriptConverter for consistency
        return TranscriptConverter.buildMessages(from: transcript)
    }
    
    static func from(prompt: String) -> [ChatMessage] {
        return [ChatMessage.user(prompt)]
    }
}
