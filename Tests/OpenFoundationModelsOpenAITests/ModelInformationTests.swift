import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI

@Suite("Model Information Tests")
struct ModelInformationTests: Sendable {
    
    // MARK: - OpenAI Model Tests
    
    @Test("OpenAI model has correct API name")
    func openAIModelAPIName() {
        let gpt4o = OpenAIModel.gpt4o
        let gpt4oMini = OpenAIModel.gpt4oMini
        let o1 = OpenAIModel.o1
        
        #expect(gpt4o.apiName == "gpt-4o")
        #expect(gpt4oMini.apiName == "gpt-4o-mini")
        #expect(o1.apiName == "o1")
    }
    
    @Test("OpenAI model has correct context window")
    func openAIModelContextWindow() {
        let gpt4o = OpenAIModel.gpt4o
        let o1 = OpenAIModel.o1
        
        #expect(gpt4o.contextWindow == 128_000)
        #expect(o1.contextWindow == 200_000)
    }
    
    @Test("OpenAI model has correct max output tokens")
    func openAIModelMaxOutputTokens() {
        let gpt4o = OpenAIModel.gpt4o
        let gpt4oMini = OpenAIModel.gpt4oMini
        let o1 = OpenAIModel.o1
        let o1Pro = OpenAIModel.o1Pro
        
        #expect(gpt4o.maxOutputTokens == 16_384)
        #expect(gpt4oMini.maxOutputTokens == 16_384)
        #expect(o1.maxOutputTokens == 32_768)
        #expect(o1Pro.maxOutputTokens == 65_536)
    }
    
    @Test("OpenAI model has correct capabilities")
    func openAIModelCapabilities() {
        let gpt4o = OpenAIModel.gpt4o
        let gpt4oMini = OpenAIModel.gpt4oMini
        let o1 = OpenAIModel.o1
        
        #expect(gpt4o.supportsVision)
        #expect(gpt4o.supportsFunctionCalling)
        #expect(gpt4o.supportsStreaming)
        #expect(!gpt4o.isReasoningModel)
        
        #expect(gpt4oMini.supportsVision)
        #expect(gpt4oMini.supportsFunctionCalling)
        #expect(gpt4oMini.supportsStreaming)
        #expect(!gpt4oMini.isReasoningModel)
        
        #expect(!o1.supportsVision)
        #expect(o1.supportsFunctionCalling)
        #expect(o1.supportsStreaming)
        #expect(o1.isReasoningModel)
    }
    
    @Test("OpenAI model has correct pricing tier")
    func openAIModelPricingTier() {
        let gpt4oMini = OpenAIModel.gpt4oMini
        let gpt4o = OpenAIModel.gpt4o
        let o1Pro = OpenAIModel.o1Pro
        
        #expect(gpt4oMini.pricingTier == .economy)
        #expect(gpt4o.pricingTier == .standard)
        #expect(o1Pro.pricingTier == .premium)
    }
    
    @Test("OpenAI model has correct knowledge cutoff")
    func openAIModelKnowledgeCutoff() {
        let gpt4o = OpenAIModel.gpt4o
        let gpt4Turbo = OpenAIModel.gpt4Turbo
        let o1 = OpenAIModel.o1
        
        #expect(gpt4o.knowledgeCutoff == "October 2023")
        #expect(gpt4Turbo.knowledgeCutoff == "April 2024")
        #expect(o1.knowledgeCutoff == "October 2023")
    }
    
    // MARK: - Model Collection Tests
    
    @Test("OpenAI model has all expected models")
    func openAIModelAllCases() {
        let allModels = OpenAIModel.allCases
        
        #expect(allModels.contains(.gpt4o))
        #expect(allModels.contains(.gpt4oMini))
        #expect(allModels.contains(.gpt4Turbo))
        #expect(allModels.contains(.o1))
        #expect(allModels.contains(.o1Pro))
        #expect(allModels.contains(.o3))
        #expect(allModels.contains(.o3Pro))
        #expect(allModels.contains(.o4Mini))
        
        #expect(allModels.count >= 8)
    }
    
    @Test("OpenAI model GPT models collection")
    func openAIModelGPTModels() {
        let gptModels = OpenAIModel.gptModels
        
        #expect(gptModels.contains(.gpt4o))
        #expect(gptModels.contains(.gpt4oMini))
        #expect(gptModels.contains(.gpt4Turbo))
        #expect(!gptModels.contains(.o1))
        #expect(!gptModels.contains(.o1Pro))
    }
    
