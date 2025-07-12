import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI
@testable import OpenFoundationModels

@Suite("OpenAI Language Model Core Tests")
struct OpenAILanguageModelTests {
    
    // MARK: - Test Configuration
    
    private static let testConfiguration = OpenAIConfiguration(
        apiKey: "sk-test-key-12345",
        baseURL: URL(string: "https://api.openai.com/v1")!,
        organization: nil
    )
    
    // MARK: - Initialization Tests
    
    @Test("Model initialization with valid configuration")
    func testModelInitialization() {
        let model = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        #expect(model.isAvailable == true, "Model should be available after initialization")
    }
    
    @Test("Model initialization with different models", arguments: [
        OpenAIModel.gpt4o,
        OpenAIModel.gpt4oMini,
        OpenAIModel.o4Mini,
        OpenAIModel.o3,
        OpenAIModel.o1,
        OpenAIModel.o1Pro
    ])
    func testModelInitializationWithDifferentModels(model: OpenAIModel) {
        let languageModel = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: model
        )
        
        #expect(languageModel.isAvailable == true, "Model \(model.apiName) should be available")
        #expect(languageModel.modelInfo.name == model.apiName, "Model info should match initialized model")
    }
    
    // MARK: - LanguageModel Protocol Compliance Tests
    
    @Test("Supports locale functionality")
    func testLocaleSupport() {
        let model = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        // OpenAI models support most major languages
        #expect(model.supports(locale: Locale(identifier: "en_US")) == true, "Should support English")
        #expect(model.supports(locale: Locale(identifier: "ja_JP")) == true, "Should support Japanese")
        #expect(model.supports(locale: Locale(identifier: "fr_FR")) == true, "Should support French")
        #expect(model.supports(locale: Locale(identifier: "es_ES")) == true, "Should support Spanish")
    }
    
    @Test("IsAvailable property is synchronous")
    func testIsAvailableProperty() {
        let model = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        // This test verifies that isAvailable is a synchronous property
        // If this compiles and runs, the property is correctly implemented as sync
        let available = model.isAvailable
        #expect(available == true, "Model should be available")
    }
    
    // MARK: - Model Information Tests
    
    @Test("Model info provides correct capabilities")
    func testModelInfoCapabilities() {
        let gptModel = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        let gptInfo = gptModel.modelInfo
        #expect(gptInfo.name == "gpt-4o", "GPT model name should be correct")
        #expect(gptInfo.supportsVision == true, "GPT-4o should support vision")
        #expect(gptInfo.supportsFunctionCalling == true, "GPT-4o should support function calling")
        #expect(gptInfo.isReasoningModel == false, "GPT-4o is not a reasoning model")
        
        let reasoningModel = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .o4Mini
        )
        
        let reasoningInfo = reasoningModel.modelInfo
        #expect(reasoningInfo.name == "o4-mini", "Reasoning model name should be correct")
        #expect(reasoningInfo.isReasoningModel == true, "o4-mini is a reasoning model")
    }
    
    @Test("Model info includes correct token limits")
    func testModelTokenLimits() {
        let model = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        let info = model.modelInfo
        #expect(info.contextWindow > 0, "Context window should be positive")
        #expect(info.maxOutputTokens > 0, "Max output tokens should be positive")
        #expect(info.contextWindow >= info.maxOutputTokens, "Context window should be >= max output tokens")
    }
    
    // MARK: - Factory Method Tests
    
    @Test("Factory method creates model with API key")
    func testFactoryMethodWithAPIKey() {
        let model = OpenAILanguageModel.create(
            apiKey: "test-key",
            model: .gpt4o
        )
        
        #expect(model.isAvailable == true, "Factory-created model should be available")
        #expect(model.modelInfo.name == "gpt-4o", "Factory-created model should have correct name")
    }
    
    @Test("Convenience factory methods work correctly")
    func testConvenienceFactoryMethods() {
        let gpt4o = OpenAILanguageModel.gpt4o(apiKey: "test-key")
        #expect(gpt4o.modelInfo.name == "gpt-4o", "GPT-4o factory method should create correct model")
        
        let gpt4oMini = OpenAILanguageModel.gpt4oMini(apiKey: "test-key")
        #expect(gpt4oMini.modelInfo.name == "gpt-4o-mini", "GPT-4o Mini factory method should create correct model")
        
        let o3 = OpenAILanguageModel.o3(apiKey: "test-key")
        #expect(o3.modelInfo.name == "o3", "o3 factory method should create correct model")
        
        let o3Pro = OpenAILanguageModel.o3Pro(apiKey: "test-key")
        #expect(o3Pro.modelInfo.name == "o3-pro", "o3 Pro factory method should create correct model")
        
        let o4Mini = OpenAILanguageModel.o4Mini(apiKey: "test-key")
        #expect(o4Mini.modelInfo.name == "o4-mini", "o4 Mini factory method should create correct model")
    }
    
    // MARK: - Utility Method Tests
    
    @Test("Token estimation provides reasonable results")
    func testTokenEstimation() {
        let model = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        // Test various text lengths
        let shortText = "Hello"
        let mediumText = "This is a medium length text that should have more tokens."
        let longText = String(repeating: "This is a longer text. ", count: 20)
        
        let shortTokens = model.estimateTokenCount(shortText)
        let mediumTokens = model.estimateTokenCount(mediumText)
        let longTokens = model.estimateTokenCount(longText)
        
        #expect(shortTokens > 0, "Short text should have positive token count")
        #expect(mediumTokens > shortTokens, "Medium text should have more tokens than short")
        #expect(longTokens > mediumTokens, "Long text should have more tokens than medium")
        
        // Test empty string
        let emptyTokens = model.estimateTokenCount("")
        #expect(emptyTokens >= 1, "Empty string should have at least 1 token (minimum)")
    }
    
    @Test("Context length checking works correctly")
    func testContextLengthChecking() {
        let model = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        let shortText = "Hello world"
        // Create text that definitely exceeds context window (GPT-4o has 128k context)
        // Approximately 4 chars per token, so 150k * 4 = 600k chars should exceed 128k tokens
        let veryLongText = String(repeating: "This is a very long text with many words. ", count: 15000)
        
        #expect(model.wouldExceedContext(shortText) == false, "Short text should not exceed context")
        #expect(model.wouldExceedContext(veryLongText) == true, "Very long text should exceed context")
    }
    
    @Test("Text truncation preserves word boundaries")
    func testTextTruncation() {
        let model = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        // Create a longer text that will definitely get truncated
        let longText = String(repeating: "This is a test sentence that should be truncated properly at word boundaries. ", count: 100)
        
        // Reserve most of the context to force truncation
        let contextWindow = model.modelInfo.contextWindow
        let reserveTokens = contextWindow - 100 // Reserve almost all tokens
        
        let truncated = model.truncateToContext(longText, reserveTokens: reserveTokens)
        
        #expect(truncated.count < longText.count, "Truncated text should be shorter than original")
        #expect(!truncated.hasSuffix(" "), "Truncated text should not end with space")
        
        // Test with very short reserve tokens (should not truncate short text)
        let shortText = "This is a short text."
        let notTruncated = model.truncateToContext(shortText, reserveTokens: 10)
        #expect(notTruncated == shortText, "Short text should not be truncated when reserve is small")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Model handles invalid configuration gracefully")
    func testInvalidConfiguration() {
        // Test with empty API key
        let invalidConfig = OpenAIConfiguration(
            apiKey: "",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            organization: nil
        )
        
        let model = OpenAILanguageModel(
            configuration: invalidConfig,
            model: .gpt4o
        )
        
        // Model should still initialize (validation happens during API calls)
        #expect(model.isAvailable == true, "Model should initialize even with invalid config")
    }
    
    @Test("Model handles invalid base URL gracefully")
    func testInvalidBaseURL() {
        let invalidConfig = OpenAIConfiguration(
            apiKey: "test-key",
            baseURL: URL(string: "https://invalid-url-that-does-not-exist.com/v1")!,
            organization: nil
        )
        
        let model = OpenAILanguageModel(
            configuration: invalidConfig,
            model: .gpt4o
        )
        
        // Model should still initialize (validation happens during API calls)
        #expect(model.isAvailable == true, "Model should initialize with invalid base URL")
    }
    
    // MARK: - Sendable Compliance Tests
    
    @Test("Model is Sendable compliant")
    func testSendableCompliance() async {
        let model = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        // Test that model can be used across actor boundaries
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    // This verifies Sendable compliance by using model in concurrent context
                    return model.isAvailable
                }
            }
            
            for await result in group {
                #expect(result == true, "Model should be available in concurrent context")
            }
        }
    }
    
    // MARK: - Configuration Tests
    
    @Test("Configuration validation works correctly")
    func testConfigurationValidation() {
        // Test valid configuration
        let validConfig = OpenAIConfiguration(
            apiKey: "sk-test-valid-key",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            organization: "test-org",
            timeout: 60.0
        )
        
        let warnings = validConfig.validate()
        #expect(warnings.isEmpty, "Valid configuration should have no warnings")
        
        // Test configuration with warnings
        let warningConfig = OpenAIConfiguration(
            apiKey: "invalid-key", // Should trigger warning
            timeout: 5.0 // Should trigger warning
        )
        
        let configWarnings = warningConfig.validate()
        #expect(configWarnings.count > 0, "Invalid configuration should have warnings")
    }
    
    // MARK: - Model Comparison Tests
    
    @Test("Different model instances have different characteristics")
    func testModelCharacteristics() {
        let gptModel = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .gpt4o
        )
        
        let reasoningModel = OpenAILanguageModel(
            configuration: Self.testConfiguration,
            model: .o4Mini
        )
        
        let gptInfo = gptModel.modelInfo
        let reasoningInfo = reasoningModel.modelInfo
        
        #expect(gptInfo.isReasoningModel != reasoningInfo.isReasoningModel, 
                "GPT and reasoning models should have different reasoning capabilities")
        #expect(gptInfo.name != reasoningInfo.name, 
                "Different models should have different names")
        #expect(gptInfo.capabilities != reasoningInfo.capabilities, 
                "Different models should have different capabilities")
    }
}