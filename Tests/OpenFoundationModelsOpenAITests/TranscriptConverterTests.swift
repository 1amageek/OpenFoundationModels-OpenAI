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
}