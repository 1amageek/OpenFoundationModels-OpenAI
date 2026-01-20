import Foundation
import OpenFoundationModels

/// Converts OpenFoundationModels Transcript to OpenAI API formats
internal struct TranscriptConverter {
    
    // MARK: - Message Building
    
    /// Build OpenAI messages from Transcript
    static func buildMessages(from transcript: Transcript) -> [ChatMessage] {
        // Try JSON-based extraction first for more complete information
        if let messagesFromJSON = buildMessagesFromJSON(transcript), !messagesFromJSON.isEmpty {
            return messagesFromJSON
        }
        
        // Fallback to entry-based extraction if JSON fails
        return buildMessagesFromEntries(transcript)
    }
    
    /// Build messages by encoding Transcript to JSON
    private static func buildMessagesFromJSON(_ transcript: Transcript) -> [ChatMessage]? {
        do {
            // Encode transcript to JSON
            let encoder = JSONEncoder()
            let data = try encoder.encode(transcript)
            
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entries = json["entries"] as? [[String: Any]] else {
                return nil
            }
            
            var messages: [ChatMessage] = []
            
            for entry in entries {
                guard let type = entry["type"] as? String else { continue }
                
                switch type {
                case "instructions":
                    if let segments = entry["segments"] as? [[String: Any]] {
                        let content = extractTextFromSegments(segments)
                        if !content.isEmpty {
                            messages.append(ChatMessage.system(content))
                        }
                    }
                    
                case "prompt":
                    if let segments = entry["segments"] as? [[String: Any]] {
                        let content = extractTextFromSegments(segments)
                        messages.append(ChatMessage.user(content))
                    }
                    
                case "response":
                    if let segments = entry["segments"] as? [[String: Any]] {
                        let content = extractTextFromSegments(segments)
                        messages.append(ChatMessage.assistant(content))
                    }
                    
                case "toolCalls":
                    // Handle different possible JSON structures for toolCalls
                    var toolCallsArray: [[String: Any]]? = nil
                    
                    // Try different key names
                    if let directArray = entry["toolCalls"] as? [[String: Any]] {
                        toolCallsArray = directArray
                    } else if let callsArray = entry["calls"] as? [[String: Any]] {
                        // Actual key name in Transcript.ToolCalls is "calls"
                        toolCallsArray = callsArray
                    }
                    // Try as nested structure (look for any array field)
                    else {
                        // Iterate through entry to find array of tool calls
                        for (key, value) in entry {
                            if key != "type" && key != "id", // Skip metadata fields
                               let array = value as? [[String: Any]] {
                                toolCallsArray = array
                                break
                            }
                        }
                    }
                    
                    if let toolCalls = toolCallsArray, !toolCalls.isEmpty {
                        let openAIToolCalls = extractToolCallsFromJSON(toolCalls)
                        if !openAIToolCalls.isEmpty {
                            messages.append(ChatMessage(
                                role: .assistant,
                                content: nil,
                                toolCalls: openAIToolCalls
                            ))
                        }
                    }
                    
                case "toolOutput":
                    if let segments = entry["segments"] as? [[String: Any]] {
                        let content = extractTextFromSegments(segments)
                        // Use ID from toolOutput entry
                        let toolCallId = entry["id"] as? String ?? UUID().uuidString
                        messages.append(ChatMessage.tool(
                            content: content,
                            toolCallId: toolCallId
                        ))
                    }
                    
                default:
                    break
                }
            }
            
            return messages.isEmpty ? nil : messages
        } catch {
            #if DEBUG
            print("Failed to build messages from JSON: \(error)")
            #endif
            return nil
        }
    }
    