    @Test("OpenAI model reasoning models collection")
    func openAIModelReasoningModels() {
        let reasoningModels = OpenAIModel.reasoningModels
        
        #expect(reasoningModels.contains(.o1))
        #expect(reasoningModels.contains(.o1Pro))
        #expect(reasoningModels.contains(.o3))
        #expect(reasoningModels.contains(.o3Pro))
        #expect(reasoningModels.contains(.o4Mini))
        #expect(!reasoningModels.contains(.gpt4o))
        #expect(!reasoningModels.contains(.gpt4oMini))
    }
    
    @Test("OpenAI model filtering by pricing tier")
    func openAIModelFilteringByPricingTier() {
        let economyModels = OpenAIModel.models(withPricingTier: .economy)
        let standardModels = OpenAIModel.models(withPricingTier: .standard)
        let premiumModels = OpenAIModel.models(withPricingTier: .premium)
        
        #expect(economyModels.contains(.gpt4oMini))
        #expect(economyModels.contains(.o4Mini))
        
        #expect(standardModels.contains(.gpt4o))
        #expect(standardModels.contains(.o1))
        
        #expect(premiumModels.contains(.o1Pro))
        #expect(premiumModels.contains(.o3Pro))
    }
    
    @Test("OpenAI model filtering by capability")
    func openAIModelFilteringByCapability() {
        let visionModels = OpenAIModel.models(withCapability: .vision)
        let reasoningModels = OpenAIModel.models(withCapability: .reasoning)
        let functionCallingModels = OpenAIModel.models(withCapability: .functionCalling)
        
        #expect(visionModels.contains(.gpt4o))
        #expect(visionModels.contains(.gpt4oMini))
        #expect(!visionModels.contains(.o1))
        
        #expect(reasoningModels.contains(.o1))
        #expect(reasoningModels.contains(.o1Pro))
        #expect(!reasoningModels.contains(.gpt4o))
        
        #expect(functionCallingModels.contains(.gpt4o))
        #expect(functionCallingModels.contains(.o1))
    }
    
    // MARK: - Model Serialization Tests
    
    @Test("OpenAI model raw value serialization")
    func openAIModelRawValueSerialization() {
        let gpt4o = OpenAIModel.gpt4o
        let o1 = OpenAIModel.o1
        
        #expect(gpt4o.rawValue == "gpt-4o")
        #expect(o1.rawValue == "o1")
        
        // Test that we can create from raw value
        #expect(OpenAIModel(rawValue: "gpt-4o") == .gpt4o)
        #expect(OpenAIModel(rawValue: "o1") == .o1)
        #expect(OpenAIModel(rawValue: "invalid-model") == nil)
    }
    
    @Test("OpenAI model string representation")
    func openAIModelStringRepresentation() {
        let gpt4o = OpenAIModel.gpt4o
        let o1 = OpenAIModel.o1
        
        let gpt4oDescription = String(describing: gpt4o)
        let o1Description = String(describing: o1)
        
        #expect(gpt4oDescription.contains("gpt-4o"))
        #expect(gpt4oDescription.contains("gpt"))
        #expect(gpt4oDescription.contains("standard"))
        
        #expect(o1Description.contains("o1"))
        #expect(o1Description.contains("reasoning"))
        #expect(o1Description.contains("standard"))
    }
    
    @Test("OpenAI model debug description")
    func openAIModelDebugDescription() {
        let gpt4o = OpenAIModel.gpt4o
        let debugDescription = String(reflecting: gpt4o)
        
        #expect(debugDescription.contains("OpenAIModel"))
        #expect(debugDescription.contains("gpt-4o"))
        #expect(debugDescription.contains("128000"))
        #expect(debugDescription.contains("16384"))
        #expect(debugDescription.contains("standard"))
        #expect(debugDescription.contains("October 2023"))
    }
    
    // MARK: - Model Comparison Tests
    
    @Test("OpenAI models can be compared for equality")
    func openAIModelEqualityComparison() {
        let model1 = OpenAIModel.gpt4o
        let model2 = OpenAIModel.gpt4o
        let model3 = OpenAIModel.gpt4oMini
        
        #expect(model1 == model2)
        #expect(model1 != model3)
        #expect(model1.apiName == model2.apiName)
        #expect(model1.apiName != model3.apiName)
    }
    
    @Test("OpenAI models can be sorted")
    func openAIModelSorting() {
        let models = [OpenAIModel.o1, OpenAIModel.gpt4o, OpenAIModel.gpt4oMini]
        let sortedModels = models.sorted { $0.rawValue < $1.rawValue }
        
        #expect(sortedModels[0] == .gpt4o)
        #expect(sortedModels[1] == .gpt4oMini)
        #expect(sortedModels[2] == .o1)
    }
    
