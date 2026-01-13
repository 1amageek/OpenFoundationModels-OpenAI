import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI

@Suite("Response Handler Tests")
struct ResponseHandlerTests {
    
    // MARK: - Test Data
    
    private static func createChatCompletionResponse(content: String) -> ChatCompletionResponse {
        return ChatCompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0,
                    message: ChatMessage.assistant(content),
                    finishReason: "stop"
                )
            ],
            usage: ChatCompletionResponse.Usage(
                promptTokens: 10,
                completionTokens: content.count / 4,
                totalTokens: 10 + (content.count / 4),
                reasoningTokens: nil
            ),
            systemFingerprint: "test-fingerprint"
        )
    }
    
    private static func createStreamResponse(content: String) -> ChatCompletionStreamResponse {
        return ChatCompletionStreamResponse(
            id: "test-stream-id",
            object: "chat.completion.chunk",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionStreamResponse.StreamChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                        role: "assistant",
                        content: content,
                        toolCalls: nil
                    ),
                    finishReason: nil
                )
            ]
        )
    }
    
    private static func createEmptyResponse() -> ChatCompletionResponse {
        return ChatCompletionResponse(
            id: "empty-test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [],
            usage: nil,
            systemFingerprint: nil
        )
    }
    
    // MARK: - GPT Response Handler Tests
    
    @Test("GPT handler extracts content from valid response")
    func testGPTContentExtraction() throws {
        let handler = GPTResponseHandler()
        let response = Self.createChatCompletionResponse(content: "Hello, world!")
        
        let extractedContent = try handler.extractContent(from: response)
        
        #expect(extractedContent == "Hello, world!", "Should extract correct content")
    }
    
    @Test("GPT handler extracts content from multiline response")
    func testGPTMultilineContentExtraction() throws {
        let handler = GPTResponseHandler()
        let multilineContent = "Line 1\nLine 2\nLine 3"
        let response = Self.createChatCompletionResponse(content: multilineContent)
        
        let extractedContent = try handler.extractContent(from: response)
        
        #expect(extractedContent == multilineContent, "Should preserve multiline content")
    }
    
    @Test("GPT handler throws error for empty response")
    func testGPTEmptyResponseError() {
        let handler = GPTResponseHandler()
        let emptyResponse = Self.createEmptyResponse()
        
        do {
            _ = try handler.extractContent(from: emptyResponse)
            #expect(Bool(false), "Should throw error for empty response")
        } catch {
            #expect(error is OpenAIResponseError, "Should throw OpenAIResponseError")
            if case OpenAIResponseError.emptyResponse = error {
                // Success - expected error type
            } else {
                #expect(Bool(false), "Should throw emptyResponse error")
            }
        }
    }
    
    @Test("GPT handler extracts stream content")
    func testGPTStreamContentExtraction() throws {
        let handler = GPTResponseHandler()
        let streamChunk = Self.createStreamResponse(content: "Hello")
        
        let extractedContent = try handler.extractStreamContent(from: streamChunk)
        
        #expect(extractedContent == "Hello", "Should extract stream content")
    }
    
    @Test("GPT handler handles nil stream content")
    func testGPTNilStreamContent() throws {
        let handler = GPTResponseHandler()
        
        // Create stream chunk with nil content
        let streamChunk = ChatCompletionStreamResponse(
            id: "test-id",
            object: "chat.completion.chunk",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionStreamResponse.StreamChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                        role: "assistant",
                        content: nil,
                        toolCalls: nil
                    ),
                    finishReason: nil
                )
            ]
        )
        
        let extractedContent = try handler.extractStreamContent(from: streamChunk)
        
        #expect(extractedContent == nil, "Should return nil for nil stream content")
    }
    
    @Test("GPT handler handles empty stream choices")
    func testGPTEmptyStreamChoices() throws {
        let handler = GPTResponseHandler()
        
        let streamChunk = ChatCompletionStreamResponse(
            id: "test-id",
            object: "chat.completion.chunk",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: []
        )
        
        let extractedContent = try handler.extractStreamContent(from: streamChunk)
        
        #expect(extractedContent == nil, "Should return nil for empty choices")
    }
    
    // MARK: - Reasoning Response Handler Tests
    
    @Test("Reasoning handler extracts content from valid response")
    func testReasoningContentExtraction() throws {
        let handler = ReasoningResponseHandler()
        let response = Self.createChatCompletionResponse(content: "This is a reasoning response.")
        
        let extractedContent = try handler.extractContent(from: response)
        
        #expect(extractedContent == "This is a reasoning response.", "Should extract correct content")
    }
    
    @Test("Reasoning handler extracts stream content")
    func testReasoningStreamContentExtraction() throws {
        let handler = ReasoningResponseHandler()
        let streamChunk = Self.createStreamResponse(content: "Reasoning...")
        
        let extractedContent = try handler.extractStreamContent(from: streamChunk)
        
        #expect(extractedContent == "Reasoning...", "Should extract reasoning stream content")
    }
    
    @Test("Reasoning handler throws error for empty response")
    func testReasoningEmptyResponseError() {
        let handler = ReasoningResponseHandler()
        let emptyResponse = Self.createEmptyResponse()
        
        do {
            _ = try handler.extractContent(from: emptyResponse)
            #expect(Bool(false), "Should throw error for empty response")
        } catch {
            #expect(error is OpenAIResponseError, "Should throw OpenAIResponseError")
            if case OpenAIResponseError.emptyResponse = error {
                // Success - expected error type
            } else {
                #expect(Bool(false), "Should throw emptyResponse error")
            }
        }
    }
    
    // MARK: - Response Handler Type Tests
    
    @Test("Correct handler types are created for different model types")
    func testHandlerTypesForModelTypes() {
        // GPT models should use GPTResponseHandler
        let gptHandler = GPTResponseHandler()
        #expect(type(of: gptHandler) == GPTResponseHandler.self, "Should create GPTResponseHandler for GPT models")
        
        // Reasoning models should use ReasoningResponseHandler
        let reasoningHandler = ReasoningResponseHandler()
        #expect(type(of: reasoningHandler) == ReasoningResponseHandler.self, "Should create ReasoningResponseHandler for reasoning models")
    }
    
    @Test("Handler type selection based on model type", arguments: OpenAIModelInfo.allModels)
    func testHandlerSelectionForModels(model: OpenAIModel) {
        // This test verifies the logic that would be in OpenAILanguageModel init
        let handler: any ResponseHandler
        switch model.modelType {
        case .gpt:
            handler = GPTResponseHandler()
        case .reasoning:
            handler = ReasoningResponseHandler()
        }
        
        switch model.modelType {
        case .gpt:
            #expect(type(of: handler) == GPTResponseHandler.self, 
                   "Should create GPTResponseHandler for GPT model \(model.apiName)")
        case .reasoning:
            #expect(type(of: handler) == ReasoningResponseHandler.self, 
                   "Should create ReasoningResponseHandler for reasoning model \(model.apiName)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("GPT handler maps standard errors correctly")
    func testGPTErrorMapping() {
        let handler = GPTResponseHandler()
        let model = OpenAIModel.gpt4o
        
        // Test various error types
        let networkError = URLError(.notConnectedToInternet)
        let mappedError = handler.handleError(networkError, for: model)
        
        #expect(mappedError is URLError, "Should preserve network errors")
    }
    
    @Test("Reasoning handler handles reasoning-specific errors")
    func testReasoningErrorHandling() {
        let handler = ReasoningResponseHandler()
        let model = OpenAIModel.o1
        
        // Test with API error that should be mapped to reasoning-specific error
        let apiError = OpenAIAPIError(
            message: "Reasoning failed", 
            type: "reasoning_error", 
            param: nil, 
            code: "reasoning_failed"
        )
        
        let mappedError = handler.handleError(apiError, for: model)
        
        if case let OpenAIResponseError.reasoningFailed(message) = mappedError {
            #expect(message == "Reasoning failed", "Should map to reasoning failed error")
        } else {
            #expect(Bool(false), "Should map to reasoning failed error")
        }
    }
    
    @Test("Reasoning handler maps context complexity errors")
    func testReasoningContextComplexityError() {
        let handler = ReasoningResponseHandler()
        let model = OpenAIModel.o3
        
        let apiError = OpenAIAPIError(
            message: "Context too complex", 
            type: "reasoning_error", 
            param: nil, 
            code: "context_too_complex"
        )
        
        let mappedError = handler.handleError(apiError, for: model)
        
        if case let OpenAIResponseError.contextTooComplex(modelName) = mappedError {
            #expect(modelName == "o3", "Should map to context too complex error with correct model")
        } else {
            #expect(Bool(false), "Should map to context too complex error")
        }
    }
    
    // MARK: - Response Content Validation Tests
    
    @Test("Handler validates content structure")
    func testContentStructureValidation() throws {
        let handler = GPTResponseHandler()
        
        // Create response with valid content structure
        let response = ChatCompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0,
                    message: ChatMessage(
                        role: .assistant,
                        content: .text("Valid content"),
                        name: nil,
                        toolCalls: nil,
                        toolCallId: nil
                    ),
                    finishReason: "stop"
                )
            ],
            usage: nil,
            systemFingerprint: nil
        )
        
        let extractedContent = try handler.extractContent(from: response)
        #expect(extractedContent == "Valid content", "Should extract valid content")
    }
    
    @Test("Handler handles response with nil message content")
    func testNilMessageContent() {
        let handler = GPTResponseHandler()
        
        let response = ChatCompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0,
                    message: ChatMessage(
                        role: .assistant,
                        content: nil, // Nil content
                        name: nil,
                        toolCalls: nil,
                        toolCallId: nil
                    ),
                    finishReason: "stop"
                )
            ],
            usage: nil,
            systemFingerprint: nil
        )
        
        do {
            _ = try handler.extractContent(from: response)
            #expect(Bool(false), "Should throw error for nil content")
        } catch {
            #expect(error is OpenAIResponseError, "Should throw OpenAIResponseError")
            if case OpenAIResponseError.noContent = error {
                // Success - expected error type
            } else {
                #expect(Bool(false), "Should throw noContent error")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Handler performs efficiently with large content")
    func testLargeContentPerformance() throws {
        let handler = GPTResponseHandler()
        let largeContent = String(repeating: "This is a large content block. ", count: 1000)
        let response = Self.createChatCompletionResponse(content: largeContent)
        
        let startTime = Date()
        let extractedContent = try handler.extractContent(from: response)
        let endTime = Date()
        
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(extractedContent == largeContent, "Should extract large content correctly")
        #expect(executionTime < 0.1, "Should extract large content quickly (< 100ms)")
    }
    
    @Test("Handler performs efficiently with many stream chunks")
    func testStreamPerformance() throws {
        let handler = GPTResponseHandler()
        let chunks = (0..<100).map { i in
            Self.createStreamResponse(content: "Chunk \(i) ")
        }
        
        let startTime = Date()
        var combinedContent = ""
        
        for chunk in chunks {
            if let content = try handler.extractStreamContent(from: chunk) {
                combinedContent += content
            }
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(combinedContent.contains("Chunk 0"), "Should contain first chunk")
        #expect(combinedContent.contains("Chunk 99"), "Should contain last chunk")
        #expect(executionTime < 0.1, "Should process 100 chunks quickly (< 100ms)")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Handler handles response with multiple choices")
    func testMultipleChoicesResponse() throws {
        let handler = GPTResponseHandler()
        
        let response = ChatCompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0,
                    message: ChatMessage.assistant("First choice"),
                    finishReason: "stop"
                ),
                ChatCompletionResponse.Choice(
                    index: 1,
                    message: ChatMessage.assistant("Second choice"),
                    finishReason: "stop"
                )
            ],
            usage: nil,
            systemFingerprint: nil
        )
        
        let extractedContent = try handler.extractContent(from: response)
        
        // Should extract from first choice
        #expect(extractedContent == "First choice", "Should extract content from first choice")
    }
    
    @Test("Handler handles special characters in content")
    func testSpecialCharactersInContent() throws {
        let handler = GPTResponseHandler()
        let specialContent = "Hello! 🌟 This has émojis and ũnicöde: ñ, ø, ß, ∑, π"
        let response = Self.createChatCompletionResponse(content: specialContent)
        
        let extractedContent = try handler.extractContent(from: response)
        
        #expect(extractedContent == specialContent, "Should preserve special characters and unicode")
    }
    
    @Test("Handler handles extremely long single line")
    func testExtremelyLongSingleLine() throws {
        let handler = GPTResponseHandler()
        let longLine = String(repeating: "a", count: 50000) // 50k characters
        let response = Self.createChatCompletionResponse(content: longLine)
        
        let extractedContent = try handler.extractContent(from: response)
        
        #expect(extractedContent.count == 50000, "Should preserve extremely long single line")
        #expect(extractedContent == longLine, "Should preserve content exactly")
    }
    
    @Test("Handler handles empty string content")
    func testEmptyStringContent() throws {
        let handler = GPTResponseHandler()
        let response = Self.createChatCompletionResponse(content: "")
        
        let extractedContent = try handler.extractContent(from: response)
        
        #expect(extractedContent == "", "Should handle empty string content")
    }
    
    @Test("Handler handles whitespace-only content")
    func testWhitespaceOnlyContent() throws {
        let handler = GPTResponseHandler()
        let whitespaceContent = "   \n\t  \n  "
        let response = Self.createChatCompletionResponse(content: whitespaceContent)
        
        let extractedContent = try handler.extractContent(from: response)
        
        #expect(extractedContent == whitespaceContent, "Should preserve whitespace-only content")
    }
}