    /// Extract text from JSON segments
    private static func extractTextFromSegments(_ segments: [[String: Any]]) -> String {
        var texts: [String] = []
        
        for segment in segments {
            if let type = segment["type"] as? String {
                if type == "text", let content = segment["content"] as? String {
                    texts.append(content)
                } else if type == "structure" {
                    // Handle structured content - it may be under different keys
                    if let generatedContent = segment["generatedContent"] {
                        // Try to serialize it as JSON
                        if let jsonData = try? JSONSerialization.data(withJSONObject: generatedContent, options: [.sortedKeys]),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            texts.append(jsonString)
                        }
                    } else if let content = segment["content"] {
                        // Fallback to content field
                        if let jsonData = try? JSONSerialization.data(withJSONObject: content, options: [.sortedKeys]),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            texts.append(jsonString)
                        }
                    }
                }
            }
        }
        
        return texts.joined(separator: " ")
    }
    
    /// Fallback: Build messages from entries directly
    private static func buildMessagesFromEntries(_ transcript: Transcript) -> [ChatMessage] {
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
        // Try JSON-based extraction first
        if let toolsFromJSON = extractToolsFromJSON(transcript) {
            return toolsFromJSON
        }
        
        // Fallback to entry-based extraction
        for entry in transcript {
            if case .instructions(let instructions) = entry,
               !instructions.toolDefinitions.isEmpty {
                return instructions.toolDefinitions.map { convertToolDefinition($0) }
            }
        }
        return nil
    }
    
    /// Extract tools by encoding Transcript to JSON
    private static func extractToolsFromJSON(_ transcript: Transcript) -> [Tool]? {
        do {
            // Encode transcript to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(transcript)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entries = json["entries"] as? [[String: Any]] else {
                return nil
            }
            
            // Look for instructions with toolDefinitions
            for entry in entries {
                if entry["type"] as? String == "instructions",
                   let toolDefs = entry["toolDefinitions"] as? [[String: Any]],
                   !toolDefs.isEmpty {
                    
                    #if DEBUG
                    print("Found \(toolDefs.count) tool definitions in JSON")
                    #endif
                    
                    var tools: [Tool] = []
                    for toolDef in toolDefs {
                        if let tool = extractToolFromJSON(toolDef) {
                            tools.append(tool)
                        }
                    }
                    return tools.isEmpty ? nil : tools
                }
            }
            
            return nil
        } catch {
            #if DEBUG
            print("Failed to extract tools from JSON: \(error)")
            #endif
            return nil
        }
    }
    
    /// Extract a single tool from JSON
    private static func extractToolFromJSON(_ json: [String: Any]) -> Tool? {
        guard let name = json["name"] as? String,
              let description = json["description"] as? String else {
            return nil
        }
        
        // Extract parameters if available
        let parameters: JSONSchema
        if let paramsJSON = json["parameters"] as? [String: Any] {
            parameters = parseSchemaJSON(paramsJSON)
        } else {
            parameters = JSONSchema(type: "object", properties: [:], required: [])
        }
        
        return Tool(
            function: Tool.Function(
                name: name,
                description: description,
                parameters: parameters
            )
        )
    }
    
    /// Extract tool calls from JSON
    private static func extractToolCallsFromJSON(_ toolCalls: [[String: Any]]) -> [OpenAIToolCall] {
        var openAIToolCalls: [OpenAIToolCall] = []
        
        for toolCall in toolCalls {
            guard let toolName = toolCall["toolName"] as? String else {
                continue
            }
            
            // Extract ID (may be under different keys)
            let id = toolCall["id"] as? String ?? UUID().uuidString
            
            // Extract arguments using improved parsing
            let extractedArguments: [String: Any]
            
            // Convert arguments to proper format
            if let argumentsData = toolCall["arguments"] {
                do {
                    // Try to parse arguments through GeneratedContent
                    let jsonData: Data
                    if let directData = argumentsData as? Data {
                        jsonData = directData
                    } else if let dict = argumentsData as? [String: Any] {
                        jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
                    } else {
                        jsonData = try JSONSerialization.data(withJSONObject: argumentsData, options: [.sortedKeys])
                    }
                    
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                    
                    // Create GeneratedContent from JSON
                    let argumentsContent = try GeneratedContent(json: jsonString)
                    
                    // Convert GeneratedContent to dictionary for OpenAI
                    extractedArguments = convertGeneratedContentToDict(argumentsContent)
                    
                    #if DEBUG
                    print("Successfully extracted arguments for tool: \(toolName)")
                    #endif
                    
                } catch {
                    #if DEBUG
                    print("Failed to parse arguments for tool \(toolName): \(error)")
                    #endif
                    // Try direct extraction as fallback
                    extractedArguments = extractArgumentsFromProperties(argumentsData)
                }
            } else {
                extractedArguments = [:]
            }
            
            // Convert arguments dictionary to JSON string for OpenAI API
            let jsonData = (try? JSONSerialization.data(withJSONObject: extractedArguments, options: [.sortedKeys])) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            // Create tool call even if arguments are empty (some tools don't require arguments)
            let toolCall = OpenAIToolCall(
                id: id,
                type: "function",
                function: OpenAIToolCall.FunctionCall(
                    name: toolName,
                    arguments: jsonString
                )
            )
            
            openAIToolCalls.append(toolCall)
        }
        
        return openAIToolCalls
    }
    
    /// Extract arguments from GeneratedContent properties structure
    private static func extractArgumentsFromProperties(_ properties: Any) -> [String: Any] {
        var arguments: [String: Any] = [:]
        
        // Handle different input types
        if let dict = properties as? [String: Any] {
            // Check if this is a wrapped GeneratedContent structure
            if let kind = dict["kind"] as? [String: Any] {
                if let structure = kind["structure"] as? [String: Any],
                   let props = structure["properties"] as? [String: Any] {
                    // Extract properties from structure
                    for (key, value) in props {
                        arguments[key] = extractValueFromGeneratedContent(value)
                    }
                } else if let props = kind["properties"] as? [String: Any] {
                    // Direct properties in kind
                    for (key, value) in props {
                        arguments[key] = extractValueFromGeneratedContent(value)
                    }
                } else {
                    // Try to extract simple values from kind
                    if let stringValue = kind["string"] as? String {
                        return ["value": stringValue]
                    } else if let numberValue = kind["number"] as? Double {
                        return ["value": numberValue]
                    } else if let boolValue = kind["boolean"] as? Bool {
                        return ["value": boolValue]
                    }
                }
            } else {
                // Direct dictionary without wrapping
                return dict
            }
        }
        
        return arguments
    }
    
    /// Extract value from GeneratedContent structure
    private static func extractValueFromGeneratedContent(_ value: Any) -> Any {
        if let contentWrapper = value as? [String: Any] {
            // Try to extract the actual value from GeneratedContent structure
            if let kind = contentWrapper["kind"] as? [String: Any] {
                if let stringValue = kind["string"] as? String {
                    return stringValue
                } else if let numberValue = kind["number"] as? Double {
                    return numberValue
                } else if let boolValue = kind["boolean"] as? Bool {
                    return boolValue
                } else if let arrayValue = kind["array"] as? [Any] {
                    return arrayValue.map { extractValueFromGeneratedContent($0) }
                } else if let structure = kind["structure"] as? [String: Any],
                          let props = structure["properties"] as? [String: Any] {
                    var dict: [String: Any] = [:]
                    for (key, val) in props {
                        dict[key] = extractValueFromGeneratedContent(val)
                    }
                    return dict
                }
            } else if let kind = contentWrapper["kind"] as? String {
                // Simple kind string
                return kind
            }
        }
        
        // Return as-is if we can't parse it
        return value
    }
    
    // MARK: - Response Format Extraction
    
    /// Extract response format from the most recent prompt
    static func extractResponseFormat(from transcript: Transcript) -> ResponseFormat? {
        // Try JSON-based extraction first for complete schema
        if let formatFromJSON = extractResponseFormatFromJSON(transcript) {
            return formatFromJSON
        }
        
        // Fallback to entry-based extraction
        for entry in transcript.reversed() {
            if case .prompt(let prompt) = entry,
               let responseFormat = prompt.responseFormat {
                return extractResponseFormatFromPrompt(responseFormat)
            }
        }
        return nil
    }
    
    /// Extract response format with full JSON Schema from the most recent prompt
    static func extractResponseFormatWithSchema(from transcript: Transcript, for model: OpenAIModel) -> ResponseFormat? {
        // Try JSON-based extraction to get complete schema
        return extractResponseFormatFromJSON(transcript, for: model)
    }
    
    /// Extract response format by encoding Transcript to JSON
    private static func extractResponseFormatFromJSON(_ transcript: Transcript) -> ResponseFormat? {
        // For backward compatibility, default to GPT model behavior
        // This method is used by extractResponseFormat which doesn't have model context
        return extractResponseFormatFromJSON(transcript, for: OpenAIModel("gpt-4o"))
    }

    /// Extract response format by encoding Transcript to JSON
    private static func extractResponseFormatFromJSON(_ transcript: Transcript, for model: OpenAIModel) -> ResponseFormat? {
        do {
            // Encode transcript to JSON
            let encoder = JSONEncoder()
            let data = try encoder.encode(transcript)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entries = json["entries"] as? [[String: Any]] else {
                return nil
            }

            // Look for the most recent prompt with responseFormat
            for entry in entries.reversed() {
                if entry["type"] as? String == "prompt",
                   let responseFormat = entry["responseFormat"] as? [String: Any] {

                    #if DEBUG
                    print("Found response format in JSON: \(responseFormat)")
                    #endif

                    // Check if there's a schema (now available with updated OpenFoundationModels)
                    if let schema = responseFormat["schema"] as? [String: Any] {
                        // For models that don't support json_schema (like DeepSeek), fallback to json mode
                        if model.modelType == .deepseek {
                            return .json
                        } else {
                            // Transform schema to OpenAI's expected format
                            let transformedSchema = transformToOpenAIJSONSchema(schema)
                            return .jsonSchema(transformedSchema)
                        }
                    }

                    // If there's a name or type field, we know JSON is expected
                    if responseFormat["name"] != nil || responseFormat["type"] != nil {
                        return .json
                    }
                }
            }

            return nil
        } catch {
            #if DEBUG
            print("Failed to extract response format from JSON: \(error)")
            #endif
            return nil
        }
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