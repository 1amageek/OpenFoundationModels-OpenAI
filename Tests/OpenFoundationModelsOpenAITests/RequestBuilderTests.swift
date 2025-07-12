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
        maxTokens: 100,
        temperature: 0.7,
        topP: 0.9
    )
    
    // MARK: - GPT Request Builder Tests
    
    @Test("GPT request builder creates valid chat request")
    func testGPTChatRequest() throws {
        let builder = GPTRequestBuilder()
        
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions
        )
        
        #expect(request.endpoint == "chat/completions", "Should use correct endpoint")
        #expect(request.method == .POST, "Should use POST method")
        #expect(request.body != nil, "Should have request body")
        
        // Decode and verify the request body
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.model == "gpt-4o", "Should use correct model name")
        #expect(chatRequest.messages.count == 2, "Should include all messages")
        #expect(chatRequest.temperature == 0.7, "Should include temperature")
        #expect(chatRequest.topP == 0.9, "Should include topP")
        #expect(chatRequest.maxTokens == 100, "Should include maxTokens")
        #expect(chatRequest.stream == nil, "Chat request should not stream")
    }
    
    @Test("GPT request builder creates valid stream request")
    func testGPTStreamRequest() throws {
        let builder = GPTRequestBuilder()
        
        let request = try builder.buildStreamRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions
        )
        
        #expect(request.endpoint == "chat/completions", "Should use correct endpoint")
        #expect(request.method == .POST, "Should use POST method")
        
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
            options: Self.testOptions
        )
        
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.model == model.apiName, "Should use correct model API name")
        
        // GPT models should support temperature and topP
        #expect(chatRequest.temperature != nil, "GPT models should support temperature")
        #expect(chatRequest.topP != nil, "GPT models should support topP")
        #expect(chatRequest.maxTokens != nil, "GPT models should support maxTokens")
    }
    
    @Test("GPT request builder handles nil options")
    func testGPTBuilderWithNilOptions() throws {
        let builder = GPTRequestBuilder()
        
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: nil
        )
        
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.temperature == nil, "Should handle nil temperature")
        #expect(chatRequest.topP == nil, "Should handle nil topP")
        #expect(chatRequest.maxTokens == nil, "Should handle nil maxTokens")
    }
    
    // MARK: - Reasoning Request Builder Tests
    
    @Test("Reasoning request builder creates valid chat request")
    func testReasoningChatRequest() throws {
        let builder = ReasoningRequestBuilder()
        
        let request = try builder.buildChatRequest(
            model: .o1,
            messages: Self.testMessages,
            options: Self.testOptions
        )
        
        #expect(request.endpoint == "chat/completions", "Should use correct endpoint")
        #expect(request.method == .POST, "Should use POST method")
        
        // Decode and verify the request body
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.model == "o1", "Should use correct model name")
        #expect(chatRequest.messages.count == 2, "Should include all messages")
        
        // Reasoning models use max_completion_tokens instead of max_tokens
        #expect(chatRequest.maxCompletionTokens == 100, "Should use maxCompletionTokens")
        #expect(chatRequest.maxTokens == nil, "Should not use maxTokens for reasoning models")
        
        // Reasoning models don't support temperature and topP
        #expect(chatRequest.temperature == nil, "Reasoning models don't support temperature")
        #expect(chatRequest.topP == nil, "Reasoning models don't support topP")
    }
    
    @Test("Reasoning request builder creates valid stream request")
    func testReasoningStreamRequest() throws {
        let builder = ReasoningRequestBuilder()
        
        let request = try builder.buildStreamRequest(
            model: .o3,
            messages: Self.testMessages,
            options: Self.testOptions
        )
        
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.stream == true, "Stream request should enable streaming")
        #expect(chatRequest.model == "o3", "Should use correct model name")
        #expect(chatRequest.maxCompletionTokens == 100, "Should use maxCompletionTokens")
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
            options: Self.testOptions
        )
        
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.model == model.apiName, "Should use correct model API name")
        
        // Reasoning models should not support temperature and topP
        #expect(chatRequest.temperature == nil, "Reasoning models should not support temperature")
        #expect(chatRequest.topP == nil, "Reasoning models should not support topP")
        #expect(chatRequest.maxCompletionTokens != nil, "Reasoning models should use maxCompletionTokens")
        #expect(chatRequest.maxTokens == nil, "Reasoning models should not use maxTokens")
    }
    
    // MARK: - Request Builder Factory Tests
    
    @Test("Factory creates correct builder for GPT models")
    func testFactoryForGPTModels() {
        let gptBuilder = RequestBuilderFactory.createRequestBuilder(for: .gpt4o)
        let miniBuilder = RequestBuilderFactory.createRequestBuilder(for: .gpt4oMini)
        
        #expect(type(of: gptBuilder) == GPTRequestBuilder.self, "Should create GPTRequestBuilder for GPT models")
        #expect(type(of: miniBuilder) == GPTRequestBuilder.self, "Should create GPTRequestBuilder for GPT Mini models")
    }
    
    @Test("Factory creates correct builder for reasoning models")
    func testFactoryForReasoningModels() {
        let o1Builder = RequestBuilderFactory.createRequestBuilder(for: .o1)
        let o3Builder = RequestBuilderFactory.createRequestBuilder(for: .o3)
        
        #expect(type(of: o1Builder) == ReasoningRequestBuilder.self, "Should create ReasoningRequestBuilder for o1")
        #expect(type(of: o3Builder) == ReasoningRequestBuilder.self, "Should create ReasoningRequestBuilder for o3")
    }
    
    @Test("Factory creates correct builder type for all models", arguments: OpenAIModel.allCases)
    func testFactoryForAllModels(model: OpenAIModel) {
        let builder = RequestBuilderFactory.createRequestBuilder(for: model)
        
        switch model.modelType {
        case .gpt:
            #expect(type(of: builder) == GPTRequestBuilder.self, 
                   "Should create GPTRequestBuilder for GPT model \(model.apiName)")
        case .reasoning:
            #expect(type(of: builder) == ReasoningRequestBuilder.self, 
                   "Should create ReasoningRequestBuilder for reasoning model \(model.apiName)")
        }
    }
    
    // MARK: - Prompt Conversion Tests
    
    @Test("String to ChatMessage conversion works")
    func testStringToChatMessageConversion() {
        let prompt = "Hello, world!"
        let messages = [ChatMessage].from(prompt: prompt)
        
        #expect(messages.count == 1, "Should create single message")
        #expect(messages.first?.role == .user, "Should create user message")
        #expect(messages.first?.content?.text == prompt, "Should preserve prompt text")
    }
    
    @Test("Prompt to ChatMessage conversion works")
    func testPromptToChatMessageConversion() {
        // Create a simple prompt with text segments
        let segment1 = Prompt.Segment(text: "Hello", id: "1")
        let segment2 = Prompt.Segment(text: "world", id: "2")
        let prompt = Prompt(segments: [segment1, segment2])
        
        let messages = [ChatMessage].from(prompt: prompt)
        
        #expect(messages.count == 1, "Should create single message")
        #expect(messages.first?.role == .user, "Should create user message")
        #expect(messages.first?.content?.text == "Hello\nworld", "Should combine segments with newlines")
    }
    
    @Test("Empty prompt conversion works")
    func testEmptyPromptConversion() {
        let emptyPrompt = Prompt(segments: [])
        let messages = [ChatMessage].from(prompt: emptyPrompt)
        
        #expect(messages.count == 1, "Should create single message even for empty prompt")
        #expect(messages.first?.role == .user, "Should create user message")
        #expect(messages.first?.content?.text == "", "Should create empty message content")
    }
    
    // MARK: - HTTP Request Structure Tests
    
    @Test("HTTP request has correct structure")
    func testHTTPRequestStructure() throws {
        let builder = GPTRequestBuilder()
        
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions
        )
        
        #expect(request.endpoint == "chat/completions", "Should have correct endpoint")
        #expect(request.method == .POST, "Should use POST method")
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
            options: Self.testOptions
        )
        
        let request2 = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: Self.testOptions
        )
        
        // Decode both and compare
        let decoder = JSONDecoder()
        let chatRequest1 = try decoder.decode(ChatCompletionRequest.self, from: request1.body!)
        let chatRequest2 = try decoder.decode(ChatCompletionRequest.self, from: request2.body!)
        
        #expect(chatRequest1.model == chatRequest2.model, "Models should match")
        #expect(chatRequest1.temperature == chatRequest2.temperature, "Temperature should match")
        #expect(chatRequest1.maxTokens == chatRequest2.maxTokens, "MaxTokens should match")
    }
    
    // MARK: - Parameter Validation Tests
    
    @Test("GPT builder preserves all supported parameters")
    func testGPTParameterPreservation() throws {
        let options = GenerationOptions(
            maxTokens: 150,
            temperature: 0.8,
            topP: 0.95
        )
        
        let builder = GPTRequestBuilder()
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: options
        )
        
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.maxTokens == 150, "Should preserve maxTokens")
        #expect(chatRequest.temperature == 0.8, "Should preserve temperature")
        #expect(chatRequest.topP == 0.95, "Should preserve topP")
    }
    
    @Test("Reasoning builder filters unsupported parameters")
    func testReasoningParameterFiltering() throws {
        let options = GenerationOptions(
            maxTokens: 200,
            temperature: 0.5, // Should be filtered out
            topP: 0.8 // Should be filtered out
        )
        
        let builder = ReasoningRequestBuilder()
        let request = try builder.buildChatRequest(
            model: .o1,
            messages: Self.testMessages,
            options: options
        )
        
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.maxCompletionTokens == 200, "Should preserve maxTokens as maxCompletionTokens")
        #expect(chatRequest.temperature == nil, "Should filter out temperature")
        #expect(chatRequest.topP == nil, "Should filter out topP")
        #expect(chatRequest.maxTokens == nil, "Should not use maxTokens for reasoning models")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Builder handles empty message list")
    func testEmptyMessageList() throws {
        let builder = GPTRequestBuilder()
        
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: [],
            options: nil
        )
        
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.messages.isEmpty, "Should handle empty message list")
    }
    
    @Test("Builder handles extreme parameter values")
    func testExtremeParameterValues() throws {
        let options = GenerationOptions(
            maxTokens: 1, // Minimum
            temperature: 0.0, // Minimum
            topP: 1.0 // Maximum
        )
        
        let builder = GPTRequestBuilder()
        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: Self.testMessages,
            options: options
        )
        
        let decoder = JSONDecoder()
        let chatRequest = try decoder.decode(ChatCompletionRequest.self, from: request.body!)
        
        #expect(chatRequest.maxTokens == 1, "Should handle minimum maxTokens")
        #expect(chatRequest.temperature == 0.0, "Should handle minimum temperature")
        #expect(chatRequest.topP == 1.0, "Should handle maximum topP")
    }
}