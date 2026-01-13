import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI

@Suite("Model Information Tests")
struct ModelInformationTests: Sendable {

    // MARK: - OpenAI Model Basic Tests

    @Test("OpenAI model has correct API name")
    func openAIModelAPIName() {
        let gpt4o = OpenAIModel.gpt4o
        let gpt4oMini = OpenAIModel.gpt4oMini
        let gpt41 = OpenAIModel.gpt41
        let o1 = OpenAIModel.o1

        #expect(gpt4o.apiName == "gpt-4o")
        #expect(gpt4oMini.apiName == "gpt-4o-mini")
        #expect(gpt41.apiName == "gpt-4.1")
        #expect(o1.apiName == "o1")
    }

    @Test("OpenAI model has correct context window")
    func openAIModelContextWindow() {
        let gpt4o = OpenAIModel.gpt4o
        let gpt41 = OpenAIModel.gpt41
        let o1 = OpenAIModel.o1

        #expect(gpt4o.contextWindow == 128_000)
        #expect(gpt41.contextWindow == 1_047_576)  // ~1M tokens
        #expect(o1.contextWindow == 200_000)
    }

    @Test("OpenAI model has correct max output tokens")
    func openAIModelMaxOutputTokens() {
        let gpt4o = OpenAIModel.gpt4o
        let gpt4oMini = OpenAIModel.gpt4oMini
        let gpt41 = OpenAIModel.gpt41
        let o1 = OpenAIModel.o1

        #expect(gpt4o.maxOutputTokens == 16_384)
        #expect(gpt4oMini.maxOutputTokens == 16_384)
        #expect(gpt41.maxOutputTokens == 32_768)
        #expect(o1.maxOutputTokens == 100_000)
    }

    @Test("OpenAI model has correct capabilities")
    func openAIModelCapabilities() {
        let gpt4o = OpenAIModel.gpt4o
        let gpt4oMini = OpenAIModel.gpt4oMini
        let o1 = OpenAIModel.o1

        // GPT models
        #expect(gpt4o.supportsVision)
        #expect(gpt4o.supportsFunctionCalling)
        #expect(gpt4o.supportsStreaming)
        #expect(!gpt4o.isReasoningModel)

        #expect(gpt4oMini.supportsVision)
        #expect(gpt4oMini.supportsFunctionCalling)
        #expect(gpt4oMini.supportsStreaming)
        #expect(!gpt4oMini.isReasoningModel)

        // Reasoning models
        #expect(o1.supportsFunctionCalling)
        #expect(o1.supportsStreaming)
        #expect(o1.isReasoningModel)
    }

    // MARK: - String-based Model Creation Tests

    @Test("OpenAI model can be created from string")
    func openAIModelStringCreation() {
        let model1 = OpenAIModel("gpt-4o")
        let model2 = OpenAIModel("o1")
        let model3 = OpenAIModel("custom-model")

        #expect(model1.id == "gpt-4o")
        #expect(model1.modelType == .gpt)

        #expect(model2.id == "o1")
        #expect(model2.modelType == .reasoning)

        #expect(model3.id == "custom-model")
        #expect(model3.modelType == .gpt)  // Default to GPT
    }

    @Test("OpenAI model can be created from string literal")
    func openAIModelStringLiteralCreation() {
        let model: OpenAIModel = "gpt-4.1-mini"

        #expect(model.id == "gpt-4.1-mini")
        #expect(model.modelType == .gpt)
    }

    @Test("OpenAI model type inference from string")
    func openAIModelTypeInference() {
        // GPT models
        let gpt4o = OpenAIModel("gpt-4o")
        let gpt41 = OpenAIModel("gpt-4.1")
        let customGPT = OpenAIModel("custom-gpt-model")

        #expect(gpt4o.modelType == .gpt)
        #expect(gpt41.modelType == .gpt)
        #expect(customGPT.modelType == .gpt)

        // Reasoning models
        let o1 = OpenAIModel("o1")
        let o1Pro = OpenAIModel("o1-pro")
        let o3 = OpenAIModel("o3")
        let o3Mini = OpenAIModel("o3-mini")
        let o4Mini = OpenAIModel("o4-mini")

        #expect(o1.modelType == .reasoning)
        #expect(o1Pro.modelType == .reasoning)
        #expect(o3.modelType == .reasoning)
        #expect(o3Mini.modelType == .reasoning)
        #expect(o4Mini.modelType == .reasoning)
    }

