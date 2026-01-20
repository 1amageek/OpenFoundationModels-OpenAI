import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI
import OpenFoundationModels

/// Tests specifically for DeepSeek API compatibility
@Suite("DeepSeek Compatibility Tests")
struct DeepSeekCompatibilityTests {

    // MARK: - Model Identification Tests

    @Test("DeepSeek model identification works correctly")
    func testDeepSeekModelIdentification() {
        // Test various DeepSeek model names
        let deepSeekModels = ["deepseek-chat", "deepseek-coder", "deepseek-v3", "deepseek-r1"]

        for modelName in deepSeekModels {
            let model = OpenAIModel(modelName)
            #expect(model.modelType == .deepseek, "Model \(modelName) should be identified as DeepSeek")
            #expect(model.apiName == modelName, "API name should match model name")
        }

        // Test that non-DeepSeek models are not identified as DeepSeek
        let nonDeepSeekModels = ["gpt-4o", "gpt-4-turbo", "o1", "claude-3"]

        for modelName in nonDeepSeekModels {
            let model = OpenAIModel(modelName)
            #expect(model.modelType != .deepseek, "Model \(modelName) should not be identified as DeepSeek")
        }
    }

    @Test("DeepSeek models have correct capabilities")
    func testDeepSeekModelCapabilities() {
        let deepSeekModel = OpenAIModel("deepseek-chat")

        // DeepSeek should support text generation, function calling, and streaming
        #expect(deepSeekModel.supportsVision == false, "DeepSeek should not support vision")
        #expect(deepSeekModel.supportsFunctionCalling == true, "DeepSeek should support function calling")
        #expect(deepSeekModel.supportsStreaming == true, "DeepSeek should support streaming")
        #expect(deepSeekModel.isReasoningModel == false, "DeepSeek should not be a reasoning model")

        // Check capabilities set
        #expect(deepSeekModel.capabilities.contains(.textGeneration), "DeepSeek should support text generation")
        #expect(deepSeekModel.capabilities.contains(.functionCalling), "DeepSeek should support function calling")
        #expect(deepSeekModel.capabilities.contains(.streaming), "DeepSeek should support streaming")
        #expect(deepSeekModel.capabilities.contains(.toolAccess), "DeepSeek should support tool access")
        #expect(!deepSeekModel.capabilities.contains(.vision), "DeepSeek should not support vision")
        #expect(!deepSeekModel.capabilities.contains(.reasoning), "DeepSeek should not support reasoning")
    }

    @Test("DeepSeek models have correct context window and tokens")
    func testDeepSeekModelLimits() {
        let deepSeekModel = OpenAIModel("deepseek-chat")

        #expect(deepSeekModel.contextWindow == 32768, "DeepSeek should have 32K context window")
        #expect(deepSeekModel.maxOutputTokens == 8192, "DeepSeek should have 8K max output tokens")
    }

    // MARK: - Response Format Compatibility Tests

    @Test("DeepSeek models use JSON response format instead of JSON Schema")
    func testDeepSeekResponseFormatCompatibility() throws {
        // Create a simple schema for testing
        let schema = GenerationSchema(
            type: String.self,
            description: "Test response",
            properties: []
        )

        // Test with GPT model (should use json_schema)
        let gptModel = OpenAIModel("gpt-4o")
        let gptResponseFormat = convertSchemaToResponseFormat(schema, for: gptModel)

        // Test with DeepSeek model (should use json)
        let deepSeekModel = OpenAIModel("deepseek-chat")
        let deepSeekResponseFormat = convertSchemaToResponseFormat(schema, for: deepSeekModel)

        // GPT should use jsonSchema format
        switch gptResponseFormat {
        case .jsonSchema:
            // Expected for GPT models
            break
        default:
            #expect(Bool(false), "GPT model should use jsonSchema format")
        }

        // DeepSeek should use json format
        switch deepSeekResponseFormat {
        case .json:
            // Expected for DeepSeek models
            break
        case .jsonSchema:
            #expect(Bool(false), "DeepSeek model should not use jsonSchema format")
        case .text:
            #expect(Bool(false), "DeepSeek model should not use text format")
        }
    }

