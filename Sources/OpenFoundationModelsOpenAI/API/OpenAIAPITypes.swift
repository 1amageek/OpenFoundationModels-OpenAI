import Foundation

// MARK: - Helper Types
public final class Box<T>: Codable, Sendable where T: Codable & Sendable {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(T.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Chat Completion Request
public struct ChatCompletionRequest: Codable, Sendable {
    public let model: String
    public let messages: [ChatMessage]
    public let temperature: Double?
    public let topP: Double?
    public let maxTokens: Int?
    public let maxCompletionTokens: Int?
    public let stop: [String]?
    public let stream: Bool?
    public let frequencyPenalty: Double?
    public let presencePenalty: Double?
    public let tools: [Tool]?
    public let toolChoice: ToolChoice?
    public let user: String?
    
    public init(
        model: String,
        messages: [ChatMessage],
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        maxCompletionTokens: Int? = nil,
        stop: [String]? = nil,
        stream: Bool? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        user: String? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.maxCompletionTokens = maxCompletionTokens
        self.stop = stop
        self.stream = stream
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.tools = tools
        self.toolChoice = toolChoice
        self.user = user
    }
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stop, stream, tools, user
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case maxCompletionTokens = "max_completion_tokens"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case toolChoice = "tool_choice"
    }
}

// MARK: - Chat Message
public struct ChatMessage: Codable, Sendable {
    public let role: Role
    public let content: Content?
    public let name: String?
    public let toolCalls: [ToolCall]?
    public let toolCallId: String?
    
    public init(
        role: Role,
        content: Content? = nil,
        name: String? = nil,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
    
    public enum Role: String, Codable, Sendable {
        case system, user, assistant, tool
    }
    
    public enum Content: Codable, Sendable {
        case text(String)
        case multimodal([ContentPart])
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let parts = try? container.decode([ContentPart].self) {
                self = .multimodal(parts)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid content format")
                )
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch self {
            case .text(let text):
                try container.encode(text)
            case .multimodal(let parts):
                try container.encode(parts)
            }
        }
        
        public var text: String? {
            switch self {
            case .text(let text):
                return text
            case .multimodal(let parts):
                return parts.compactMap { part in
                    if case .text(let textPart) = part {
                        return textPart.text
                    }
                    return nil
                }.joined(separator: " ")
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content, name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

// MARK: - Content Parts (for multimodal)
public enum ContentPart: Codable, Sendable {
    case text(TextPart)
    case image(ImagePart)
    case audio(AudioPart)
    
    public struct TextPart: Codable, Sendable {
        public let type: String
        public let text: String
        
        public init(text: String) {
            self.type = "text"
            self.text = text
        }
        
        private enum CodingKeys: String, CodingKey {
            case type, text
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "text"
            self.text = try container.decode(String.self, forKey: .text)
        }
    }
    
    public struct ImagePart: Codable, Sendable {
        public let type = "image_url"
        public let imageUrl: ImageURL
        
        public init(imageUrl: ImageURL) {
            self.imageUrl = imageUrl
        }
        
        public struct ImageURL: Codable, Sendable {
            public let url: String
            public let detail: Detail?
            
            public init(url: String, detail: Detail? = nil) {
                self.url = url
                self.detail = detail
            }
            
            public enum Detail: String, Codable, Sendable {
                case auto, low, high
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case type
            case imageUrl = "image_url"
        }
    }
    
    public struct AudioPart: Codable, Sendable {
        public let type = "input_audio"
        public let inputAudio: InputAudio
        
        public init(inputAudio: InputAudio) {
            self.inputAudio = inputAudio
        }
        
        public struct InputAudio: Codable, Sendable {
            public let data: String // base64 encoded
            public let format: Format
            
            public init(data: String, format: Format) {
                self.data = data
                self.format = format
            }
            
            public enum Format: String, Codable, Sendable {
                case wav, mp3, flac, m4a, ogg, oga, webm
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case type
            case inputAudio = "input_audio"
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        let type = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: "type")!)
        
        switch type {
        case "text":
            let textPart = try TextPart(from: decoder)
            self = .text(textPart)
        case "image_url":
            let imagePart = try ImagePart(from: decoder)
            self = .image(imagePart)
        case "input_audio":
            let audioPart = try AudioPart(from: decoder)
            self = .audio(audioPart)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown content part type: \(type)")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let textPart):
            try textPart.encode(to: encoder)
        case .image(let imagePart):
            try imagePart.encode(to: encoder)
        case .audio(let audioPart):
            try audioPart.encode(to: encoder)
        }
    }
}

// MARK: - Tool Definitions
public struct Tool: Codable, Sendable {
    public let type: String
    public let function: Function
    
    public init(function: Function) {
        self.type = "function"
        self.function = function
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, function
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "function"
        self.function = try container.decode(Function.self, forKey: .function)
    }
    
    public struct Function: Codable, Sendable {
        public let name: String
        public let description: String?
        public let parameters: JSONSchema
        
        public init(name: String, description: String? = nil, parameters: JSONSchema) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }
}

public enum ToolChoice: Codable, Sendable {
    case none
    case auto
    case required
    case function(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            switch string {
            case "none": self = .none
            case "auto": self = .auto
            case "required": self = .required
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid tool choice: \(string)")
                )
            }
        } else if let object = try? container.decode([String: [String: String]].self),
                  let function = object["function"],
                  let name = function["name"] {
            self = .function(name)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid tool choice format")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .function(let name):
            struct FunctionChoice: Codable {
                let type: String
                let function: FunctionName
                
                init(function: FunctionName) {
                    self.type = "function"
                    self.function = function
                }
                
                struct FunctionName: Codable {
                    let name: String
                }
            }
            try container.encode(FunctionChoice(function: FunctionChoice.FunctionName(name: name)))
        }
    }
}

// MARK: - Tool Call
public struct ToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: FunctionCall
    
    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
    
    public struct FunctionCall: Codable, Sendable {
        public let name: String
        public let arguments: String
        
        public init(name: String, arguments: String) {
            self.name = name
            self.arguments = arguments
        }
    }
}

// MARK: - JSON Schema (simplified for function calling)
public struct JSONSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: JSONSchemaProperty]?
    public let required: [String]?
    public let description: String?
    
