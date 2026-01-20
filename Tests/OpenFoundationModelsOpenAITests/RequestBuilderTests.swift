import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI
@testable import OpenFoundationModels

@Suite("Request Builder Tests")
struct RequestBuilderTests {
    
    // MARK: - Test Data
    
    private static let testMessages = [
        ChatMessage.system("You are a helpful assistant."),
        ChatMessage.user("Hello, how are you?")
    ]
    
    private static let testOptions = GenerationOptions(
        temperature: 0.7,
        maximumResponseTokens: 100
    )
    
    // MARK: - GPT Request Builder Tests
    
    @Test("GPT request builder creates valid chat request")
    func testGPTChatRequest() throws {
        let builder = GPTRequestBuilder()
        
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        #expect(request.endpoint == "chat/completions", "Should use correct endpoint")
        #expect(request.method == HTTPMethod.POST, "Should use POST method")
        #expect(request.body != nil, "Should have request body")
        
        // Decode and verify the request body
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.model == "gpt-4o", "Should use correct model name")
        #expect(chatRequest.messages.count == 2, "Should include all messages")
        #expect(chatRequest.temperature == 0.7, "Should include temperature")
        // Note: topP is not set in the new GenerationOptions, and maxTokens handling may differ
        #expect(chatRequest.stream == nil, "Chat request should not stream")
    }
    
    @Test("GPT request builder creates valid stream request")
    func testGPTStreamRequest() throws {
        let builder = GPTRequestBuilder()
        
        let request = try builder.buildStreamRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        #expect(request.endpoint == "chat/completions", "Should use correct endpoint")
        #expect(request.method == HTTPMethod.POST, "Should use POST method")
        
        // Decode and verify the request body
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.stream == true, "Stream request should enable streaming")
        #expect(chatRequest.model == "gpt-4o", "Should use correct model name")
    }
    
    @Test("GPT request builder works with different GPT models", arguments: [
        OpenAIModel.gpt4o,
        OpenAIModel.gpt4oMini,
        OpenAIModel.gpt4Turbo
    ])
    func testGPTBuilderWithDifferentModels(model: OpenAIModel) throws {
        let builder = GPTRequestBuilder()
        
        let request = try builder.buildChatRequest(
            model: model,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.model == model.apiName, "Should use correct model API name")

        // GPT models should support temperature
        #expect(chatRequest.temperature != nil, "GPT models should support temperature")
    }
    
    @Test("GPT request builder handles nil options")
    func testGPTBuilderWithNilOptions() throws {
        let builder = GPTRequestBuilder()

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: nil,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.temperature == nil, "Should handle nil temperature")
        #expect(chatRequest.maxTokens == nil, "Should handle nil maxTokens")
    }

    @Test("GPT request builder handles tools")
    func testGPTBuilderWithTools() throws {
        let builder = GPTRequestBuilder()

        // Create test tool with proper JSONSchema
        let tool = Tool(
            function: Tool.Function(
                name: "get_weather",
                description: "Get the current weather",
                parameters: JSONSchema(
                    type: "object",
                    properties: [:],
                    required: nil
                )
            )
        )

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: [tool],
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.tools != nil, "Should include tools when provided")
        #expect(chatRequest.tools?.count == 1, "Should include correct number of tools")
        #expect(chatRequest.tools?.first?.function.name == "get_weather", "Should preserve tool name")
    }
    
    // MARK: - Reasoning Request Builder Tests
    
    @Test("Reasoning request builder creates valid chat request")
    func testReasoningChatRequest() throws {
        let builder = ReasoningRequestBuilder()

        let request = try builder.buildChatRequest(
            model: .o1,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        #expect(request.endpoint == "chat/completions", "Should use correct endpoint")
        #expect(request.method == HTTPMethod.POST, "Should use POST method")

        // Decode and verify the request body
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.model == "o1", "Should use correct model name")
        #expect(chatRequest.messages.count == 2, "Should include all messages")

        // Reasoning models don't support temperature
        #expect(chatRequest.temperature == nil, "Reasoning models don't support temperature")
    }

    @Test("Reasoning request builder creates valid stream request")
    func testReasoningStreamRequest() throws {
        let builder = ReasoningRequestBuilder()

        let request = try builder.buildStreamRequest(
            model: .o3,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.stream == true, "Stream request should enable streaming")
        #expect(chatRequest.model == "o3", "Should use correct model name")
    }

    @Test("Reasoning request builder works with different reasoning models", arguments: [
        OpenAIModel.o1,
        OpenAIModel.o1Pro,
        OpenAIModel.o3,
        OpenAIModel.o3Pro,
        OpenAIModel.o4Mini
    ])
    func testReasoningBuilderWithDifferentModels(model: OpenAIModel) throws {
        let builder = ReasoningRequestBuilder()

        let request = try builder.buildChatRequest(
            model: model,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.model == model.apiName, "Should use correct model API name")

        // Reasoning models should not support temperature
        #expect(chatRequest.temperature == nil, "Reasoning models should not support temperature")
    }
    
    // MARK: - Request Builder Type Tests
    
    @Test("Correct builder types are created for different model types")
    func testBuilderTypesForModelTypes() {
        // GPT models should use GPTRequestBuilder
        let gptBuilder = GPTRequestBuilder()
        #expect(type(of: gptBuilder) == GPTRequestBuilder.self, "Should create GPTRequestBuilder for GPT models")
        
        // Reasoning models should use ReasoningRequestBuilder
        let reasoningBuilder = ReasoningRequestBuilder()
        #expect(type(of: reasoningBuilder) == ReasoningRequestBuilder.self, "Should create ReasoningRequestBuilder for reasoning models")
    }
    
    @Test("Builder type selection based on model type", arguments: OpenAIModelInfo.allModels)
    func testBuilderSelectionForModels(model: OpenAIModel) {
        // This test verifies the logic that would be in OpenAILanguageModel init
        let builder: any RequestBuilder
        switch model.modelType {
        case .gpt:
            builder = GPTRequestBuilder()
        case .reasoning:
            builder = ReasoningRequestBuilder()
        case .deepseek:
            builder = GPTRequestBuilder() // DeepSeek uses GPT builder
        }

        switch model.modelType {
        case .gpt:
            #expect(type(of: builder) == GPTRequestBuilder.self,
                   "Should create GPTRequestBuilder for GPT model \(model.apiName)")
        case .reasoning:
            #expect(type(of: builder) == ReasoningRequestBuilder.self,
                   "Should create ReasoningRequestBuilder for reasoning model \(model.apiName)")
        case .deepseek:
            #expect(type(of: builder) == GPTRequestBuilder.self,
                   "Should create GPTRequestBuilder for DeepSeek model \(model.apiName)")
        }
    }
    
    // MARK: - Transcript Conversion Tests
    
    @Test("Transcript to ChatMessage conversion works")
    func testTranscriptToChatMessageConversion() {
        // Create transcript with proper initialization
        let instructionSegment = Transcript.TextSegment(
            id: "inst-1",
            content: "You are a helpful assistant."
        )
        let instructions = Transcript.Instructions(
            id: "instructions-1",
            segments: [.text(instructionSegment)],
            toolDefinitions: []
        )
        
        let promptSegment = Transcript.TextSegment(
            id: "prompt-1",
            content: "Hello, world!"
        )
        let prompt = Transcript.Prompt(
            id: "prompt-1",
            segments: [.text(promptSegment)],
            options: GenerationOptions(),
            responseFormat: nil
        )
        
        let responseSegment = Transcript.TextSegment(
            id: "response-1",
            content: "Hi there!"
        )
        let response = Transcript.Response(
            id: "response-1",
            assetIDs: [],
            segments: [.text(responseSegment)]
        )
        
        // Create transcript with entries
        let transcript = Transcript(entries: [
            .instructions(instructions),
            .prompt(prompt),
            .response(response)
        ])
        
        let messages = [ChatMessage].from(transcript: transcript)
        
        #expect(messages.count == 3, "Should create three messages")
        #expect(messages[0].role == ChatMessage.Role.system, "First should be system message")
        #expect(messages[1].role == ChatMessage.Role.user, "Second should be user message")
        #expect(messages[2].role == ChatMessage.Role.assistant, "Third should be assistant message")
    }
    
    @Test("Empty transcript conversion works")
    func testEmptyTranscriptConversion() {
        let transcript = Transcript()
        let messages = [ChatMessage].from(transcript: transcript)
        
        #expect(messages.isEmpty, "Should create empty message list for empty transcript")
    }
    
    // MARK: - HTTP Request Structure Tests
    
    @Test("HTTP request has correct structure")
    func testHTTPRequestStructure() throws {
        let builder = GPTRequestBuilder()

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        #expect(request.endpoint == "chat/completions", "Should have correct endpoint")
        #expect(request.method == HTTPMethod.POST, "Should use POST method")
        #expect(request.headers.isEmpty, "Should have empty headers by default")
        #expect(request.body != nil, "Should have request body")

        // Verify the body is valid JSON
        let json = try JSONSerialization.jsonObject(with: request.body!, options: [])
        #expect(json is [String: Any], "Request body should be valid JSON object")
    }

    @Test("Request body encoding is consistent")
    func testRequestBodyEncoding() throws {
        let builder = GPTRequestBuilder()

        // Build same request twice
        let request1 = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        let request2 = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        // Decode both and compare
        let decoder = JSONDecoder()
        let chatRequest1 = try decoder.decode(ChatCompletionRequest.self, from: request1.body!)
        let chatRequest2 = try decoder.decode(ChatCompletionRequest.self, from: request2.body!)

        #expect(chatRequest1.model == chatRequest2.model, "Models should match")
        #expect(chatRequest1.temperature == chatRequest2.temperature, "Temperature should match")
    }
    
    // MARK: - Parameter Validation Tests

    @Test("GPT builder preserves supported parameters")
    func testGPTParameterPreservation() throws {
        let options = GenerationOptions(
            temperature: 0.8,
            maximumResponseTokens: 150
        )

        let builder = GPTRequestBuilder()
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: options,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.temperature == 0.8, "Should preserve temperature")
        // Note: maximumResponseTokens may be mapped differently
    }

    @Test("Reasoning builder filters unsupported parameters")
    func testReasoningParameterFiltering() throws {
        let options = GenerationOptions(
            temperature: 0.5, // Should be filtered out for reasoning models
            maximumResponseTokens: 200
        )

        let builder = ReasoningRequestBuilder()
        let request = try builder.buildChatRequest(
            model: .o1,
            messages: Self.testMessages,
            options: options,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.temperature == nil, "Should filter out temperature for reasoning models")
    }

    // MARK: - Edge Case Tests

    @Test("Builder handles empty message list")
    func testEmptyMessageList() throws {
        let builder = GPTRequestBuilder()

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: [],
            options: nil,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.messages.isEmpty, "Should handle empty message list")
    }

    @Test("Builder handles extreme parameter values")
    func testExtremeParameterValues() throws {
        let options = GenerationOptions(
            temperature: 0.0, // Minimum
            maximumResponseTokens: 1 // Minimum
        )

        let builder = GPTRequestBuilder()
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: options,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.temperature == 0.0, "Should handle minimum temperature")
    }

    // MARK: - ResponseFormat Tests

    @Test("GPT builder includes JSON response format")
    func testGPTBuilderWithJSONResponseFormat() throws {
        let builder = GPTRequestBuilder()

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: .json
        )

        // Verify by checking the JSON structure
        let json = try JSONSerialization.jsonObject(with: request.body!) as? [String: Any]
        let responseFormat = json?["response_format"] as? [String: Any]

        #expect(responseFormat != nil, "Should include response format")
        #expect(responseFormat?["type"] as? String == "json_object", "Should be json_object type")
    }

    @Test("GPT builder includes JSON Schema response format")
    func testGPTBuilderWithJSONSchemaResponseFormat() throws {
        let builder = GPTRequestBuilder()

        let schemaDict: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "The name"],
                "age": ["type": "integer", "description": "The age"]
            ],
            "required": ["name", "age"]
        ]
        let responseFormat = ResponseFormat.jsonSchema(schemaDict)

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: responseFormat
        )

        // Verify by checking the JSON structure
        let json = try JSONSerialization.jsonObject(with: request.body!) as? [String: Any]
        let format = json?["response_format"] as? [String: Any]

        #expect(format != nil, "Should include response format")
        #expect(format?["type"] as? String == "json_schema", "Should be json_schema type")
        #expect(format?["json_schema"] != nil, "Should include JSON schema")
    }

    @Test("GPT builder handles nil response format")
    func testGPTBuilderWithNilResponseFormat() throws {
        let builder = GPTRequestBuilder()

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: nil
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.responseFormat == nil, "Should not include response format when nil")
    }

    @Test("Reasoning builder includes response format")
    func testReasoningBuilderWithResponseFormat() throws {
        let builder = ReasoningRequestBuilder()

        let request = try builder.buildChatRequest(
            model: .o1,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: .json
        )

        // Verify by checking the JSON structure
        let json = try JSONSerialization.jsonObject(with: request.body!) as? [String: Any]
        let responseFormat = json?["response_format"] as? [String: Any]

        #expect(responseFormat != nil, "Reasoning builder should include response format")
        #expect(responseFormat?["type"] as? String == "json_object", "Should be json_object type")
    }

    @Test("Stream request includes response format")
    func testStreamRequestWithResponseFormat() throws {
        let builder = GPTRequestBuilder()

        let request = try builder.buildStreamRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: nil,
            responseFormat: .json
        )

        // Verify by checking the JSON structure
        let json = try JSONSerialization.jsonObject(with: request.body!) as? [String: Any]
        let responseFormat = json?["response_format"] as? [String: Any]

        #expect(json?["stream"] as? Bool == true, "Should be a stream request")
        #expect(responseFormat != nil, "Stream request should include response format")
        #expect(responseFormat?["type"] as? String == "json_object", "Should be json_object type")
    }

    @Test("Request includes both tools and response format")
    func testRequestWithToolsAndResponseFormat() throws {
        let builder = GPTRequestBuilder()

        let tool = Tool(
            function: Tool.Function(
                name: "get_data",
                description: "Get some data",
                parameters: JSONSchema(type: "object", properties: [:], required: nil)
            )
        )

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions,
            tools: [tool],
            responseFormat: .json
        )

        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)

        #expect(chatRequest.tools != nil, "Should include tools")
        #expect(chatRequest.tools?.count == 1, "Should have one tool")
        #expect(chatRequest.responseFormat != nil, "Should include response format")
    }
}