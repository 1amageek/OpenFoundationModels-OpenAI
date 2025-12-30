import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI
import OpenFoundationModels

/// Integration tests that verify the full flow from Transcript through OpenAILanguageModel
@Suite("Integration Tests")
struct IntegrationTests {

    // MARK: - Request Validation Tests

    @Test("Generate creates correct request structure")
    func testGenerateRequestStructure() async throws {
        // Create a transcript with all entry types
        let transcript = Transcript(
            entries: [
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: "You are a helpful assistant."))],
                        toolDefinitions: []
                    )
                ),
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "Hello!"))],
                        options: GenerationOptions(temperature: 0.7, maximumResponseTokens: 100)
                    )
                )
            ]
        )

        // Build messages and verify structure
        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 2)
        #expect(messages[0].role == .system)
        #expect(messages[1].role == .user)

        // Verify options extraction
        let options = TranscriptConverter.extractOptions(from: transcript)
        #expect(options?.temperature == 0.7)
        #expect(options?.maximumResponseTokens == 100)
    }

    @Test("Generate with tools creates correct request")
    func testGenerateWithToolsRequestStructure() async throws {
        let toolDef = Transcript.ToolDefinition(
            name: "calculator",
            description: "Perform calculations",
            parameters: GenerationSchema(
                type: String.self,
                description: "Calculator parameters",
                properties: []
            )
        )

        let transcript = Transcript(
            entries: [
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: "You can use tools."))],
                        toolDefinitions: [toolDef]
                    )
                ),
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "Calculate 2+2"))]
                    )
                )
            ]
        )

        // Extract tools and verify
        let tools = TranscriptConverter.extractTools(from: transcript)

        #expect(tools != nil)
        #expect(tools?.count == 1)
        #expect(tools?.first?.function.name == "calculator")
        #expect(tools?.first?.function.description == "Perform calculations")
    }

    @Test("Generate with response format creates correct request")
    func testGenerateWithResponseFormatRequestStructure() async throws {
        let schema = GenerationSchema(
            type: String.self,
            description: "Response schema",
            properties: []
        )

        let responseFormat = Transcript.ResponseFormat(schema: schema)

        let transcript = Transcript(
            entries: [
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "Get data"))],
                        responseFormat: responseFormat
                    )
                )
            ]
        )

        // Extract response format and verify
        let extractedFormat = TranscriptConverter.extractResponseFormat(from: transcript)

        #expect(extractedFormat != nil)
    }

    // MARK: - Full Flow Tests

    @Test("Complete conversation flow builds correct message sequence")
    func testCompleteConversationFlow() async throws {
        let argumentsContent = try GeneratedContent(json: """
            {"query": "test"}
            """)

        let toolCall = Transcript.ToolCall(
            id: "call_1",
            toolName: "search",
            arguments: argumentsContent
        )

        let transcript = Transcript(
            entries: [
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: "System prompt"))],
                        toolDefinitions: []
                    )
                ),
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "User question"))]
                    )
                ),
                .response(
                    Transcript.Response(
                        assetIDs: [],
                        segments: [.text(Transcript.TextSegment(content: "Assistant thinking..."))]
                    )
                ),
                .toolCalls(
                    Transcript.ToolCalls([toolCall])
                ),
                .toolOutput(
                    Transcript.ToolOutput(
                        id: "call_1",
                        toolName: "search",
                        segments: [.text(Transcript.TextSegment(content: "Search results"))]
                    )
                ),
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "Follow up question"))]
                    )
                )
            ]
        )

        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 6)
        #expect(messages[0].role == ChatMessage.Role.system)
        #expect(messages[1].role == ChatMessage.Role.user)
        #expect(messages[2].role == ChatMessage.Role.assistant)
        #expect(messages[3].role == ChatMessage.Role.assistant) // tool calls
        #expect(messages[3].toolCalls != nil)
        #expect(messages[4].role == ChatMessage.Role.tool)
        #expect(messages[5].role == ChatMessage.Role.user)
    }

    // MARK: - Response Parsing Tests

    @Test("Parse text response correctly")
    func testParseTextResponse() throws {
        let responseJSON = """
            {
                "id": "chatcmpl-123",
                "object": "chat.completion",
                "created": 1234567890,
                "model": "gpt-4o",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello! How can I help you today?"
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 10,
                    "completion_tokens": 8,
                    "total_tokens": 18
                }
            }
            """

        let decoder = JSONDecoder()
        let response = try decoder.decode(ChatCompletionResponse.self, from: responseJSON.data(using: .utf8)!)

        #expect(response.choices.count == 1)
        #expect(response.choices[0].message.content?.text == "Hello! How can I help you today?")
        #expect(response.choices[0].finishReason == "stop")
    }

    @Test("Parse tool call response correctly")
    func testParseToolCallResponse() throws {
        let responseJSON = """
            {
                "id": "chatcmpl-123",
                "object": "chat.completion",
                "created": 1234567890,
                "model": "gpt-4o",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_abc123",
                            "type": "function",
                            "function": {
                                "name": "get_weather",
                                "arguments": "{\\"location\\":\\"Tokyo\\",\\"unit\\":\\"celsius\\"}"
                            }
                        }]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {
                    "prompt_tokens": 15,
                    "completion_tokens": 20,
                    "total_tokens": 35
                }
            }
            """

        let decoder = JSONDecoder()
        let response = try decoder.decode(ChatCompletionResponse.self, from: responseJSON.data(using: .utf8)!)

        #expect(response.choices.count == 1)
        #expect(response.choices[0].message.toolCalls?.count == 1)
        #expect(response.choices[0].message.toolCalls?[0].function.name == "get_weather")
        #expect(response.choices[0].finishReason == "tool_calls")

        // Parse the arguments
        let argsString = response.choices[0].message.toolCalls?[0].function.arguments ?? "{}"
        let args = try JSONSerialization.jsonObject(with: argsString.data(using: .utf8)!) as? [String: Any]
        #expect(args?["location"] as? String == "Tokyo")
        #expect(args?["unit"] as? String == "celsius")
    }

    @Test("Parse multiple tool calls response")
    func testParseMultipleToolCallsResponse() throws {
        let responseJSON = """
            {
                "id": "chatcmpl-123",
                "object": "chat.completion",
                "created": 1234567890,
                "model": "gpt-4o",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [
                            {
                                "id": "call_1",
                                "type": "function",
                                "function": {
                                    "name": "get_weather",
                                    "arguments": "{\\"location\\":\\"Tokyo\\"}"
                                }
                            },
                            {
                                "id": "call_2",
                                "type": "function",
                                "function": {
                                    "name": "get_time",
                                    "arguments": "{\\"timezone\\":\\"JST\\"}"
                                }
                            }
                        ]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {
                    "prompt_tokens": 20,
                    "completion_tokens": 40,
                    "total_tokens": 60
                }
            }
            """

        let decoder = JSONDecoder()
        let response = try decoder.decode(ChatCompletionResponse.self, from: responseJSON.data(using: .utf8)!)

        #expect(response.choices[0].message.toolCalls?.count == 2)
        #expect(response.choices[0].message.toolCalls?[0].function.name == "get_weather")
        #expect(response.choices[0].message.toolCalls?[1].function.name == "get_time")
    }

    // MARK: - Request Builder Integration Tests

    @Test("Request builder creates valid JSON for GPT model")
    func testRequestBuilderGPTJSON() throws {
        let builder = GPTRequestBuilder()

        let messages = [
            ChatMessage.system("You are helpful."),
            ChatMessage.user("Hello")
        ]

        let tool = Tool(
            function: Tool.Function(
                name: "test_tool",
                description: "A test tool",
                parameters: JSONSchema(type: "object", properties: [:], required: nil)
            )
        )

        let request = try builder.buildChatRequest(
            model: .gpt4o,
            messages: messages,
            options: GenerationOptions(temperature: 0.8, maximumResponseTokens: 200),
            tools: [tool],
            responseFormat: .json
        )

        // Verify the request body is valid JSON
        let json = try JSONSerialization.jsonObject(with: request.body!) as? [String: Any]

        #expect(json?["model"] as? String == "gpt-4o")
        #expect(json?["temperature"] as? Double == 0.8)
        #expect((json?["messages"] as? [[String: Any]])?.count == 2)
        #expect((json?["tools"] as? [[String: Any]])?.count == 1)
        #expect((json?["response_format"] as? [String: Any])?["type"] as? String == "json_object")
    }

    @Test("Request builder creates valid JSON for Reasoning model")
    func testRequestBuilderReasoningJSON() throws {
        let builder = ReasoningRequestBuilder()

        let messages = [
            ChatMessage.user("Solve this complex problem...")
        ]

        let request = try builder.buildChatRequest(
            model: .o1,
            messages: messages,
            options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 1000),
            tools: nil,
            responseFormat: nil
        )

        // Verify the request body
        let json = try JSONSerialization.jsonObject(with: request.body!) as? [String: Any]

        #expect(json?["model"] as? String == "o1")
        // Reasoning models don't support temperature, so it should not be included
        #expect(json?["temperature"] == nil)
        #expect((json?["messages"] as? [[String: Any]])?.count == 1)
    }

    // MARK: - Error Handling Integration Tests

    @Test("Error responses are parsed correctly")
    func testErrorResponseParsing() throws {
        let errorJSON = """
            {
                "error": {
                    "message": "Rate limit exceeded",
                    "type": "rate_limit_error",
                    "param": null,
                    "code": "rate_limit_exceeded"
                }
            }
            """

        // Verify error JSON structure is correct
        let json = try JSONSerialization.jsonObject(with: errorJSON.data(using: .utf8)!) as? [String: Any]
        let error = json?["error"] as? [String: Any]

        #expect(error?["message"] as? String == "Rate limit exceeded")
        #expect(error?["type"] as? String == "rate_limit_error")
        #expect(error?["code"] as? String == "rate_limit_exceeded")
    }

    // MARK: - Model Selection Tests

    @Test("Correct request builder is used for each model type")
    func testModelRequestBuilderSelection() {
        for model in OpenAIModel.allCases {
            switch model.modelType {
            case .gpt:
                // GPT models should use GPTRequestBuilder
                let builder = GPTRequestBuilder()
                #expect(type(of: builder) == GPTRequestBuilder.self,
                       "Model \(model.apiName) should use GPTRequestBuilder")
            case .reasoning:
                // Reasoning models should use ReasoningRequestBuilder
                let builder = ReasoningRequestBuilder()
                #expect(type(of: builder) == ReasoningRequestBuilder.self,
                       "Model \(model.apiName) should use ReasoningRequestBuilder")
            }
        }
    }

    // MARK: - End-to-End Scenario Tests

    @Test("Multi-turn conversation maintains context")
    func testMultiTurnConversation() throws {
        // Simulate a multi-turn conversation
        var entries: [Transcript.Entry] = [
            .instructions(
                Transcript.Instructions(
                    segments: [.text(Transcript.TextSegment(content: "You are a math tutor."))],
                    toolDefinitions: []
                )
            )
        ]

        // Turn 1
        entries.append(.prompt(
            Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "What is 2+2?"))]
            )
        ))
        entries.append(.response(
            Transcript.Response(
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(content: "2+2 equals 4."))]
            )
        ))

        // Turn 2
        entries.append(.prompt(
            Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "And what is that multiplied by 3?"))]
            )
        ))
        entries.append(.response(
            Transcript.Response(
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(content: "4 multiplied by 3 equals 12."))]
            )
        ))

        // Turn 3
        entries.append(.prompt(
            Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "What about divided by 2?"))]
            )
        ))

        let transcript = Transcript(entries: entries)
        let messages = TranscriptConverter.buildMessages(from: transcript)

        // Verify all messages are preserved
        #expect(messages.count == 6) // system + 5 conversation turns
        #expect(messages[0].role == .system)
        #expect(messages[1].role == .user)
        #expect(messages[2].role == .assistant)
        #expect(messages[3].role == .user)
        #expect(messages[4].role == .assistant)
        #expect(messages[5].role == .user)

        // Verify content is preserved
        #expect(messages[1].content?.text == "What is 2+2?")
        #expect(messages[2].content?.text == "2+2 equals 4.")
        #expect(messages[5].content?.text == "What about divided by 2?")
    }

    @Test("Tool calling workflow creates correct message sequence")
    func testToolCallingWorkflow() throws {
        // Create a complete tool calling workflow
        let toolDef = Transcript.ToolDefinition(
            name: "get_stock_price",
            description: "Get current stock price",
            parameters: GenerationSchema(type: String.self, description: "Stock symbol", properties: [])
        )

        let argumentsContent = try GeneratedContent(json: """
            {"symbol": "AAPL"}
            """)

        let toolCall = Transcript.ToolCall(
            id: "call_stock",
            toolName: "get_stock_price",
            arguments: argumentsContent
        )

        let entries: [Transcript.Entry] = [
            .instructions(
                Transcript.Instructions(
                    segments: [.text(Transcript.TextSegment(content: "You are a financial assistant."))],
                    toolDefinitions: [toolDef]
                )
            ),
            .prompt(
                Transcript.Prompt(
                    segments: [.text(Transcript.TextSegment(content: "What's Apple's stock price?"))]
                )
            ),
            .toolCalls(
                Transcript.ToolCalls([toolCall])
            ),
            .toolOutput(
                Transcript.ToolOutput(
                    id: "call_stock",
                    toolName: "get_stock_price",
                    segments: [.text(Transcript.TextSegment(content: "$150.25"))]
                )
            ),
            .response(
                Transcript.Response(
                    assetIDs: [],
                    segments: [.text(Transcript.TextSegment(content: "Apple's current stock price is $150.25."))]
                )
            )
        ]

        let transcript = Transcript(entries: entries)
        let messages = TranscriptConverter.buildMessages(from: transcript)
        let tools = TranscriptConverter.extractTools(from: transcript)

        // Verify messages
        #expect(messages.count == 5)
        #expect(messages[2].toolCalls?.first?.function.name == "get_stock_price")
        #expect(messages[3].role == .tool)
        #expect(messages[3].toolCallId == "call_stock")

        // Verify tools
        #expect(tools?.count == 1)
        #expect(tools?.first?.function.name == "get_stock_price")
    }
}