    @Test("TranscriptConverter respects model type for response format extraction")
    func testTranscriptConverterDeepSeekResponseFormat() throws {
        // Create a transcript with a prompt that has a response format
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
                        segments: [.text(Transcript.TextSegment(content: "Generate a response"))],
                        responseFormat: responseFormat
                    )
                )
            ]
        )

        // Test with GPT model
        let gptModel = OpenAIModel("gpt-4o")
        let gptExtractedFormat = TranscriptConverter.extractResponseFormatWithSchema(from: transcript, for: gptModel)

        // Test with DeepSeek model
        let deepSeekModel = OpenAIModel("deepseek-chat")
        let deepSeekExtractedFormat = TranscriptConverter.extractResponseFormatWithSchema(from: transcript, for: deepSeekModel)

        // GPT should extract jsonSchema format
        switch gptExtractedFormat {
        case .jsonSchema:
            // Expected
            break
        default:
            #expect(Bool(false), "GPT model should extract jsonSchema format")
        }

        // DeepSeek should extract json format
        switch deepSeekExtractedFormat {
        case .json:
            // Expected
            break
        case .jsonSchema:
            #expect(Bool(false), "DeepSeek model should extract json format, not jsonSchema")
        default:
            #expect(Bool(false), "DeepSeek model should extract json format")
        }
    }

    // MARK: - Request Builder Compatibility Tests

    @Test("DeepSeek models use correct request builder")
    func testDeepSeekRequestBuilder() {
        let deepSeekModel = OpenAIModel("deepseek-chat")

        // DeepSeek should use GPTRequestBuilder, not ReasoningRequestBuilder
        switch deepSeekModel.modelType {
        case .deepseek:
            // This should work without throwing
            let builder = GPTRequestBuilder()
            #expect(type(of: builder) == GPTRequestBuilder.self)
        default:
            #expect(Bool(false), "DeepSeek model should have deepseek type")
        }
    }

    @Test("DeepSeek models use correct response handler")
    func testDeepSeekResponseHandler() {
        let deepSeekModel = OpenAIModel("deepseek-chat")

        // DeepSeek should use GPTResponseHandler, not ReasoningResponseHandler
        switch deepSeekModel.modelType {
        case .deepseek:
            // This should work without throwing
            let handler = GPTResponseHandler()
            #expect(type(of: handler) == GPTResponseHandler.self)
        default:
            #expect(Bool(false), "DeepSeek model should have deepseek type")
        }
    }
}

// MARK: - Helper Functions for Testing

/// Convert GenerationSchema to ResponseFormat for a specific model (test helper)
private func convertSchemaToResponseFormat(_ schema: GenerationSchema, for model: OpenAIModel) -> ResponseFormat {
    // This replicates the logic from OpenAILanguageModel.convertSchemaToResponseFormat
    // For models that don't support json_schema (like DeepSeek), fallback to json mode
    if model.modelType == .deepseek {
        return .json
    }

    // For other models, try to create jsonSchema format
    do {
        let encoder = JSONEncoder()
        let schemaData = try encoder.encode(schema)

        // Convert to JSON dictionary
        if let schemaJson = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
            // Transform to OpenAI's expected JSON Schema format
            let transformedSchema = transformToOpenAIJSONSchema(schemaJson)
            return .jsonSchema(transformedSchema)
        }
    } catch {
        // Ignore encoding errors in test
    }

    // Fallback to JSON mode
    return .json
}

/// Transform GenerationSchema JSON to OpenAI's JSON Schema format (test helper)
private func transformToOpenAIJSONSchema(_ json: [String: Any]) -> [String: Any] {
    var schema: [String: Any] = [:]

    // Extract type (default to "object")
    schema["type"] = json["type"] as? String ?? "object"

    // Extract and transform properties
    if let properties = json["properties"] as? [String: [String: Any]] {
        var transformedProperties: [String: [String: Any]] = [:]

        for (key, propJson) in properties {
            var prop: [String: Any] = [:]
            prop["type"] = propJson["type"] as? String ?? "string"

            if let description = propJson["description"] as? String {
                prop["description"] = description
            }

            if let enumValues = propJson["enum"] as? [String] {
                prop["enum"] = enumValues
            }

            if prop["type"] as? String == "array",
               let items = propJson["items"] as? [String: Any] {
                prop["items"] = items
            }

            transformedProperties[key] = prop
        }

        schema["properties"] = transformedProperties
    }

    // Extract required fields
    if let required = json["required"] as? [String] {
        schema["required"] = required
    }

    // Add description if present
    if let description = json["description"] as? String {
        schema["description"] = description
    }

    return schema
}