    public init(
        type: String,
        properties: [String: JSONSchemaProperty]? = nil,
        required: [String]? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.description = description
    }
}

public struct JSONSchemaProperty: Codable, Sendable {
    public let type: String
    public let description: String?
    public let enumValues: [String]?
    public let minimum: Double?
    public let maximum: Double?
    public let items: Box<JSONSchemaProperty>?
    
    public init(
        type: String,
        description: String? = nil,
        enumValues: [String]? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        items: JSONSchemaProperty? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.minimum = minimum
        self.maximum = maximum
        self.items = items.map(Box.init)
    }
    
    enum CodingKeys: String, CodingKey {
        case type, description, minimum, maximum, items
        case enumValues = "enum"
    }
}

// MARK: - Chat Completion Response
public struct ChatCompletionResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    public let usage: Usage?
    public let systemFingerprint: String?
    
    public struct Choice: Codable, Sendable {
        public let index: Int
        public let message: ChatMessage
        public let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    public struct Usage: Codable, Sendable {
        public let promptTokens: Int
        public let completionTokens: Int?
        public let totalTokens: Int
        public let reasoningTokens: Int? // For reasoning models
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
            case reasoningTokens = "reasoning_tokens"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage
        case systemFingerprint = "system_fingerprint"
    }
}

// MARK: - Chat Completion Stream Response
public struct ChatCompletionStreamResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [StreamChoice]
    
    public struct StreamChoice: Codable, Sendable {
        public let index: Int
        public let delta: Delta
        public let finishReason: String?
        
        public struct Delta: Codable, Sendable {
            public let role: String?
            public let content: String?
            public let toolCalls: [ToolCall]?
            
            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCalls = "tool_calls"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }
}

// MARK: - Helper Types
private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Convenience Extensions
extension ChatMessage {
    public static func system(_ content: String) -> ChatMessage {
        return ChatMessage(role: .system, content: .text(content))
    }
    
    public static func user(_ content: String) -> ChatMessage {
        return ChatMessage(role: .user, content: .text(content))
    }
    
    public static func assistant(_ content: String) -> ChatMessage {
        return ChatMessage(role: .assistant, content: .text(content))
    }
    
    public static func tool(content: String, toolCallId: String) -> ChatMessage {
        return ChatMessage(role: .tool, content: .text(content), toolCallId: toolCallId)
    }
    
    public static func userWithImage(text: String, imageURL: String, detail: ContentPart.ImagePart.ImageURL.Detail = .auto) -> ChatMessage {
        let parts: [ContentPart] = [
            .text(ContentPart.TextPart(text: text)),
            .image(ContentPart.ImagePart(imageUrl: ContentPart.ImagePart.ImageURL(url: imageURL, detail: detail)))
        ]
        return ChatMessage(role: .user, content: .multimodal(parts))
    }
}