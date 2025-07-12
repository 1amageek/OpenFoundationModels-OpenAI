import Foundation

// MARK: - OpenAI Configuration
public struct OpenAIConfiguration: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let organization: String?
    public let timeout: TimeInterval
    public let retryPolicy: RetryPolicy
    public let rateLimits: RateLimitConfiguration
    
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        organization: String? = nil,
        timeout: TimeInterval = 120.0,
        retryPolicy: RetryPolicy = .exponentialBackoff(),
        rateLimits: RateLimitConfiguration = .default
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.organization = organization
        self.timeout = timeout
        self.retryPolicy = retryPolicy
        self.rateLimits = rateLimits
    }
}

// MARK: - Retry Policy
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double
    
    public init(
        maxAttempts: Int,
        initialDelay: TimeInterval,
        maxDelay: TimeInterval,
        backoffMultiplier: Double = 2.0
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
    }
    
    public static func exponentialBackoff(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 32.0
    ) -> RetryPolicy {
        return RetryPolicy(
            maxAttempts: maxAttempts,
            initialDelay: initialDelay,
            maxDelay: maxDelay
        )
    }
    
    public static let none = RetryPolicy(maxAttempts: 1, initialDelay: 0, maxDelay: 0)
}

// MARK: - Rate Limit Configuration
public struct RateLimitConfiguration: Sendable {
    public let requestsPerMinute: Int
    public let tokensPerMinute: Int
    public let enableBackoff: Bool
    
    public init(
        requestsPerMinute: Int,
        tokensPerMinute: Int,
        enableBackoff: Bool = true
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.enableBackoff = enableBackoff
    }
    
    public static let `default` = RateLimitConfiguration(
        requestsPerMinute: 3_500,
        tokensPerMinute: 90_000,
        enableBackoff: true
    )
    
    public static let tier1 = RateLimitConfiguration(
        requestsPerMinute: 500,
        tokensPerMinute: 30_000,
        enableBackoff: true
    )
    
    public static let tier2 = RateLimitConfiguration(
        requestsPerMinute: 3_500,
        tokensPerMinute: 90_000,
        enableBackoff: true
    )
    
    public static let tier3 = RateLimitConfiguration(
        requestsPerMinute: 10_000,
        tokensPerMinute: 150_000,
        enableBackoff: true
    )
    
    public static let unlimited = RateLimitConfiguration(
        requestsPerMinute: Int.max,
        tokensPerMinute: Int.max,
        enableBackoff: false
    )
}

// MARK: - Configuration Validation
extension OpenAIConfiguration {
    /// Validates the configuration and returns any warnings
    public func validate() -> [String] {
        var warnings: [String] = []
        
        // Check API key format
        if !apiKey.hasPrefix("sk-") && !apiKey.hasPrefix("sk-proj-") {
            warnings.append("API key doesn't follow expected OpenAI format")
        }
        
        // Check timeout value
        if timeout < 10.0 {
            warnings.append("Timeout value (\(timeout)s) is very low and may cause frequent timeouts")
        }
        
        if timeout > 300.0 {
            warnings.append("Timeout value (\(timeout)s) is very high")
        }
        
        // Check rate limits
        if rateLimits.requestsPerMinute > 10_000 {
            warnings.append("Rate limit (\(rateLimits.requestsPerMinute) RPM) exceeds typical OpenAI limits")
        }
        
        return warnings
    }
    
    /// Returns a configuration with validated values
    public func validated() -> OpenAIConfiguration {
        return OpenAIConfiguration(
            apiKey: apiKey,
            baseURL: baseURL,
            organization: organization,
            timeout: max(10.0, min(300.0, timeout)),
            retryPolicy: retryPolicy,
            rateLimits: rateLimits
        )
    }
}