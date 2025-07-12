import Testing
import Foundation
@testable import OpenFoundationModelsOpenAI

@Suite("Configuration Tests")
struct ConfigurationTests: Sendable {
    
    // MARK: - Mock Factory
    
    private static func createMockConfiguration() -> OpenAIConfiguration {
        return OpenAIConfiguration(
            apiKey: "sk-test-api-key-12345",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            organization: "test-org-id",
            timeout: 30.0,
            retryPolicy: .exponentialBackoff(maxAttempts: 3),
            rateLimits: .default
        )
    }
    
    private static func createMinimalConfiguration() -> OpenAIConfiguration {
        return OpenAIConfiguration(
            apiKey: "sk-test-api-key"
        )
    }
    
    // MARK: - Basic Configuration Tests
    
    @Test("Configuration can be created with all parameters")
    func configurationCreationWithAllParameters() {
        let config = Self.createMockConfiguration()
        
        #expect(config.apiKey == "sk-test-api-key-12345")
        #expect(config.organization == "test-org-id")
        #expect(config.baseURL.absoluteString == "https://api.openai.com/v1")
        #expect(config.timeout == 30.0)
        #expect(config.retryPolicy.maxAttempts == 3)
    }
    
    @Test("Configuration can be created with minimal parameters")
    func configurationCreationWithMinimalParameters() {
        let config = Self.createMinimalConfiguration()
        
        #expect(config.apiKey == "sk-test-api-key")
        #expect(config.organization == nil)
        #expect(config.baseURL.absoluteString == "https://api.openai.com/v1")
        #expect(config.timeout == 120.0)
        #expect(config.retryPolicy.maxAttempts == 3)
    }
    
    @Test("Configuration handles empty API key")
    func configurationHandlesEmptyAPIKey() {
        let config = OpenAIConfiguration(
            apiKey: ""
        )
        
        #expect(config.apiKey.isEmpty)
    }
    
    @Test("Configuration handles custom base URL")
    func configurationHandlesCustomBaseURL() {
        let customURL = URL(string: "https://custom-api.example.com/v1")!
        let config = OpenAIConfiguration(
            apiKey: "sk-test-key",
            baseURL: customURL
        )
        
        #expect(config.baseURL == customURL)
    }
    
    // MARK: - Configuration Validation Tests
    
    @Test("Configuration validates timeout interval bounds")
    func configurationValidatesTimeoutInterval() {
        let zeroTimeoutConfig = OpenAIConfiguration(
            apiKey: "sk-test-key",
            timeout: 0.0
        )
        #expect(zeroTimeoutConfig.timeout == 0.0)
        
        let largeTimeoutConfig = OpenAIConfiguration(
            apiKey: "sk-test-key",
            timeout: 300.0
        )
        #expect(largeTimeoutConfig.timeout == 300.0)
    }
    
    @Test("Configuration validates max retries bounds")
    func configurationValidatesMaxRetries() {
        let zeroRetriesConfig = OpenAIConfiguration(
            apiKey: "sk-test-key",
            retryPolicy: .none
        )
        #expect(zeroRetriesConfig.retryPolicy.maxAttempts == 1)
        
        let manyRetriesConfig = OpenAIConfiguration(
            apiKey: "sk-test-key",
            retryPolicy: .exponentialBackoff(maxAttempts: 10)
        )
        #expect(manyRetriesConfig.retryPolicy.maxAttempts == 10)
    }
    
    // MARK: - Configuration Equatable Tests
    
    @Test("Configuration equality works correctly")
    func configurationEquality() {
        let config1 = Self.createMockConfiguration()
        let config2 = OpenAIConfiguration(
            apiKey: "sk-test-api-key-12345",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            organization: "test-org-id",
            timeout: 30.0,
            retryPolicy: .exponentialBackoff(maxAttempts: 3),
            rateLimits: .default
        )
        
        #expect(config1.apiKey == config2.apiKey)
        #expect(config1.organization == config2.organization)
        #expect(config1.baseURL == config2.baseURL)
        #expect(config1.timeout == config2.timeout)
        #expect(config1.retryPolicy.maxAttempts == config2.retryPolicy.maxAttempts)
    }
    