    // MARK: - Model Performance Tests
    
    @Test("OpenAI model property access is efficient")
    func openAIModelPropertyAccessEfficiency() {
        let model = OpenAIModel.gpt4o
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<10000 {
            let _ = model.apiName
            let _ = model.contextWindow
            let _ = model.maxOutputTokens
            let _ = model.capabilities
            let _ = model.pricingTier
        }
        
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        #expect(elapsedTime < 1.0)
    }
    
    @Test("OpenAI model filtering is efficient")
    func openAIModelFilteringEfficiency() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<1000 {
            let _ = OpenAIModel.gptModels
            let _ = OpenAIModel.reasoningModels
            let _ = OpenAIModel.models(withPricingTier: .economy)
            let _ = OpenAIModel.models(withCapability: .vision)
        }
        
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        #expect(elapsedTime < 1.0)
    }
    
    // MARK: - Model Edge Cases
    
    @Test("OpenAI model handles case insensitive raw value creation")
    func openAIModelCaseInsensitiveCreation() {
        // OpenAI models are case sensitive
        #expect(OpenAIModel(rawValue: "GPT-4O") == nil)
        #expect(OpenAIModel(rawValue: "O1") == nil)
        #expect(OpenAIModel(rawValue: "gpt-4o") == .gpt4o)
        #expect(OpenAIModel(rawValue: "o1") == .o1)
    }
    
    @Test("OpenAI model handles empty collections gracefully")
    func openAIModelEmptyCollections() {
        // Test with empty capability set
        let economyModels = OpenAIModel.models(withPricingTier: .economy)
        let standardModels = OpenAIModel.models(withPricingTier: .standard)
        let premiumModels = OpenAIModel.models(withPricingTier: .premium)
        
        #expect(!economyModels.isEmpty)
        #expect(!standardModels.isEmpty)
        #expect(!premiumModels.isEmpty)
        
        // All models should be in one of the tiers
        let totalCount = economyModels.count + standardModels.count + premiumModels.count
        #expect(totalCount == OpenAIModel.allCases.count)
    }
    
    @Test("OpenAI model capabilities are consistent")
    func openAIModelCapabilitiesConsistency() {
        for model in OpenAIModel.allCases {
            // All models should support streaming
            #expect(model.supportsStreaming)
            
            // All models should support function calling
            #expect(model.supportsFunctionCalling)
            
            // Reasoning models should not support vision
            if model.isReasoningModel {
                #expect(!model.supportsVision)
            }
            
            // Context window should be positive
            #expect(model.contextWindow > 0)
            
            // Max output tokens should be positive
            #expect(model.maxOutputTokens > 0)
            
            // Max output should be less than context window
            #expect(model.maxOutputTokens <= model.contextWindow)
        }
    }
    
    @Test("OpenAI model parameter constraints are valid")
    func openAIModelParameterConstraints() {
        // Test GPT models
        let gptModels = OpenAIModel.gptModels
        for model in gptModels {
            #expect(!model.isReasoningModel)
        }
        
        // Test reasoning models
        let reasoningModels = OpenAIModel.reasoningModels
        for model in reasoningModels {
            #expect(model.isReasoningModel)
        }
        
        // Ensure no overlap
        let gptModelSet = Set(gptModels)
        let reasoningModelSet = Set(reasoningModels)
        #expect(gptModelSet.isDisjoint(with: reasoningModelSet))
        
        // Together they should equal all models
        let allModelSet = Set(OpenAIModel.allCases)
        #expect(gptModelSet.union(reasoningModelSet) == allModelSet)
    }
    
    // MARK: - Model Sendable Compliance Tests
    
    @Test("OpenAI model is sendable compliant")
    func openAIModelSendableCompliance() async {
        let model = OpenAIModel.gpt4o
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    let localModel = model
                    #expect(localModel.apiName == "gpt-4o")
                    #expect(localModel.contextWindow == 128_000)
                }
            }
        }
    }
    
    @Test("OpenAI model collections are sendable compliant")
    func openAIModelCollectionsSendableCompliance() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    let allModels = OpenAIModel.allCases
                    let gptModels = OpenAIModel.gptModels
                    let reasoningModels = OpenAIModel.reasoningModels
                    
                    #expect(allModels.count >= 8)
                    #expect(!gptModels.isEmpty)
                    #expect(!reasoningModels.isEmpty)
                }
            }
        }
    }
}