    @Test("OpenAI model can override inferred type")
    func openAIModelTypeOverride() {
        let customReasoning = OpenAIModel("my-custom-model", type: .reasoning)
        let customGPT = OpenAIModel("o1-like-model", type: .gpt)

        #expect(customReasoning.modelType == .reasoning)
        #expect(customGPT.modelType == .gpt)
    }

    // MARK: - Model Collection Tests

    @Test("OpenAIModelInfo provides all expected models")
    func openAIModelInfoAllModels() {
        let allModels = OpenAIModelInfo.allModels

        #expect(allModels.contains(.gpt4o))
        #expect(allModels.contains(.gpt4oMini))
        #expect(allModels.contains(.gpt4Turbo))
        #expect(allModels.contains(.gpt41))
        #expect(allModels.contains(.gpt41Mini))
        #expect(allModels.contains(.gpt41Nano))
        #expect(allModels.contains(.o1))
        #expect(allModels.contains(.o1Pro))
        #expect(allModels.contains(.o3))
        #expect(allModels.contains(.o3Pro))
        #expect(allModels.contains(.o3Mini))
        #expect(allModels.contains(.o4Mini))

        #expect(allModels.count >= 12)
    }

    @Test("OpenAIModelInfo GPT models collection")
    func openAIModelInfoGPTModels() {
        let gptModels = OpenAIModelInfo.gptModels

        #expect(gptModels.contains(.gpt4o))
        #expect(gptModels.contains(.gpt4oMini))
        #expect(gptModels.contains(.gpt4Turbo))
        #expect(gptModels.contains(.gpt41))
        #expect(gptModels.contains(.gpt41Mini))
        #expect(gptModels.contains(.gpt41Nano))
        #expect(!gptModels.contains(.o1))
        #expect(!gptModels.contains(.o1Pro))
    }

    @Test("OpenAIModelInfo reasoning models collection")
    func openAIModelInfoReasoningModels() {
        let reasoningModels = OpenAIModelInfo.reasoningModels

        #expect(reasoningModels.contains(.o1))
        #expect(reasoningModels.contains(.o1Pro))
        #expect(reasoningModels.contains(.o3))
        #expect(reasoningModels.contains(.o3Pro))
        #expect(reasoningModels.contains(.o3Mini))
        #expect(reasoningModels.contains(.o4Mini))
        #expect(!reasoningModels.contains(.gpt4o))
        #expect(!reasoningModels.contains(.gpt4oMini))
    }

    @Test("OpenAIModelInfo filtering by capability")
    func openAIModelInfoFilteringByCapability() {
        let visionModels = OpenAIModelInfo.models(withCapability: .vision)
        let reasoningCapableModels = OpenAIModelInfo.models(withCapability: .reasoning)
        let functionCallingModels = OpenAIModelInfo.models(withCapability: .functionCalling)

        #expect(visionModels.contains(.gpt4o))
        #expect(visionModels.contains(.gpt4oMini))

        #expect(reasoningCapableModels.contains(.o1))
        #expect(reasoningCapableModels.contains(.o1Pro))
        #expect(!reasoningCapableModels.contains(.gpt4o))

        // All models support function calling
        #expect(functionCallingModels.contains(.gpt4o))
        #expect(functionCallingModels.contains(.o1))
    }

    // MARK: - Model Serialization Tests

    @Test("OpenAI model id serialization")
    func openAIModelIdSerialization() {
        let gpt4o = OpenAIModel.gpt4o
        let o1 = OpenAIModel.o1

        #expect(gpt4o.id == "gpt-4o")
        #expect(o1.id == "o1")
    }

    @Test("OpenAI model string representation")
    func openAIModelStringRepresentation() {
        let gpt4o = OpenAIModel.gpt4o
        let o1 = OpenAIModel.o1

        let gpt4oDescription = String(describing: gpt4o)
        let o1Description = String(describing: o1)

        #expect(gpt4oDescription.contains("gpt-4o"))
        #expect(gpt4oDescription.contains("gpt"))

        #expect(o1Description.contains("o1"))
        #expect(o1Description.contains("reasoning"))
    }