    @Test("Configuration inequality works correctly")
    func configurationInequality() {
        let config1 = Self.createMockConfiguration()
        let config2 = Self.createMinimalConfiguration()
        
        #expect(config1.apiKey != config2.apiKey)
        #expect(config1.organization != config2.organization)
        #expect(config1.timeout != config2.timeout)
    }
    
    // MARK: - Configuration Sendable Compliance Tests
    
    @Test("Configuration is sendable compliant")
    func configurationSendableCompliance() async {
        let config = Self.createMockConfiguration()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    let localConfig = config
                    #expect(localConfig.apiKey == "sk-test-api-key-12345")
                }
            }
        }
    }
    
    // MARK: - Configuration Performance Tests
    
    @Test("Configuration creation is efficient")
    func configurationCreationEfficiency() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<1000 {
            let _ = OpenAIConfiguration(
                apiKey: "sk-test-key-\(UUID().uuidString)",
                organization: "test-org"
            )
        }
        
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        #expect(elapsedTime < 1.0)
    }
    
    // MARK: - Configuration Edge Cases
    
    @Test("Configuration handles very long API key")
    func configurationHandlesLongAPIKey() {
        let longAPIKey = "sk-" + String(repeating: "a", count: 1000)
        let config = OpenAIConfiguration(
            apiKey: longAPIKey
        )
        
        #expect(config.apiKey.count == 1003)
        #expect(config.apiKey == longAPIKey)
    }
    
    @Test("Configuration handles special characters in organization ID")
    func configurationHandlesSpecialCharactersInOrgID() {
        let specialOrgID = "org-123_test@example.com"
        let config = OpenAIConfiguration(
            apiKey: "sk-test-key",
            organization: specialOrgID
        )
        
        #expect(config.organization == specialOrgID)
    }
    
    @Test("Configuration handles URL with query parameters")
    func configurationHandlesURLWithQueryParameters() {
        let urlWithQuery = URL(string: "https://api.openai.com/v1?version=2023-10-01")!
        let config = OpenAIConfiguration(
            apiKey: "sk-test-key",
            baseURL: urlWithQuery
        )
        
        #expect(config.baseURL == urlWithQuery)
        #expect(config.baseURL.query == "version=2023-10-01")
    }
    
    @Test("Configuration handles extreme timeout values")
    func configurationHandlesExtremeTimeoutValues() {
        let veryShortTimeout = OpenAIConfiguration(
            apiKey: "sk-test-key",
            timeout: 0.001
        )
        #expect(veryShortTimeout.timeout == 0.001)
        
        let veryLongTimeout = OpenAIConfiguration(
            apiKey: "sk-test-key",
            timeout: 3600.0
        )
        #expect(veryLongTimeout.timeout == 3600.0)
    }
    
    @Test("Configuration handles extreme retry values")
    func configurationHandlesExtremeRetryValues() {
        let noRetriesConfig = OpenAIConfiguration(
            apiKey: "sk-test-key",
            retryPolicy: .none
        )
        #expect(noRetriesConfig.retryPolicy.maxAttempts == 1)
        
        let manyRetriesConfig = OpenAIConfiguration(
            apiKey: "sk-test-key",
            retryPolicy: .exponentialBackoff(maxAttempts: 100)
        )
        #expect(manyRetriesConfig.retryPolicy.maxAttempts == 100)
    }
    
    // MARK: - Configuration Validation Tests
    
    @Test("Configuration validation detects invalid API key format")
    func configurationValidationDetectsInvalidAPIKey() {
        let config = OpenAIConfiguration(apiKey: "invalid-key-format")
        let warnings = config.validate()
        
        #expect(warnings.contains { $0.contains("API key doesn't follow expected OpenAI format") })
    }
    
    @Test("Configuration validation detects valid API key formats")
    func configurationValidationDetectsValidAPIKey() {
        let skConfig = OpenAIConfiguration(apiKey: "sk-test-key")
        let skProjConfig = OpenAIConfiguration(apiKey: "sk-proj-test-key")
        
        let skWarnings = skConfig.validate()
        let skProjWarnings = skProjConfig.validate()
        
        #expect(!skWarnings.contains { $0.contains("API key doesn't follow expected OpenAI format") })
        #expect(!skProjWarnings.contains { $0.contains("API key doesn't follow expected OpenAI format") })
    }
    
    @Test("Configuration validation detects low timeout values")
    func configurationValidationDetectsLowTimeout() {
        let config = OpenAIConfiguration(apiKey: "sk-test", timeout: 5.0)
        let warnings = config.validate()
        
        #expect(warnings.contains { $0.contains("Timeout value") && $0.contains("very low") })
    }
    
    @Test("Configuration validation detects high timeout values")
    func configurationValidationDetectsHighTimeout() {
        let config = OpenAIConfiguration(apiKey: "sk-test", timeout: 400.0)
        let warnings = config.validate()
        
        #expect(warnings.contains { $0.contains("Timeout value") && $0.contains("very high") })
    }
    
    @Test("Configuration validation detects high rate limits")
    func configurationValidationDetectsHighRateLimits() {
        let highRateLimit = RateLimitConfiguration(requestsPerMinute: 20000, tokensPerMinute: 1000000)
        let config = OpenAIConfiguration(apiKey: "sk-test", rateLimits: highRateLimit)
        let warnings = config.validate()
        
        #expect(warnings.contains { $0.contains("Rate limit") && $0.contains("exceeds typical OpenAI limits") })
    }
    
    @Test("Configuration validated() method clamps timeout values")
    func configurationValidatedClampsTimeoutValues() {
        let lowTimeoutConfig = OpenAIConfiguration(apiKey: "sk-test", timeout: 5.0)
        let highTimeoutConfig = OpenAIConfiguration(apiKey: "sk-test", timeout: 400.0)
        
        let validatedLow = lowTimeoutConfig.validated()
        let validatedHigh = highTimeoutConfig.validated()
        
        #expect(validatedLow.timeout == 10.0)
        #expect(validatedHigh.timeout == 300.0)
    }
    
    // MARK: - Rate Limit Configuration Tests
    
    @Test("Rate limit configuration has correct default values")
    func rateLimitConfigurationDefaults() {
        let defaultConfig = RateLimitConfiguration.default
        
        #expect(defaultConfig.requestsPerMinute == 3_500)
        #expect(defaultConfig.tokensPerMinute == 90_000)
        #expect(defaultConfig.enableBackoff == true)
    }
    
    @Test("Rate limit configuration tiers work correctly")
    func rateLimitConfigurationTiers() {
        let tier1 = RateLimitConfiguration.tier1
        let tier2 = RateLimitConfiguration.tier2
        let tier3 = RateLimitConfiguration.tier3
        let unlimited = RateLimitConfiguration.unlimited
        
        #expect(tier1.requestsPerMinute == 500)
        #expect(tier1.tokensPerMinute == 30_000)
        
        #expect(tier2.requestsPerMinute == 3_500)
        #expect(tier2.tokensPerMinute == 90_000)
        
        #expect(tier3.requestsPerMinute == 10_000)
        #expect(tier3.tokensPerMinute == 150_000)
        
        #expect(unlimited.requestsPerMinute == Int.max)
        #expect(unlimited.tokensPerMinute == Int.max)
        #expect(unlimited.enableBackoff == false)
    }
    
    // MARK: - Retry Policy Tests
    
    @Test("Retry policy exponential backoff has correct defaults")
    func retryPolicyExponentialBackoffDefaults() {
        let policy = RetryPolicy.exponentialBackoff()
        
        #expect(policy.maxAttempts == 3)
        #expect(policy.initialDelay == 1.0)
        #expect(policy.maxDelay == 32.0)
        #expect(policy.backoffMultiplier == 2.0)
    }
    
    @Test("Retry policy none has correct values")
    func retryPolicyNone() {
        let policy = RetryPolicy.none
        
        #expect(policy.maxAttempts == 1)
        #expect(policy.initialDelay == 0)
        #expect(policy.maxDelay == 0)
    }
    
    @Test("Retry policy can be customized")
    func retryPolicyCustomization() {
        let customPolicy = RetryPolicy(
            maxAttempts: 5,
            initialDelay: 2.0,
            maxDelay: 60.0,
            backoffMultiplier: 1.5
        )
        
        #expect(customPolicy.maxAttempts == 5)
        #expect(customPolicy.initialDelay == 2.0)
        #expect(customPolicy.maxDelay == 60.0)
        #expect(customPolicy.backoffMultiplier == 1.5)
    }
}