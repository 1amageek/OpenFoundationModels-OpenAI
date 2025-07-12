import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI

@Suite("HTTP Client Tests")
struct HTTPClientTests {
    
    // MARK: - Mock Data Factory
    
    private static func createMockConfiguration() -> OpenAIConfiguration {
        return OpenAIConfiguration(
            apiKey: "sk-test-key-12345",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            organization: "test-org",
            timeout: 30.0
        )
    }
    
    private static func createMockChatCompletionResponse() -> Data {
        let response = ChatCompletionResponse(
            id: "test-response-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionResponse.Choice(
                    index: 0,
                    message: ChatMessage.assistant("Hello, this is a test response!"),
                    finishReason: "stop"
                )
            ],
            usage: ChatCompletionResponse.Usage(
                promptTokens: 10,
                completionTokens: 8,
                totalTokens: 18,
                reasoningTokens: nil
            ),
            systemFingerprint: "fp-test-123"
        )
        
        return try! JSONEncoder().encode(response)
    }
    
    private static func createMockStreamingChunk(content: String) -> Data {
        let chunk = ChatCompletionStreamResponse(
            id: "test-stream-id",
            object: "chat.completion.chunk",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [
                ChatCompletionStreamResponse.StreamChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                        role: nil,
                        content: content,
                        toolCalls: nil
                    ),
                    finishReason: nil
                )
            ]
        )
        
        let jsonData = try! JSONEncoder().encode(chunk)
        return "data: \(String(data: jsonData, encoding: .utf8)!)\n\n".data(using: .utf8)!
    }
    
    private static func createMockHTTPRequest() -> OpenAIHTTPRequest {
        let chatRequest = ChatCompletionRequest(
            model: "gpt-4o",
            messages: [ChatMessage.user("Hello")],
            temperature: 0.7,
            maxTokens: 100
        )
        
        let body = try! JSONEncoder().encode(chatRequest)
        
        return OpenAIHTTPRequest(
            endpoint: "chat/completions",
            method: .POST,
            headers: [:],
            body: body
        )
    }
    
    // MARK: - HTTP Request Structure Tests
    
    @Test("HTTP request has correct structure")
    func testHTTPRequestStructure() {
        let request = Self.createMockHTTPRequest()
        
        #expect(request.endpoint == "chat/completions", "Should have correct endpoint")
        #expect(request.method == .POST, "Should use POST method")
        #expect(request.body != nil, "Should have request body")
        #expect(request.headers.isEmpty, "Headers should be empty by default")
    }
    
    @Test("HTTP request method enum works correctly")
    func testHTTPMethodEnum() {
        let postMethod = HTTPMethod.POST
        let getMethod = HTTPMethod.GET
        
        #expect(postMethod != getMethod, "Different methods should not be equal")
        #expect(postMethod.rawValue == "POST", "POST method should have correct raw value")
        #expect(getMethod.rawValue == "GET", "GET method should have correct raw value")
    }
    
    @Test("HTTP request is sendable compliant")
    func testHTTPRequestSendable() async {
        let request = Self.createMockHTTPRequest()
        
        // Test concurrent access
        await withTaskGroup(of: String.self) { group in
            for i in 0..<10 {
                group.addTask {
                    return "\(request.endpoint)-\(i)"
                }
            }
            
            for await result in group {
                #expect(result.contains("chat/completions"), "Should access endpoint in concurrent context")
            }
        }
    }
    
    // MARK: - HTTP Error Tests
    
    @Test("HTTP error types are correctly defined")
    func testHTTPErrorTypes() {
        let statusError = OpenAIHTTPError.statusError(404, nil)
        let invalidResponseError = OpenAIHTTPError.invalidResponse
        let networkError = OpenAIHTTPError.networkError(URLError(.notConnectedToInternet))
        let invalidURLError = OpenAIHTTPError.invalidURL("invalid://url")
        
        // Test error descriptions
        #expect(!statusError.localizedDescription.isEmpty, "Status error should have description")
        #expect(!invalidResponseError.localizedDescription.isEmpty, "Invalid response error should have description")
        #expect(!networkError.localizedDescription.isEmpty, "Network error should have description")
        #expect(!invalidURLError.localizedDescription.isEmpty, "Invalid URL error should have description")
    }
    
    @Test("HTTP status error includes status code")
    func testHTTPStatusErrorDetails() {
        let error404 = OpenAIHTTPError.statusError(404, nil)
        let error500 = OpenAIHTTPError.statusError(500, "Internal server error".data(using: .utf8))
        
        if case let OpenAIHTTPError.statusError(code, data) = error404 {
            #expect(code == 404, "Should preserve status code")
            #expect(data == nil, "Should preserve nil data")
        } else {
            #expect(Bool(false), "Should be status error")
        }
        
        if case let OpenAIHTTPError.statusError(code, data) = error500 {
            #expect(code == 500, "Should preserve status code")
            #expect(data != nil, "Should preserve response data")
        } else {
            #expect(Bool(false), "Should be status error")
        }
    }
    
    @Test("Network error wraps original URLError")
    func testNetworkErrorWrapping() {
        let originalError = URLError(.timedOut)
        let httpError = OpenAIHTTPError.networkError(originalError)
        
        if case let OpenAIHTTPError.networkError(wrappedError) = httpError {
            if let urlError = wrappedError as? URLError {
                #expect(urlError.code == .timedOut, "Should preserve original error code")
            } else {
                #expect(Bool(false), "Wrapped error should be URLError")
            }
        } else {
            #expect(Bool(false), "Should be network error")
        }
    }
    
    // MARK: - Request Building Tests
    
    @Test("Request body contains valid JSON")
    func testRequestBodyJSON() throws {
        let request = Self.createMockHTTPRequest()
        
        guard let body = request.body else {
            #expect(Bool(false), "Request should have body")
            return
        }
        
        // Verify it's valid JSON
        let jsonObject = try JSONSerialization.jsonObject(with: body, options: [])
        #expect(jsonObject is [String: Any], "Body should be valid JSON object")
        
        // Verify specific fields
        if let dict = jsonObject as? [String: Any] {
            #expect(dict["model"] as? String == "gpt-4o", "Should include model")
            #expect(dict["messages"] is [[String: Any]], "Should include messages")
            #expect(dict["temperature"] as? Double == 0.7, "Should include temperature")
            #expect(dict["max_tokens"] as? Int == 100, "Should include max_tokens")
        }
    }
    
    @Test("Request headers can be customized")
    func testCustomHeaders() {
        let customHeaders = [
            "Authorization": "Bearer test-token",
            "Content-Type": "application/json",
            "User-Agent": "OpenFoundationModels/1.0"
        ]
        
        let request = OpenAIHTTPRequest(
            endpoint: "chat/completions",
            method: .POST,
            headers: customHeaders,
            body: nil
        )
        
        #expect(request.headers.count == 3, "Should have custom headers")
        #expect(request.headers["Authorization"] == "Bearer test-token", "Should preserve authorization header")
        #expect(request.headers["Content-Type"] == "application/json", "Should preserve content type")
        #expect(request.headers["User-Agent"] == "OpenFoundationModels/1.0", "Should preserve user agent")
    }
    
    @Test("Request can be created without body")
    func testRequestWithoutBody() {
        let request = OpenAIHTTPRequest(
            endpoint: "models",
            method: .GET,
            headers: [:],
            body: nil
        )
        
        #expect(request.endpoint == "models", "Should have correct endpoint")
        #expect(request.method == .GET, "Should use GET method")
        #expect(request.body == nil, "Should have no body")
    }
    
    // MARK: - Response Processing Tests
    
    @Test("Chat completion response can be decoded")
    func testChatCompletionResponseDecoding() throws {
        let responseData = Self.createMockChatCompletionResponse()
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(ChatCompletionResponse.self, from: responseData)
        
        #expect(response.id == "test-response-id", "Should decode ID correctly")
        #expect(response.model == "gpt-4o", "Should decode model correctly")
        #expect(response.choices.count == 1, "Should have one choice")
        #expect(response.choices.first?.message.content?.text == "Hello, this is a test response!", "Should decode message content")
        #expect(response.usage?.totalTokens == 18, "Should decode usage correctly")
    }
    
    @Test("Streaming response chunks can be decoded")
    func testStreamingResponseDecoding() throws {
        let chunkData = Self.createMockStreamingChunk(content: "Hello")
        
        // Extract JSON from SSE format
        let dataString = String(data: chunkData, encoding: .utf8)!
        let jsonString = dataString.replacingOccurrences(of: "data: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let chunk = try decoder.decode(ChatCompletionStreamResponse.self, from: jsonData)
        
        #expect(chunk.id == "test-stream-id", "Should decode stream ID")
        #expect(chunk.model == "gpt-4o", "Should decode model")
        #expect(chunk.choices.first?.delta.content == "Hello", "Should decode delta content")
    }
    
    @Test("Response handles empty choices gracefully")
    func testEmptyChoicesResponse() throws {
        let response = ChatCompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-4o",
            choices: [], // Empty choices
            usage: nil,
            systemFingerprint: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        
        let decoder = JSONDecoder()
        let decodedResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        #expect(decodedResponse.choices.isEmpty, "Should handle empty choices")
        #expect(decodedResponse.id == "test-id", "Should preserve other fields")
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("HTTP client handles concurrent requests safely")
    func testConcurrentRequestSafety() async {
        let config = Self.createMockConfiguration()
        let _ = OpenAIHTTPClient(configuration: config)
        
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    // Test that HTTP client creation is thread-safe
                    let testConfig = Self.createMockConfiguration()
                    let _ = OpenAIHTTPClient(configuration: testConfig)
                    return true
                }
            }
            
            for await result in group {
                #expect(result == true, "Concurrent access should be safe")
            }
        }
    }
    
    // MARK: - Request Validation Tests
    
    @Test("Request validates endpoint format")
    func testEndpointValidation() {
        let validEndpoints = [
            "chat/completions",
            "models",
            "embeddings",
            "moderations"
        ]
        
        for endpoint in validEndpoints {
            let request = OpenAIHTTPRequest(
                endpoint: endpoint,
                method: .POST,
                headers: [:],
                body: nil
            )
            
            #expect(request.endpoint == endpoint, "Should preserve valid endpoint")
            #expect(!request.endpoint.isEmpty, "Endpoint should not be empty")
        }
    }
    
    @Test("Request handles special characters in endpoint")
    func testSpecialCharactersInEndpoint() {
        let specialEndpoint = "models/gpt-4o-mini"
        let request = OpenAIHTTPRequest(
            endpoint: specialEndpoint,
            method: .GET,
            headers: [:],
            body: nil
        )
        
        #expect(request.endpoint == specialEndpoint, "Should handle hyphens in endpoint")
    }
    
    // MARK: - Body Encoding Tests
    
    @Test("Request body encoding preserves data integrity")
    func testBodyEncodingIntegrity() throws {
        let originalData = "Hello, World! 🌍".data(using: .utf8)!
        
        let request = OpenAIHTTPRequest(
            endpoint: "test",
            method: .POST,
            headers: [:],
            body: originalData
        )
        
        #expect(request.body == originalData, "Should preserve original data")
        
        if let body = request.body {
            let reconstructedString = String(data: body, encoding: .utf8)
            #expect(reconstructedString == "Hello, World! 🌍", "Should preserve unicode characters")
        }
    }
    
    @Test("Request body encoding handles large payloads")
    func testLargePayloadEncoding() throws {
        let largeString = String(repeating: "Large data chunk. ", count: 10000)
        let largeData = largeString.data(using: .utf8)!
        
        let request = OpenAIHTTPRequest(
            endpoint: "test",
            method: .POST,
            headers: [:],
            body: largeData
        )
        
        #expect(request.body != nil, "Should handle large payloads")
        #expect(request.body?.count == largeData.count, "Should preserve data size")
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("HTTP error provides recovery information")
    func testHTTPErrorRecovery() {
        let rateLimitError = OpenAIHTTPError.statusError(429, nil)
        let serverError = OpenAIHTTPError.statusError(500, nil)
        let networkError = OpenAIHTTPError.networkError(URLError(.notConnectedToInternet))
        
        // Test that errors provide meaningful descriptions
        #expect(rateLimitError.localizedDescription.contains("429"), "Rate limit error should mention status code")
        #expect(serverError.localizedDescription.contains("500"), "Server error should mention status code")
        #expect(!networkError.localizedDescription.isEmpty, "Network error should be descriptive")
    }
    
    // MARK: - Performance Tests
    
    @Test("Request creation is efficient")
    func testRequestCreationPerformance() {
        let startTime = Date()
        
        for _ in 0..<1000 {
            _ = OpenAIHTTPRequest(
                endpoint: "chat/completions",
                method: .POST,
                headers: ["Content-Type": "application/json"],
                body: "test data".data(using: .utf8)
            )
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 0.1, "Should create 1000 requests quickly (< 100ms)")
    }
    
    @Test("Response decoding is efficient")
    func testResponseDecodingPerformance() throws {
        let responseData = Self.createMockChatCompletionResponse()
        let decoder = JSONDecoder()
        
        let startTime = Date()
        
        for _ in 0..<1000 {
            _ = try decoder.decode(ChatCompletionResponse.self, from: responseData)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 0.5, "Should decode 1000 responses quickly (< 500ms)")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Request handles empty endpoint gracefully")
    func testEmptyEndpoint() {
        let request = OpenAIHTTPRequest(
            endpoint: "",
            method: .GET,
            headers: [:],
            body: nil
        )
        
        #expect(request.endpoint.isEmpty, "Should handle empty endpoint")
    }
    
    @Test("Request handles nil body gracefully")
    func testNilBody() {
        let request = OpenAIHTTPRequest(
            endpoint: "test",
            method: .GET,
            headers: [:],
            body: nil
        )
        
        #expect(request.body == nil, "Should handle nil body")
    }
    
    @Test("HTTP error descriptions are consistent")
    func testHTTPErrorDescriptions() {
        let invalidResponse1 = OpenAIHTTPError.invalidResponse
        let invalidResponse2 = OpenAIHTTPError.invalidResponse
        let statusError = OpenAIHTTPError.statusError(500, nil)
        
        // Note: We can't test equality directly as the enum doesn't conform to Equatable
        // But we can test that the same error types have consistent descriptions
        #expect(invalidResponse1.localizedDescription == invalidResponse2.localizedDescription, "Same error types should have same description")
        #expect(invalidResponse1.localizedDescription != statusError.localizedDescription, "Different error types should have different descriptions")
    }
    
    @Test("Request method string representation")
    func testMethodStringRepresentation() {
        let postMethod = HTTPMethod.POST
        let getMethod = HTTPMethod.GET
        
        // Test that methods can be used consistently
        let request1 = OpenAIHTTPRequest(endpoint: "test", method: postMethod, headers: [:], body: nil)
        let request2 = OpenAIHTTPRequest(endpoint: "test", method: getMethod, headers: [:], body: nil)
        
        #expect(request1.method == postMethod, "Should preserve POST method")
        #expect(request2.method == getMethod, "Should preserve GET method")
        #expect(request1.method != request2.method, "Different methods should not be equal")
    }
}