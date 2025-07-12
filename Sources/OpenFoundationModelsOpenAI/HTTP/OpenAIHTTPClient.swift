import Foundation

// MARK: - HTTP Request/Response Types
public struct OpenAIHTTPRequest: Sendable {
    public let endpoint: String
    public let method: HTTPMethod
    public let headers: [String: String]
    public let body: Data?
    public let timeout: TimeInterval
    
    public init(
        endpoint: String,
        method: HTTPMethod = .POST,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 120.0
    ) {
        self.endpoint = endpoint
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

public enum HTTPMethod: String, Sendable {
    case GET = "GET"
    case POST = "POST"
}

public struct OpenAIHTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let data: Data
    
    public init(statusCode: Int, headers: [String: String], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}

// MARK: - HTTP Errors
public enum OpenAIHTTPError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case networkError(Error)
    case invalidResponse
    case statusError(Int, Data?)
    case decodingError(Error)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case authenticationFailed
    case apiError(OpenAIAPIError)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response received"
        case .statusError(let code, _):
            return "HTTP error with status code: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Retry after: \(retryAfter?.description ?? "unknown")"
        case .authenticationFailed:
            return "Authentication failed. Check your API key."
        case .apiError(let apiError):
            return "API error: \(apiError.message)"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - OpenAI API Error
public struct OpenAIAPIError: Codable, Error, Sendable {
    public let message: String
    public let type: String?
    public let param: String?
    public let code: String?
    
    public struct ErrorResponse: Codable, Sendable {
        public let error: OpenAIAPIError
    }
}

// MARK: - HTTP Client
public actor OpenAIHTTPClient {
    private let session: URLSession
    private let configuration: OpenAIConfiguration
    private let baseURL: URL
    
    public init(configuration: OpenAIConfiguration) {
        self.configuration = configuration
        self.baseURL = configuration.baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.timeoutIntervalForResource = configuration.timeout
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// Send a request and decode the response
    public func send<T: Codable>(_ request: OpenAIHTTPRequest) async throws -> T {
        let response = try await sendRaw(request)
        
        // Check for API errors first
        if response.statusCode >= 400 {
            try handleErrorResponse(response)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw OpenAIHTTPError.decodingError(error)
        }
    }
    
    /// Send a raw request
    public func sendRaw(_ request: OpenAIHTTPRequest) async throws -> OpenAIHTTPResponse {
        let urlRequest = try buildURLRequest(from: request)
        
        do {
            let (data, urlResponse) = try await session.data(for: urlRequest)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw OpenAIHTTPError.invalidResponse
            }
            
            let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, header in
                if let key = header.key as? String, let value = header.value as? String {
                    result[key] = value
                }
            }
            
            return OpenAIHTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: headers,
                data: data
            )
        } catch {
            if error is URLError {
                throw OpenAIHTTPError.networkError(error)
            }
            throw error
        }
    }
    
    /// Stream a request (for Server-Sent Events)
    public func stream(_ request: OpenAIHTTPRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlRequest = try buildURLRequest(from: request)
                    
                    let (asyncBytes, urlResponse) = try await session.bytes(for: urlRequest)
                    
                    guard let httpResponse = urlResponse as? HTTPURLResponse else {
                        continuation.finish(throwing: OpenAIHTTPError.invalidResponse)
                        return
                    }
                    
                    if httpResponse.statusCode >= 400 {
                        // Collect error data
                        var errorData = Data()
                        for try await byte in asyncBytes {
                            errorData.append(byte)
                        }
                        
                        let response = OpenAIHTTPResponse(
                            statusCode: httpResponse.statusCode,
                            headers: [:],
                            data: errorData
                        )
                        try handleErrorResponse(response)
                        return
                    }
                    
                    var buffer = Data()
                    
                    for try await byte in asyncBytes {
                        buffer.append(byte)
                        
                        // Look for complete lines (Server-Sent Events are line-based)
                        while let newlineRange = buffer.range(of: Data([0x0A])) { // \n
                            let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
                            buffer.removeSubrange(0..<newlineRange.upperBound)
                            
                            if !lineData.isEmpty {
                                continuation.yield(lineData)
                            }
                        }
                    }
                    
                    // Send any remaining data
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func buildURLRequest(from request: OpenAIHTTPRequest) throws -> URLRequest {
        let fullURL = baseURL.appendingPathComponent(request.endpoint)
        
        guard let url = URL(string: fullURL.absoluteString) else {
            throw OpenAIHTTPError.invalidURL(fullURL.absoluteString)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        
        // Set default headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        
        if let organization = configuration.organization {
            urlRequest.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Set custom headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body
        urlRequest.httpBody = request.body
        
        return urlRequest
    }
    
    private func handleErrorResponse(_ response: OpenAIHTTPResponse) throws {
        switch response.statusCode {
        case 401:
            throw OpenAIHTTPError.authenticationFailed
        case 429:
            let retryAfter = parseRetryAfter(from: response.headers)
            throw OpenAIHTTPError.rateLimitExceeded(retryAfter: retryAfter)
        default:
            // Try to parse API error
            if let apiError = try? parseAPIError(from: response.data) {
                throw OpenAIHTTPError.apiError(apiError)
            } else {
                throw OpenAIHTTPError.statusError(response.statusCode, response.data)
            }
        }
    }
    
    private func parseRetryAfter(from headers: [String: String]) -> TimeInterval? {
        if let retryAfterHeader = headers["Retry-After"] ?? headers["retry-after"] {
            return TimeInterval(retryAfterHeader)
        }
        return nil
    }
    
    private func parseAPIError(from data: Data) throws -> OpenAIAPIError {
        let decoder = JSONDecoder()
        let errorResponse = try decoder.decode(OpenAIAPIError.ErrorResponse.self, from: data)
        return errorResponse.error
    }
}