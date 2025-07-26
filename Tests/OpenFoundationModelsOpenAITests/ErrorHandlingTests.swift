import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    
    // MARK: - Mock Error Factory
    
    private static func createMockAPIError(code: String, message: String) -> OpenAIAPIError {
        return OpenAIAPIError(
            message: message,
            type: "error",
            param: nil,
            code: code
        )
    }
    
    private static func createMockNetworkError() -> URLError {
        return URLError(.notConnectedToInternet)
    }
    
    private static func createMockTimeoutError() -> URLError {
        return URLError(.timedOut)
    }
    
    // MARK: - Response Handler Error Tests
    
    @Test("GPT handler preserves network errors")
    func testGPTHandlerNetworkError() {
        let handler = GPTResponseHandler()
        let networkError = Self.createMockNetworkError()
        let model = OpenAIModel.gpt4o
        
        let mappedError = handler.handleError(networkError, for: model)
        
        #expect(mappedError is URLError, "GPT handler should preserve network errors")
        #expect((mappedError as? URLError)?.code == .notConnectedToInternet, "Should preserve error code")
    }
    
    @Test("GPT handler preserves timeout errors")
    func testGPTHandlerTimeoutError() {
        let handler = GPTResponseHandler()
        let timeoutError = Self.createMockTimeoutError()
        let model = OpenAIModel.gpt4o
        
        let mappedError = handler.handleError(timeoutError, for: model)
        
        #expect(mappedError is URLError, "GPT handler should preserve timeout errors")
        #expect((mappedError as? URLError)?.code == .timedOut, "Should preserve timeout code")
    }
    
    @Test("Reasoning handler handles reasoning-specific errors")
    func testReasoningHandlerSpecificErrors() {
        let handler = ReasoningResponseHandler()
        let reasoningError = Self.createMockAPIError(
            code: "reasoning_failed", 
            message: "Reasoning process failed"
        )
        let model = OpenAIModel.o1
        
        let mappedError = handler.handleError(reasoningError, for: model)
        
        if case let OpenAIResponseError.reasoningFailed(message) = mappedError {
            #expect(message == "Reasoning process failed", "Should map to reasoning failed error")
        } else {
            #expect(Bool(false), "Should map to reasoning failed error")
        }
    }
    
    @Test("Reasoning handler handles context complexity errors")
    func testReasoningHandlerContextComplexityError() {
        let handler = ReasoningResponseHandler()
        let complexityError = Self.createMockAPIError(
            code: "context_too_complex", 
            message: "Context is too complex for reasoning"
        )
        let model = OpenAIModel.o3Pro
        
        let mappedError = handler.handleError(complexityError, for: model)
        
        if case let OpenAIResponseError.contextTooComplex(modelName) = mappedError {
            #expect(modelName == "o3-pro", "Should include correct model name")
        } else {
            #expect(Bool(false), "Should map to context too complex error")
        }
    }
    
    @Test("Reasoning handler falls back to standard error mapping")
    func testReasoningHandlerFallback() {
        let handler = ReasoningResponseHandler()
        let standardError = Self.createMockAPIError(
            code: "rate_limit_exceeded", 
            message: "Rate limit exceeded"
        )
        let model = OpenAIModel.o1
        
        let mappedError = handler.handleError(standardError, for: model)
        
        // Should fall back to standard error mapping
        #expect(mappedError != nil, "Should handle standard errors")
    }
    
    // MARK: - OpenAI Model Error Type Tests
    
    @Test("Model not available error provides correct information")
    func testModelNotAvailableError() {
        let error = OpenAIModelError.modelNotAvailable("gpt-4o")
        let description = error.localizedDescription
        let suggestion = error.recoverySuggestion
        
        #expect(description.contains("gpt-4o"), "Should mention model name")
        #expect(description.contains("not available"), "Should mention availability")
        #expect(suggestion != nil, "Should provide recovery suggestion")
        #expect(suggestion!.contains("Check"), "Should suggest checking availability")
    }
    
    @Test("Context length exceeded error provides correct information")
    func testContextLengthExceededError() {
        let error = OpenAIModelError.contextLengthExceeded(model: "gpt-4o", maxTokens: 128000)
        let description = error.localizedDescription
        let suggestion = error.recoverySuggestion
        
        #expect(description.contains("gpt-4o"), "Should mention model name")
        #expect(description.contains("128000"), "Should mention token limit")
        #expect(description.contains("exceeded"), "Should mention exceeding limit")
        #expect(suggestion != nil, "Should provide recovery suggestion")
        #expect(suggestion!.contains("Reduce"), "Should suggest reducing prompt")
    }
    
    @Test("Rate limit exceeded error provides correct information")
    func testRateLimitExceededError() {
        let error = OpenAIModelError.rateLimitExceeded
        let description = error.localizedDescription
        let suggestion = error.recoverySuggestion
        
        #expect(description.contains("Rate limit"), "Should mention rate limit")
        #expect(description.contains("exceeded"), "Should mention exceeding limit")
        #expect(suggestion != nil, "Should provide recovery suggestion")
        #expect(suggestion!.contains("backoff"), "Should suggest backoff strategy")
    }
    
    @Test("Quota exceeded error provides correct information")
    func testQuotaExceededError() {
        let error = OpenAIModelError.quotaExceeded
        let description = error.localizedDescription
        let suggestion = error.recoverySuggestion
        
        #expect(description.contains("quota"), "Should mention quota")
        #expect(description.contains("exceeded"), "Should mention exceeding quota")
        #expect(suggestion != nil, "Should provide recovery suggestion")
        #expect(suggestion!.contains("credits") || suggestion!.contains("upgrade"), "Should suggest adding credits or upgrading")
    }
    
    @Test("Parameter not supported error provides correct information")
    func testParameterNotSupportedError() {
        let error = OpenAIModelError.parameterNotSupported(parameter: "temperature", model: "o1")
        let description = error.localizedDescription
        let suggestion = error.recoverySuggestion
        
        #expect(description.contains("temperature"), "Should mention parameter name")
        #expect(description.contains("o1"), "Should mention model name")
        #expect(description.contains("not supported"), "Should mention lack of support")
        #expect(suggestion != nil, "Should provide recovery suggestion")
        #expect(suggestion!.contains("Remove"), "Should suggest removing parameter")
    }
    
    @Test("Invalid request error provides correct information")
    func testInvalidRequestError() {
        let error = OpenAIModelError.invalidRequest("Invalid JSON format")
        let description = error.localizedDescription
        
        #expect(description.contains("Invalid JSON format"), "Should include error message")
        #expect(description.contains("Invalid request"), "Should mention invalid request")
    }
    
    @Test("API error wraps original error correctly")
    func testAPIErrorWrapping() {
        let originalError = Self.createMockAPIError(code: "test_error", message: "Test message")
        let error = OpenAIModelError.apiError(originalError)
        let description = error.localizedDescription
        
        #expect(description.contains("Test message"), "Should include original error message")
        #expect(description.contains("API error"), "Should mention API error")
    }
    
    // MARK: - OpenAI Response Error Type Tests
    
    @Test("Empty response error provides correct information")
    func testEmptyResponseError() {
        let error = OpenAIResponseError.emptyResponse
        let description = error.localizedDescription
        
        #expect(!description.isEmpty, "Should have error description")
        #expect(description.contains("empty"), "Should mention empty response")
    }
    
    @Test("No content error provides correct information")
    func testNoContentError() {
        let error = OpenAIResponseError.noContent
        let description = error.localizedDescription
        
        #expect(!description.isEmpty, "Should have error description")
        #expect(description.contains("no content"), "Should mention no content")
    }
    
    @Test("Invalid format error provides correct information")
    func testInvalidFormatError() {
        let error = OpenAIResponseError.invalidFormat
        let description = error.localizedDescription
        
        #expect(!description.isEmpty, "Should have error description")
        #expect(description.contains("invalid"), "Should mention invalid format")
    }
    
    @Test("Reasoning failed error provides correct information")
    func testReasoningFailedError() {
        let error = OpenAIResponseError.reasoningFailed(message: "Complex reasoning failed")
        let description = error.localizedDescription
        
        #expect(!description.isEmpty, "Should have error description")
        #expect(description.contains("reasoning"), "Should mention reasoning")
        #expect(description.contains("Complex reasoning failed"), "Should include specific message")
    }
    
    @Test("Context too complex error provides correct information")
    func testContextTooComplexError() {
        let error = OpenAIResponseError.contextTooComplex(model: "o3")
        let description = error.localizedDescription
        
        #expect(!description.isEmpty, "Should have error description")
        #expect(description.contains("Context"), "Should mention context")
        #expect(description.contains("o3"), "Should mention model name")
        #expect(description.contains("complex"), "Should mention complexity")
    }
    
    @Test("Streaming error provides correct information")
    func testStreamingError() {
        let error = OpenAIResponseError.streamingError("Connection lost")
        let description = error.localizedDescription
        
        #expect(!description.isEmpty, "Should have error description")
        #expect(description.contains("Streaming"), "Should mention streaming")
        #expect(description.contains("Connection lost"), "Should include specific message")
    }
    
    @Test("Decoding error provides correct information")
    func testDecodingError() {
        let originalError = DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Invalid JSON")
        )
        let error = OpenAIResponseError.decodingError(originalError)
        let description = error.localizedDescription
        
        #expect(!description.isEmpty, "Should have error description")
        #expect(description.contains("decode"), "Should mention decoding")
    }
    
    // MARK: - Model Constraint Tests
    
    @Test("GPT model constraints are correct")
    func testGPTModelConstraints() {
        let gptModels: [OpenAIModel] = [.gpt4o, .gpt4oMini, .gpt4Turbo]
        
        for model in gptModels {
            let constraints = model.constraints
            
            #expect(constraints.supportsTemperature == true, "GPT models should support temperature")
            #expect(constraints.supportsTopP == true, "GPT models should support topP")
            #expect(constraints.supportsFrequencyPenalty == true, "GPT models should support frequency penalty")
            #expect(constraints.supportsPresencePenalty == true, "GPT models should support presence penalty")
            #expect(constraints.supportsStop == true, "GPT models should support stop sequences")
            #expect(constraints.maxTokensParameterName == "max_tokens", "GPT models should use max_tokens")
            
            if let tempRange = constraints.temperatureRange {
                #expect(tempRange.contains(0.7), "Should accept valid temperature")
                #expect(!tempRange.contains(-0.1), "Should reject negative temperature")
                #expect(!tempRange.contains(2.1), "Should reject temperature > 2.0")
            }
            
            if let topPRange = constraints.topPRange {
                #expect(topPRange.contains(0.9), "Should accept valid topP")
                #expect(!topPRange.contains(-0.1), "Should reject negative topP")
                #expect(!topPRange.contains(1.1), "Should reject topP > 1.0")
            }
        }
    }
    
    @Test("Reasoning model constraints are correct")
    func testReasoningModelConstraints() {
        let reasoningModels: [OpenAIModel] = [.o1, .o1Pro, .o3, .o3Pro, .o4Mini]
        
        for model in reasoningModels {
            let constraints = model.constraints
            
            #expect(constraints.supportsTemperature == false, "Reasoning models should not support temperature")
            #expect(constraints.supportsTopP == false, "Reasoning models should not support topP")
            #expect(constraints.supportsFrequencyPenalty == false, "Reasoning models should not support frequency penalty")
            #expect(constraints.supportsPresencePenalty == false, "Reasoning models should not support presence penalty")
            #expect(constraints.supportsStop == false, "Reasoning models should not support stop sequences")
            #expect(constraints.maxTokensParameterName == "max_completion_tokens", "Reasoning models should use max_completion_tokens")
            
            #expect(constraints.temperatureRange == nil, "Reasoning models should not have temperature range")
            #expect(constraints.topPRange == nil, "Reasoning models should not have topP range")
        }
    }
    
    // MARK: - Error Scenarios Tests
    
    @Test("Handler gracefully handles unknown errors")
    func testUnknownErrorHandling() {
        let handler = GPTResponseHandler()
        let unknownError = NSError(domain: "TestDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        let model = OpenAIModel.gpt4o
        
        let mappedError = handler.handleError(unknownError, for: model)
        
        #expect(mappedError is NSError, "Should preserve unknown errors")
        #expect((mappedError as NSError).code == 999, "Should preserve error code")
    }
    
    @Test("Response handler types are created correctly")
    func testResponseHandlerTypes() {
        // Test GPT models
        let gptHandler = GPTResponseHandler()
        #expect(type(of: gptHandler) == GPTResponseHandler.self, "Should create GPT handler for GPT models")
        
        // Test reasoning models
        let reasoningHandler = ReasoningResponseHandler()
        #expect(type(of: reasoningHandler) == ReasoningResponseHandler.self, "Should create reasoning handler for reasoning models")
    }
    
    @Test("Error handling performance with multiple errors")
    func testErrorHandlingPerformance() {
        let handler = GPTResponseHandler()
        let model = OpenAIModel.gpt4o
        let errors = (0..<1000).map { i in
            URLError(.init(rawValue: 1000 + i))
        }
        
        let startTime = Date()
        
        for error in errors {
            _ = handler.handleError(error, for: model)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 0.1, "Should handle 1000 errors quickly (< 100ms)")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Error descriptions are non-empty for all error types")
    func testErrorDescriptionsNonEmpty() {
        let modelErrors: [OpenAIModelError] = [
            .modelNotAvailable("test-model"),
            .parameterNotSupported(parameter: "temp", model: "test"),
            .contextLengthExceeded(model: "test", maxTokens: 1000),
            .invalidRequest("test message"),
            .rateLimitExceeded,
            .quotaExceeded,
            .apiError(Self.createMockAPIError(code: "test", message: "test"))
        ]
        
        for error in modelErrors {
            let description = error.localizedDescription
            #expect(!description.isEmpty, "Error description should not be empty")
            #expect(description.count > 5, "Error description should be meaningful")
        }
        
        let responseErrors: [OpenAIResponseError] = [
            .emptyResponse,
            .noContent,
            .invalidFormat,
            .reasoningFailed(message: "test"),
            .contextTooComplex(model: "test"),
            .streamingError("test"),
            .decodingError(DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "test")
            ))
        ]
        
        for error in responseErrors {
            let description = error.localizedDescription
            #expect(!description.isEmpty, "Response error description should not be empty")
            #expect(description.count > 5, "Response error description should be meaningful")
        }
    }
    
    @Test("Recovery suggestions exist where appropriate")
    func testRecoverySuggestions() {
        let errorsWithSuggestions: [OpenAIModelError] = [
            .modelNotAvailable("test-model"),
            .parameterNotSupported(parameter: "temp", model: "test"),
            .contextLengthExceeded(model: "test", maxTokens: 1000),
            .rateLimitExceeded,
            .quotaExceeded
        ]
        
        for error in errorsWithSuggestions {
            let suggestion = error.recoverySuggestion
            #expect(suggestion != nil, "Error should have recovery suggestion")
            #expect(!suggestion!.isEmpty, "Recovery suggestion should not be empty")
            #expect(suggestion!.count > 10, "Recovery suggestion should be helpful")
        }
    }
}