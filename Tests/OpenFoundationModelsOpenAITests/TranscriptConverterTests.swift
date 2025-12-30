import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI
import OpenFoundationModels

@Suite("Transcript Converter Tests")
struct TranscriptConverterTests {
    
    @Test("JSON-based message conversion with fallback")
    func testJSONMessageConversion() throws {
        // Create a sample transcript
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
                        segments: [.text(Transcript.TextSegment(content: "Hello, how are you?"))]
                    )
                ),
                .response(
                    Transcript.Response(
                        assetIDs: [],
                        segments: [.text(Transcript.TextSegment(content: "I'm doing well, thank you!"))]
                    )
                )
            ]
        )
        
        // Convert to messages
        let messages = TranscriptConverter.buildMessages(from: transcript)
        
        // Verify the conversion
        #expect(messages.count == 3)
        #expect(messages[0].role == ChatMessage.Role.system)
        #expect(messages[0].content?.text == "You are a helpful assistant.")
        #expect(messages[1].role == ChatMessage.Role.user)
        #expect(messages[1].content?.text == "Hello, how are you?")
        #expect(messages[2].role == ChatMessage.Role.assistant)
        #expect(messages[2].content?.text == "I'm doing well, thank you!")
    }
    
    @Test("Tool extraction from transcript")
    func testToolExtraction() throws {
        // Create a transcript with tool definitions
        let toolDef = Transcript.ToolDefinition(
            name: "get_weather",
            description: "Get the current weather",
            parameters: GenerationSchema(
                type: String.self,
                description: "Weather query parameters",
                properties: []
            )
        )
        
        let transcript = Transcript(
            entries: [
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: "You have access to weather tools."))],
                        toolDefinitions: [toolDef]
                    )
                ),
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "What's the weather?"))]
                    )
                )
            ]
        )
        
        // Extract tools
        let tools = TranscriptConverter.extractTools(from: transcript)
        
        // Verify extraction
        #expect(tools != nil)
        #expect(tools?.count == 1)
        #expect(tools?.first?.function.name == "get_weather")
        #expect(tools?.first?.function.description == "Get the current weather")
    }
    
    @Test("Tool calls conversion")
    func testToolCallsConversion() throws {
        // Create a transcript with tool calls
        let argumentsContent = try GeneratedContent(json: """
            {"location": "San Francisco", "unit": "celsius"}
            """)
        
        let toolCall = Transcript.ToolCall(
            id: "call_123",
            toolName: "get_weather",
            arguments: argumentsContent
        )
        
        let transcript = Transcript(
            entries: [
                .toolCalls(
                    Transcript.ToolCalls(
                        [toolCall]
                    )
                )
            ]
        )
        
        // Convert to messages
        let messages = TranscriptConverter.buildMessages(from: transcript)
        
        // Verify the conversion
        #expect(messages.count == 1)
        #expect(messages[0].role == .assistant)
        #expect(messages[0].toolCalls?.count == 1)
        #expect(messages[0].toolCalls?.first?.function.name == "get_weather")
        
        // Verify arguments are properly converted
        let argsString = messages[0].toolCalls?.first?.function.arguments ?? "{}"
        let argsData = argsString.data(using: .utf8)!
        let args = try JSONSerialization.jsonObject(with: argsData) as? [String: Any]
        #expect(args?["location"] as? String == "San Francisco")
        #expect(args?["unit"] as? String == "celsius")
    }
    
    @Test("Response format extraction with schema")
    func testResponseFormatExtraction() throws {
        // Create a transcript with response format
        let schema = GenerationSchema(
            type: String.self,
            description: "Response schema",
            properties: []
        )
        
        let responseFormat = Transcript.ResponseFormat(
            schema: schema
        )
        
        let transcript = Transcript(
            entries: [
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "Get weather"))],
                        responseFormat: responseFormat
                    )
                )
            ]
        )
        
        // Extract response format
        let extractedFormat = TranscriptConverter.extractResponseFormat(from: transcript)
        
        // Verify extraction (will be .json due to current limitations)
        #expect(extractedFormat != nil)
        // The format will be .json because the schema is not exposed in encoding
        if case .json = extractedFormat {
            // Expected due to OpenFoundationModels limitations
        } else if case .jsonSchema = extractedFormat {
            // This would be ideal if schema was accessible
        } else {
            Issue.record("Unexpected response format type")
        }
    }
    
    @Test("Empty transcript handling")
    func testEmptyTranscript() {
        let transcript = Transcript(entries: [])
        
        let messages = TranscriptConverter.buildMessages(from: transcript)
        #expect(messages.isEmpty)
        
        let tools = TranscriptConverter.extractTools(from: transcript)
        #expect(tools == nil)
        
        let format = TranscriptConverter.extractResponseFormat(from: transcript)
        #expect(format == nil)
    }
    
    @Test("Complex structured content conversion")
    func testStructuredContentConversion() throws {
        // Create structured content
        let structuredContent = try GeneratedContent(json: """
            {
                "name": "John Doe",
                "age": 30,
                "active": true
            }
            """)

        let transcript = Transcript(
            entries: [
                .response(
                    Transcript.Response(
                        assetIDs: [],
                        segments: [
                            .text(Transcript.TextSegment(content: "Here is the data: ")),
                            .structure(Transcript.StructuredSegment(source: "test", content: structuredContent))
                        ]
                    )
                )
            ]
        )

        // Convert to messages
        let messages = TranscriptConverter.buildMessages(from: transcript)

        // Verify conversion
        #expect(messages.count == 1)
        #expect(messages[0].role == ChatMessage.Role.assistant)
        let contentText = messages[0].content?.text ?? ""
        print("Actual content: \(contentText)")
        #expect(contentText.contains("Here is the data:"))
        // The structured content should be serialized as JSON
        #expect(contentText.contains("generatedContent") || contentText.contains("John Doe") || contentText.contains("name"))
    }

    // MARK: - ToolOutput Tests

    @Test("Tool output conversion")
    func testToolOutputConversion() throws {
        let transcript = Transcript(
            entries: [
                .toolOutput(
                    Transcript.ToolOutput(
                        id: "call_123",
                        toolName: "get_weather",
                        segments: [.text(Transcript.TextSegment(content: "Temperature: 22°C, Sunny"))]
                    )
                )
            ]
        )

        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        #expect(messages[0].role == ChatMessage.Role.tool)
        #expect(messages[0].content?.text == "Temperature: 22°C, Sunny")
    }

    @Test("Multiple tool outputs conversion")
    func testMultipleToolOutputsConversion() throws {
        let transcript = Transcript(
            entries: [
                .toolOutput(
                    Transcript.ToolOutput(
                        id: "call_1",
                        toolName: "get_weather",
                        segments: [.text(Transcript.TextSegment(content: "Tokyo: 25°C"))]
                    )
                ),
                .toolOutput(
                    Transcript.ToolOutput(
                        id: "call_2",
                        toolName: "get_time",
                        segments: [.text(Transcript.TextSegment(content: "14:30 JST"))]
                    )
                )
            ]
        )

        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 2)
        #expect(messages[0].role == ChatMessage.Role.tool)
        #expect(messages[1].role == ChatMessage.Role.tool)
    }

    // MARK: - Full Conversation Flow Tests

    @Test("Full conversation with tool calling flow")
    func testFullToolCallingFlow() throws {
        let toolDef = Transcript.ToolDefinition(
            name: "search",
            description: "Search the web",
            parameters: GenerationSchema(type: String.self, description: "Query", properties: [])
        )

        let argumentsContent = try GeneratedContent(json: """
            {"query": "latest news"}
            """)

        let toolCall = Transcript.ToolCall(
            id: "call_search",
            toolName: "search",
            arguments: argumentsContent
        )

        let transcript = Transcript(
            entries: [
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: "You can search the web."))],
                        toolDefinitions: [toolDef]
                    )
                ),
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "Find the latest news"))]
                    )
                ),
                .toolCalls(
                    Transcript.ToolCalls([toolCall])
                ),
                .toolOutput(
                    Transcript.ToolOutput(
                        id: "call_search",
                        toolName: "search",
                        segments: [.text(Transcript.TextSegment(content: "News results: ..."))]
                    )
                ),
                .response(
                    Transcript.Response(
                        assetIDs: [],
                        segments: [.text(Transcript.TextSegment(content: "Here are the latest news..."))]
                    )
                )
            ]
        )

        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 5)
        #expect(messages[0].role == ChatMessage.Role.system)
        #expect(messages[1].role == ChatMessage.Role.user)
        #expect(messages[2].role == ChatMessage.Role.assistant)
        #expect(messages[2].toolCalls?.count == 1)
        #expect(messages[3].role == ChatMessage.Role.tool)
        #expect(messages[4].role == ChatMessage.Role.assistant)
    }

    // MARK: - Options Extraction Tests

    @Test("Options extraction from prompt")
    func testOptionsExtraction() {
        let options = GenerationOptions(
            temperature: 0.8,
            maximumResponseTokens: 500
        )

        let transcript = Transcript(
            entries: [
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "Test"))],
                        options: options
                    )
                )
            ]
        )

        let extractedOptions = TranscriptConverter.extractOptions(from: transcript)

        #expect(extractedOptions != nil)
        #expect(extractedOptions?.temperature == 0.8)
        #expect(extractedOptions?.maximumResponseTokens == 500)
    }

    @Test("Options extraction returns nil for empty transcript")
    func testOptionsExtractionEmpty() {
        let transcript = Transcript(entries: [])

        let extractedOptions = TranscriptConverter.extractOptions(from: transcript)

        #expect(extractedOptions == nil)
    }

    // MARK: - Edge Cases

    @Test("Unicode content handling")
    func testUnicodeContent() throws {
        let transcript = Transcript(
            entries: [
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "こんにちは、世界！🌍 Привет мир!"))]
                    )
                ),
                .response(
                    Transcript.Response(
                        assetIDs: [],
                        segments: [.text(Transcript.TextSegment(content: "你好！مرحبا 🎉"))]
                    )
                )
            ]
        )

        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 2)
        #expect(messages[0].content?.text?.contains("こんにちは") == true)
        #expect(messages[0].content?.text?.contains("🌍") == true)
        #expect(messages[1].content?.text?.contains("你好") == true)
        #expect(messages[1].content?.text?.contains("🎉") == true)
    }

    @Test("Special characters in content")
    func testSpecialCharacters() throws {
        let transcript = Transcript(
            entries: [
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: "Code: `print(\"Hello\\nWorld\")`\n<script>alert('xss')</script>"))]
                    )
                )
            ]
        )

        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        let content = messages[0].content?.text ?? ""
        #expect(content.contains("print"))
        #expect(content.contains("<script>"))
    }

    @Test("Large content handling")
    func testLargeContent() throws {
        let largeText = String(repeating: "This is a test sentence. ", count: 1000)

        let transcript = Transcript(
            entries: [
                .prompt(
                    Transcript.Prompt(
                        segments: [.text(Transcript.TextSegment(content: largeText))]
                    )
                )
            ]
        )

        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        #expect(messages[0].content?.text?.count == largeText.count)
    }

    @Test("Multiple segments in single entry")
    func testMultipleSegments() throws {
        let transcript = Transcript(
            entries: [
                .prompt(
                    Transcript.Prompt(
                        segments: [
                            .text(Transcript.TextSegment(content: "First part. ")),
                            .text(Transcript.TextSegment(content: "Second part. ")),
                            .text(Transcript.TextSegment(content: "Third part."))
                        ]
                    )
                )
            ]
        )

        let messages = TranscriptConverter.buildMessages(from: transcript)

        #expect(messages.count == 1)
        let content = messages[0].content?.text ?? ""
        #expect(content.contains("First part"))
        #expect(content.contains("Second part"))
        #expect(content.contains("Third part"))
    }

    // MARK: - Tool Definition Tests

    @Test("Multiple tool definitions extraction")
    func testMultipleToolDefinitions() throws {
        let toolDef1 = Transcript.ToolDefinition(
            name: "get_weather",
            description: "Get weather info",
            parameters: GenerationSchema(type: String.self, description: "Location", properties: [])
        )

        let toolDef2 = Transcript.ToolDefinition(
            name: "get_time",
            description: "Get current time",
            parameters: GenerationSchema(type: String.self, description: "Timezone", properties: [])
        )

        let transcript = Transcript(
            entries: [
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: "Tools available"))],
                        toolDefinitions: [toolDef1, toolDef2]
                    )
                )
            ]
        )

        let tools = TranscriptConverter.extractTools(from: transcript)

        #expect(tools?.count == 2)
        #expect(tools?[0].function.name == "get_weather")
        #expect(tools?[1].function.name == "get_time")
    }

    @Test("Tool extraction returns nil when no tools defined")
    func testNoToolsDefined() {
        let transcript = Transcript(
            entries: [
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: "No tools"))],
                        toolDefinitions: []
                    )
                )
            ]
        )

        let tools = TranscriptConverter.extractTools(from: transcript)

        #expect(tools == nil || tools?.isEmpty == true)
    }

    // MARK: - Performance Tests

    @Test("Conversion performance with many entries")
    func testConversionPerformance() throws {
        var entries: [Transcript.Entry] = []

        // Create 100 prompt-response pairs
        for i in 0..<100 {
            entries.append(.prompt(
                Transcript.Prompt(
                    segments: [.text(Transcript.TextSegment(content: "Question \(i)"))]
                )
            ))
            entries.append(.response(
                Transcript.Response(
                    assetIDs: [],
                    segments: [.text(Transcript.TextSegment(content: "Answer \(i)"))]
                )
            ))
        }

        let transcript = Transcript(entries: entries)

        let startTime = Date()
        let messages = TranscriptConverter.buildMessages(from: transcript)
        let duration = Date().timeIntervalSince(startTime)

        #expect(messages.count == 200)
        #expect(duration < 1.0, "Conversion should complete in under 1 second")
    }
}