    @Test("OpenAI model debug description")
    func openAIModelDebugDescription() {
        let gpt4o = OpenAIModel.gpt4o
        let debugDescription = String(reflecting: gpt4o)

        #expect(debugDescription.contains("OpenAIModel"))
        #expect(debugDescription.contains("gpt-4o"))
        #expect(debugDescription.contains("128000"))
        #expect(debugDescription.contains("16384"))
    }

    @Test("OpenAI model is Codable")
    func openAIModelCodable() throws {
        let model = OpenAIModel.gpt41

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(model)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString == "\"gpt-4.1\"")

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OpenAIModel.self, from: data)

        #expect(decoded.id == model.id)
        #expect(decoded.modelType == model.modelType)
    }

    // MARK: - Model Comparison Tests

    @Test("OpenAI models can be compared for equality")
    func openAIModelEqualityComparison() {
        let model1 = OpenAIModel.gpt4o
        let model2 = OpenAIModel.gpt4o
        let model3 = OpenAIModel.gpt4oMini
        let model4 = OpenAIModel("gpt-4o")

        #expect(model1 == model2)
        #expect(model1 != model3)
        #expect(model1 == model4)  // Same id
    }

    @Test("OpenAI models can be sorted")
    func openAIModelSorting() {
        let models = [OpenAIModel.o1, OpenAIModel.gpt4o, OpenAIModel.gpt4oMini]
        let sortedModels = models.sorted { $0.id < $1.id }

        #expect(sortedModels[0] == .gpt4o)
        #expect(sortedModels[1] == .gpt4oMini)
        #expect(sortedModels[2] == .o1)
    }

    @Test("OpenAI models can be used in Set")
    func openAIModelInSet() {
        var modelSet: Set<OpenAIModel> = []

        modelSet.insert(.gpt4o)
        modelSet.insert(.gpt4oMini)
        modelSet.insert(.gpt4o)  // Duplicate

        #expect(modelSet.count == 2)
        #expect(modelSet.contains(.gpt4o))
        #expect(modelSet.contains(.gpt4oMini))
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
        }

        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        #expect(elapsedTime < 1.0)
    }

    // MARK: - Model Edge Cases

    @Test("OpenAI model handles custom model names")
    func openAIModelCustomNames() {
        let customModel = OpenAIModel("ft:gpt-4o:my-org:custom-suffix:id")

        #expect(customModel.id == "ft:gpt-4o:my-org:custom-suffix:id")
        #expect(customModel.modelType == .gpt)  // Inferred as GPT
    }

    @Test("OpenAI model handles future model names")
    func openAIModelFutureNames() {
        // Future GPT models
        let futureGPT = OpenAIModel("gpt-5")
        #expect(futureGPT.modelType == .gpt)

        // Future reasoning models
        let futureO5 = OpenAIModel("o5")
        #expect(futureO5.modelType == .gpt)  // Would need explicit type

        let futureO5WithType = OpenAIModel("o5", type: .reasoning)
        #expect(futureO5WithType.modelType == .reasoning)
    }

    @Test("OpenAI model capabilities are consistent")
    func openAIModelCapabilitiesConsistency() {
        for model in OpenAIModelInfo.allModels {
            // All models should support streaming
            #expect(model.supportsStreaming)

            // All models should support function calling
            #expect(model.supportsFunctionCalling)

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
        let gptModels = OpenAIModelInfo.gptModels
        for model in gptModels {
            #expect(!model.isReasoningModel)
            #expect(model.modelType == .gpt)
        }

        // Test reasoning models
        let reasoningModels = OpenAIModelInfo.reasoningModels
        for model in reasoningModels {
            #expect(model.isReasoningModel)
            #expect(model.modelType == .reasoning)
        }

        // Ensure no overlap
        let gptModelSet = Set(gptModels)
        let reasoningModelSet = Set(reasoningModels)
        #expect(gptModelSet.isDisjoint(with: reasoningModelSet))

        // Together they should equal all models
        let allModelSet = Set(OpenAIModelInfo.allModels)
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
                    let allModels = OpenAIModelInfo.allModels
                    let gptModels = OpenAIModelInfo.gptModels
                    let reasoningModels = OpenAIModelInfo.reasoningModels

                    #expect(allModels.count >= 12)
                    #expect(!gptModels.isEmpty)
                    #expect(!reasoningModels.isEmpty)
                }
            }
        }
    }
}
