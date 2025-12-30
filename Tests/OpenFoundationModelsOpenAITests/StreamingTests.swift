import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI

@Suite("Streaming Tests")
struct StreamingTests {
    
    // MARK: - Mock Data Factory
    
    private static func createMockStreamChunk(content: String, isLast: Bool = false) -> Data {
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
                    finishReason: isLast ? "stop" : nil
                )
            ]
        )
        
        let encoder = JSONEncoder()
        let jsonData = try! encoder.encode(chunk)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return "data: \(jsonString)\n\n".data(using: .utf8)!
    }
    
    private static func createMockDoneChunk() -> Data {
        return "data: [DONE]\n\n".data(using: .utf8)!
    }
    
    private static func createMockEventChunk(event: String, data: String) -> Data {
        return "event: \(event)\ndata: \(data)\n\n".data(using: .utf8)!
    }
    
    private static func createMockEmptyChunk() -> Data {
        return "\n".data(using: .utf8)!
    }
    
    // MARK: - StreamingHandler Tests
    
    @Test("StreamingHandler processes simple chunk correctly")
    func testSimpleChunkProcessing() throws {
        let handler = StreamingHandler()
        let chunkData = Self.createMockStreamChunk(content: "Hello")
        
        let result = try handler.processStreamData(chunkData)
        
        #expect(result != nil, "Should process valid chunk")
        #expect(result?.count == 1, "Should return single chunk")
        #expect(result?.first?.choices.first?.delta.content == "Hello", "Should extract correct content")
    }
    
    @Test("StreamingHandler processes multiple words in sequence")
    func testMultipleWordProcessing() throws {
        let handler = StreamingHandler()
        let words = ["Hello", " ", "world", "!"]
        
        for word in words {
            let chunkData = Self.createMockStreamChunk(content: word)
            let result = try handler.processStreamData(chunkData)
            
            #expect(result != nil, "Should process each chunk")
            #expect(result?.first?.choices.first?.delta.content == word, "Should extract correct word: \(word)")
        }
    }
    
    @Test("StreamingHandler handles DONE signal")
    func testDoneSignalHandling() throws {
        let handler = StreamingHandler()
        let doneData = Self.createMockDoneChunk()
        
        let result = try handler.processStreamData(doneData)
        
        #expect(result == nil, "Should return nil for DONE signal")
    }
    
    @Test("StreamingHandler handles empty chunks")
    func testEmptyChunkHandling() throws {
        let handler = StreamingHandler()
        let emptyData = Self.createMockEmptyChunk()
        
        let result = try handler.processStreamData(emptyData)
        
        #expect(result == nil, "Should return nil for empty chunks")
    }
    
    @Test("StreamingHandler handles invalid UTF-8 data")
    func testInvalidUTF8Handling() throws {
        let handler = StreamingHandler()
        let invalidData = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8
        
        let result = try handler.processStreamData(invalidData)
        
        #expect(result == nil, "Should return nil for invalid UTF-8")
    }
    
    @Test("StreamingHandler processes Server-Sent Events format")
    func testServerSentEventsFormat() throws {
        let handler = StreamingHandler()
        let eventData = Self.createMockEventChunk(event: "message", data: "test")
        
        let result = try handler.processStreamData(eventData)
        
        #expect(result == nil, "Should return nil for non-data events")
    }
    
    // MARK: - AdvancedStreamingHandler Tests
    
    @Test("AdvancedStreamingHandler processes chunked data")
    func testAdvancedHandlerChunkedData() async throws {
        let handler = AdvancedStreamingHandler()
        
        // Simulate partial chunks
        let partialData1 = "data: {\"id\":\"test\",\"object\":\"chat.completion.chunk\",".data(using: .utf8)!
        let partialData2 = "\"created\":1234567890,\"model\":\"gpt-4o\",\"choices\":[{".data(using: .utf8)!
        let partialData3 = "\"index\":0,\"delta\":{\"content\":\"Hello\"},\"finish_reason\":null}]}\n\n".data(using: .utf8)!
        
        let result1 = try await handler.processStreamChunk(partialData1)
        #expect(result1.chunks.isEmpty, "Should not process incomplete chunk")
        
        let result2 = try await handler.processStreamChunk(partialData2)
        #expect(result2.chunks.isEmpty, "Should not process incomplete chunk")
        
        let result3 = try await handler.processStreamChunk(partialData3)
        #expect(result3.chunks.count == 1, "Should process complete chunk")
        #expect(result3.accumulatedContent == "Hello", "Should accumulate content")
    }
    
    @Test("AdvancedStreamingHandler accumulates content correctly")
    func testAdvancedHandlerContentAccumulation() async throws {
        let handler = AdvancedStreamingHandler()
        let chunks = ["Hello", " ", "world", "!"]
        
        var totalContent = ""
        for chunk in chunks {
            let chunkData = Self.createMockStreamChunk(content: chunk)
            let result = try await handler.processStreamChunk(chunkData)
            totalContent += chunk
            
            #expect(result.accumulatedContent == totalContent, "Should accumulate content correctly")
        }
        
        let finalContent = await handler.getAccumulatedContent()
        #expect(finalContent == "Hello world!", "Should return complete accumulated content")
    }
    
    @Test("AdvancedStreamingHandler detects stream completion")
    func testAdvancedHandlerStreamCompletion() async throws {
        let handler = AdvancedStreamingHandler()
        
        // Process some content
        let contentData = Self.createMockStreamChunk(content: "Hello")
        let contentResult = try await handler.processStreamChunk(contentData)
        #expect(contentResult.isComplete == false, "Should not be complete yet")
        
        // Process DONE signal
        let doneData = Self.createMockDoneChunk()
        let doneResult = try await handler.processStreamChunk(doneData)
        #expect(doneResult.isComplete == true, "Should detect completion")
        
        let isComplete = await handler.isStreamComplete()
        #expect(isComplete == true, "Should report stream as complete")
    }
    
    @Test("AdvancedStreamingHandler can be reset")
    func testAdvancedHandlerReset() async throws {
        let handler = AdvancedStreamingHandler()
        
        // Add some content
        let chunkData = Self.createMockStreamChunk(content: "Hello")
        _ = try await handler.processStreamChunk(chunkData)
        
        let contentBeforeReset = await handler.getAccumulatedContent()
        #expect(contentBeforeReset == "Hello", "Should have content before reset")
        
        // Reset the handler
        await handler.reset()
        
        let contentAfterReset = await handler.getAccumulatedContent()
        #expect(contentAfterReset == "", "Should be empty after reset")
        
        let isComplete = await handler.isStreamComplete()
        #expect(isComplete == false, "Should not be complete after reset")
    }
    
    // MARK: - StreamCollector Tests
    
    @Test("StreamCollector collects chunks correctly")
    func testStreamCollectorChunkCollection() async throws {
        let collector = StreamCollector()
        
        let chunk1 = ChatCompletionStreamResponse(
            id: "test1",
            object: "chat.completion.chunk",
            created: 1234567890,
            model: "gpt-4o",
            choices: [
                ChatCompletionStreamResponse.StreamChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                        role: nil,
                        content: "Hello",
                        toolCalls: nil
                    ),
                    finishReason: nil
                )
            ]
        )
        
        let chunk2 = ChatCompletionStreamResponse(
            id: "test2",
            object: "chat.completion.chunk",
            created: 1234567891,
            model: "gpt-4o",
            choices: [
                ChatCompletionStreamResponse.StreamChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                        role: nil,
                        content: " world",
                        toolCalls: nil
                    ),
                    finishReason: "stop"
                )
            ]
        )
        
        await collector.addChunk(chunk1)
        await collector.addChunk(chunk2)
        
        let collectedContent = await collector.getCollectedContent()
        #expect(collectedContent == "Hello world", "Should collect content from all chunks")
        
        let allChunks = await collector.getAllChunks()
        #expect(allChunks.count == 2, "Should store all chunks")
        
        let isComplete = await collector.isStreamComplete()
        #expect(isComplete == true, "Should detect completion from finish reason")
    }
    
    @Test("StreamCollector provides statistics")
    func testStreamCollectorStatistics() async throws {
        let collector = StreamCollector()
        let content = "Hello world! This is a test message."
        
        let chunk = ChatCompletionStreamResponse(
            id: "test",
            object: "chat.completion.chunk",
            created: 1234567890,
            model: "gpt-4o",
            choices: [
                ChatCompletionStreamResponse.StreamChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                        role: nil,
                        content: content,
                        toolCalls: nil
                    ),
                    finishReason: "stop"
                )
            ]
        )
        
        await collector.addChunk(chunk)
        
        let stats = await collector.getStatistics()
        #expect(stats.totalChunks == 1, "Should count chunks correctly")
        #expect(stats.totalCharacters == content.count, "Should count characters correctly")
        #expect(stats.estimatedTokens == content.count / 4, "Should estimate tokens correctly")
        #expect(stats.isComplete == true, "Should report completion status")
    }
    
    // MARK: - AsyncStream Extension Tests
    
    @Test("AsyncStream collect extension works correctly")
    func testAsyncStreamCollectExtension() async throws {
        // Create a mock AsyncStream
        let chunks = ["Hello", " ", "world", "!"]
        let stream = AsyncStream<String> { continuation in
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                    // Small delay to simulate real streaming
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
                continuation.finish()
            }
        }
        
        let collected = try await stream.collect()
        #expect(collected == "Hello world!", "Should collect all stream content")
    }
    
    @Test("AsyncStream collect handles empty stream")
    func testAsyncStreamCollectEmpty() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.finish()
        }
        
        let collected = try await stream.collect()
        #expect(collected == "", "Should return empty string for empty stream")
    }
    
    @Test("AsyncStream collect handles single item")
    func testAsyncStreamCollectSingleItem() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("Single item")
            continuation.finish()
        }
        
        let collected = try await stream.collect()
        #expect(collected == "Single item", "Should collect single item correctly")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("StreamingHandler handles malformed JSON")
    func testStreamingHandlerMalformedJSON() throws {
        let handler = StreamingHandler()
        let malformedData = "data: {invalid json}\n\n".data(using: .utf8)!
        
        #expect(throws: OpenAIResponseError.self) {
            try handler.processStreamData(malformedData)
        }
    }
    
    @Test("AdvancedStreamingHandler handles JSON parsing errors")
    func testAdvancedHandlerJSONError() async throws {
        let handler = AdvancedStreamingHandler()
        let malformedData = "data: {\"invalid\": json}\n\n".data(using: .utf8)!
        
        await #expect(throws: OpenAIResponseError.self) {
            try await handler.processStreamChunk(malformedData)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("StreamingHandler performs efficiently with many chunks")
    func testStreamingHandlerPerformance() throws {
        let handler = StreamingHandler()
        let chunks = (0..<1000).map { i in
            Self.createMockStreamChunk(content: "Chunk \(i) ")
        }
        
        let startTime = Date()
        
        for chunkData in chunks {
            _ = try handler.processStreamData(chunkData)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 1.0, "Should process 1000 chunks in less than 1 second")
    }
    
    @Test("AdvancedStreamingHandler performs efficiently")
    func testAdvancedHandlerPerformance() async throws {
        let handler = AdvancedStreamingHandler()
        let chunks = (0..<500).map { i in
            Self.createMockStreamChunk(content: "Word\(i) ")
        }
        
        let startTime = Date()
        
        for chunkData in chunks {
            _ = try await handler.processStreamChunk(chunkData)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 2.0, "Should process 500 chunks in less than 2 seconds")
        
        let finalContent = await handler.getAccumulatedContent()
        #expect(finalContent.contains("Word0"), "Should contain first word")
        #expect(finalContent.contains("Word499"), "Should contain last word")
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("StreamingHandler handles very large chunks")
    func testStreamingHandlerLargeChunks() throws {
        let handler = StreamingHandler()
        let largeContent = String(repeating: "Large content block. ", count: 1000)
        let chunkData = Self.createMockStreamChunk(content: largeContent)
        
        let result = try handler.processStreamData(chunkData)
        
        #expect(result != nil, "Should handle large chunks")
        #expect(result?.first?.choices.first?.delta.content == largeContent, "Should preserve large content")
    }
    
    @Test("AdvancedStreamingHandler handles rapid chunks")
    func testAdvancedHandlerRapidChunks() async throws {
        let handler = AdvancedStreamingHandler()
        let rapidChunks = (0..<100).map { _ in "." }
        
        // Process chunks as quickly as possible
        await withTaskGroup(of: Void.self) { group in
            for chunk in rapidChunks {
                group.addTask {
                    let chunkData = Self.createMockStreamChunk(content: chunk)
                    _ = try? await handler.processStreamChunk(chunkData)
                }
            }
        }
        
        let finalContent = await handler.getAccumulatedContent()
        #expect(finalContent.count <= 100, "Should handle rapid chunks without duplication")
        #expect(finalContent.allSatisfy { $0 == "." }, "Should contain only dots")
    }
    
    @Test("StreamingHandler handles special characters in stream")
    func testStreamingHandlerSpecialCharacters() throws {
        let handler = StreamingHandler()
        let specialContent = "Hello! 🌟 émojis: ñ, ø, ß, ∑, π, 中文, 日本語"
        let chunkData = Self.createMockStreamChunk(content: specialContent)
        
        let result = try handler.processStreamData(chunkData)
        
        #expect(result != nil, "Should handle special characters")
        #expect(result?.first?.choices.first?.delta.content == specialContent, "Should preserve special characters")
    }
    
    @Test("StreamingHandler handles empty content chunks")
    func testStreamingHandlerEmptyContent() throws {
        let handler = StreamingHandler()
        let chunkData = Self.createMockStreamChunk(content: "")
        
        let result = try handler.processStreamData(chunkData)
        
        #expect(result != nil, "Should handle empty content chunks")
        #expect(result?.first?.choices.first?.delta.content == "", "Should preserve empty content")
    }
    
    @Test("StreamCollector handles chunks without content")
    func testStreamCollectorNoContent() async throws {
        let collector = StreamCollector()

        let chunk = ChatCompletionStreamResponse(
            id: "test",
            object: "chat.completion.chunk",
            created: 1234567890,
            model: "gpt-4o",
            choices: [
                ChatCompletionStreamResponse.StreamChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                        role: "assistant",
                        content: nil, // No content
                        toolCalls: nil
                    ),
                    finishReason: nil
                )
            ]
        )

        await collector.addChunk(chunk)

        let collectedContent = await collector.getCollectedContent()
        #expect(collectedContent == "", "Should handle chunks without content")

        let allChunks = await collector.getAllChunks()
        #expect(allChunks.count == 1, "Should still store chunk without content")
    }

    // MARK: - Streaming Tool Calls Tests

    @Test("StreamingHandler processes tool call chunks")
    func testStreamingToolCallChunks() throws {
        let handler = StreamingHandler()

        // Create a tool call chunk
        let toolCallChunk = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_abc123","type":"function","function":{"name":"get_weather","arguments":""}}]},"finish_reason":null}]}
            """

        let result = try handler.processStreamData(toolCallChunk.data(using: .utf8)!)

        #expect(result != nil, "Should process tool call chunk")
        #expect(result?.first?.choices.first?.delta.toolCalls != nil, "Should have tool calls")
        #expect(result?.first?.choices.first?.delta.toolCalls?.first?.function.name == "get_weather", "Should have correct function name")
    }

    @Test("StreamingHandler accumulates tool call arguments")
    func testStreamingToolCallArgumentAccumulation() throws {
        let handler = StreamingHandler()

        // First chunk with function name
        let chunk1 = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_abc123","type":"function","function":{"name":"get_weather","arguments":""}}]},"finish_reason":null}]}
            """

        // Second chunk with partial arguments
        let chunk2 = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"loc"}}]},"finish_reason":null}]}
            """

        // Third chunk with more arguments
        let chunk3 = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ation\\":\\"Tokyo\\"}"}}]},"finish_reason":null}]}
            """

        let result1 = try handler.processStreamData(chunk1.data(using: .utf8)!)
        let result2 = try handler.processStreamData(chunk2.data(using: .utf8)!)
        let result3 = try handler.processStreamData(chunk3.data(using: .utf8)!)

        #expect(result1 != nil)
        #expect(result2 != nil)
        #expect(result3 != nil)

        // Verify each chunk has the expected structure
        #expect(result1?.first?.choices.first?.delta.toolCalls?.first?.id == "call_abc123")
        #expect(result2?.first?.choices.first?.delta.toolCalls?.first?.function.arguments == "{\"loc")
        #expect(result3?.first?.choices.first?.delta.toolCalls?.first?.function.arguments == "ation\":\"Tokyo\"}")
    }

    @Test("StreamingHandler handles multiple parallel tool calls")
    func testStreamingMultipleToolCalls() throws {
        let handler = StreamingHandler()

        // Chunk with multiple tool calls
        let chunk = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"get_weather","arguments":""}},{"index":1,"id":"call_2","type":"function","function":{"name":"get_time","arguments":""}}]},"finish_reason":null}]}
            """

        let result = try handler.processStreamData(chunk.data(using: .utf8)!)

        #expect(result != nil)
        #expect(result?.first?.choices.first?.delta.toolCalls?.count == 2, "Should have two tool calls")
        #expect(result?.first?.choices.first?.delta.toolCalls?[0].function.name == "get_weather")
        #expect(result?.first?.choices.first?.delta.toolCalls?[1].function.name == "get_time")
    }

    @Test("StreamingHandler handles tool call finish reason")
    func testStreamingToolCallFinishReason() throws {
        let handler = StreamingHandler()

        let chunk = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
            """

        let result = try handler.processStreamData(chunk.data(using: .utf8)!)

        #expect(result != nil)
        #expect(result?.first?.choices.first?.finishReason == "tool_calls", "Should have tool_calls finish reason")
    }

    @Test("AdvancedStreamingHandler accumulates tool calls across chunks")
    func testAdvancedStreamingToolCallAccumulation() async throws {
        let handler = AdvancedStreamingHandler()

        // First chunk with tool call start
        let chunk1 = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"role":"assistant","tool_calls":[{"index":0,"id":"call_xyz","type":"function","function":{"name":"search","arguments":""}}]},"finish_reason":null}]}

            """

        // Second chunk with arguments
        let chunk2 = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"query\\":\\"test\\"}"}}]},"finish_reason":null}]}

            """

        // Final chunk
        let chunk3 = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}

            """

        let result1 = try await handler.processStreamChunk(chunk1.data(using: .utf8)!)
        let result2 = try await handler.processStreamChunk(chunk2.data(using: .utf8)!)
        let result3 = try await handler.processStreamChunk(chunk3.data(using: .utf8)!)

        #expect(!result1.chunks.isEmpty || !result2.chunks.isEmpty || !result3.chunks.isEmpty, "Should process chunks")
        #expect(result3.isComplete, "Should be complete after tool_calls finish reason")
    }

    @Test("StreamCollector tracks tool call chunks")
    func testStreamCollectorToolCalls() async throws {
        let collector = StreamCollector()

        let toolCallChunk = ChatCompletionStreamResponse(
            id: "test",
            object: "chat.completion.chunk",
            created: 1234567890,
            model: "gpt-4o",
            choices: [
                ChatCompletionStreamResponse.StreamChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponse.StreamChoice.Delta(
                        role: "assistant",
                        content: nil,
                        toolCalls: [
                            StreamingToolCall(
                                index: 0,
                                id: "call_test",
                                type: "function",
                                function: StreamingToolCall.StreamingFunctionCall(
                                    name: "test_function",
                                    arguments: "{}"
                                )
                            )
                        ]
                    ),
                    finishReason: nil
                )
            ]
        )

        await collector.addChunk(toolCallChunk)

        let allChunks = await collector.getAllChunks()
        #expect(allChunks.count == 1)
        #expect(allChunks.first?.choices.first?.delta.toolCalls?.first?.function.name == "test_function")
    }

    @Test("Streaming mixed content and tool calls")
    func testStreamingMixedContentAndToolCalls() throws {
        let handler = StreamingHandler()

        // Content chunk first
        let contentChunk = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"role":"assistant","content":"Let me check the weather for you."},"finish_reason":null}]}
            """

        // Then tool call chunk
        let toolCallChunk = """
            data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_weather","type":"function","function":{"name":"get_weather","arguments":"{\\"city\\":\\"Tokyo\\"}"}}]},"finish_reason":null}]}
            """

        let contentResult = try handler.processStreamData(contentChunk.data(using: .utf8)!)
        let toolCallResult = try handler.processStreamData(toolCallChunk.data(using: .utf8)!)

        #expect(contentResult?.first?.choices.first?.delta.content == "Let me check the weather for you.")
        #expect(toolCallResult?.first?.choices.first?.delta.toolCalls?.first?.function.name == "get_weather")
    }
}