import Foundation

// MARK: - Streaming Handler
internal struct StreamingHandler: Sendable {
    
    /// Process streaming data and extract chat completion chunks
    func processStreamData(_ data: Data) throws -> [ChatCompletionStreamResponse]? {
        guard let line = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Parse Server-Sent Events format
        let serverSentEvent = parseServerSentEvent(line)
        
        // Skip non-data events
        guard let eventData = serverSentEvent.data, !eventData.isEmpty else {
            return nil
        }
        
        // Handle end of stream
        if eventData.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
            return nil
        }
        
        // Parse JSON chunk
        guard let jsonData = eventData.data(using: .utf8) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let chunk = try decoder.decode(ChatCompletionStreamResponse.self, from: jsonData)
            return [chunk]
        } catch {
            throw OpenAIResponseError.decodingError(error)
        }
    }
    
    private func parseServerSentEvent(_ line: String) -> ServerSentEvent {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty lines are field separators
        if trimmedLine.isEmpty {
            return ServerSentEvent(id: nil, event: nil, data: nil, retry: nil)
        }
        
        // Parse field: value format
        if let colonIndex = trimmedLine.firstIndex(of: ":") {
            let field = String(trimmedLine[..<colonIndex])
            let valueStartIndex = trimmedLine.index(after: colonIndex)
            let value = valueStartIndex < trimmedLine.endIndex 
                ? String(trimmedLine[valueStartIndex...]).trimmingCharacters(in: .whitespaces)
                : ""
            
            switch field {
            case "id":
                return ServerSentEvent(id: value, event: nil, data: nil, retry: nil)
            case "event":
                return ServerSentEvent(id: nil, event: value, data: nil, retry: nil)
            case "data":
                return ServerSentEvent(id: nil, event: nil, data: value, retry: nil)
            case "retry":
                let retryValue = Int(value)
                return ServerSentEvent(id: nil, event: nil, data: nil, retry: retryValue)
            default:
                return ServerSentEvent(id: nil, event: nil, data: nil, retry: nil)
            }
        }
        
        // If no colon, treat entire line as data
        return ServerSentEvent(id: nil, event: nil, data: trimmedLine, retry: nil)
    }
}

// MARK: - Server-Sent Event
internal struct ServerSentEvent: Sendable {
    let id: String?
    let event: String?
    let data: String?
    let retry: Int?
}

// MARK: - Advanced Streaming Handler
internal actor AdvancedStreamingHandler {
    private var buffer: String = ""
    private var accumulatedContent: String = ""
    private var isComplete: Bool = false
    
    func processStreamChunk(_ data: Data) throws -> StreamProcessingResult {
        guard let chunk = String(data: data, encoding: .utf8) else {
            throw OpenAIResponseError.streamingError("Invalid UTF-8 data received")
        }
        
        buffer += chunk
        var results: [ChatCompletionStreamResponse] = []
        
        // Process complete lines
        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[..<newlineRange.lowerBound])
            buffer.removeSubrange(..<newlineRange.upperBound)
            
            if let event = try parseEventLine(line) {
                results.append(event)
            }
        }
        
        return StreamProcessingResult(
            chunks: results,
            accumulatedContent: accumulatedContent,
            isComplete: isComplete
        )
    }
    
    private func parseEventLine(_ line: String) throws -> ChatCompletionStreamResponse? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines and non-data lines
        guard trimmedLine.hasPrefix("data: ") else {
            return nil
        }
        
        let dataContent = String(trimmedLine.dropFirst(6)) // Remove "data: "
        
        // Handle end of stream
        if dataContent == "[DONE]" {
            isComplete = true
            return nil
        }
        
        // Parse JSON
        guard let jsonData = dataContent.data(using: .utf8) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let chunk = try decoder.decode(ChatCompletionStreamResponse.self, from: jsonData)

            // Accumulate content
            if let content = chunk.choices.first?.delta.content {
                accumulatedContent += content
            }

            // Check for finish reason to mark stream as complete
            if let finishReason = chunk.choices.first?.finishReason, !finishReason.isEmpty {
                isComplete = true
            }

            return chunk
        } catch {
            throw OpenAIResponseError.decodingError(error)
        }
    }
    
    func getAccumulatedContent() -> String {
        return accumulatedContent
    }
    
    func isStreamComplete() -> Bool {
        return isComplete
    }
    
    func reset() {
        buffer = ""
        accumulatedContent = ""
        isComplete = false
    }
}

// MARK: - Stream Processing Result
internal struct StreamProcessingResult: Sendable {
    let chunks: [ChatCompletionStreamResponse]
    let accumulatedContent: String
    let isComplete: Bool
}

// MARK: - Stream Collector (for testing and debugging)
internal actor StreamCollector {
    private var chunks: [ChatCompletionStreamResponse] = []
    private var content: String = ""
    private var isComplete: Bool = false
    
    func addChunk(_ chunk: ChatCompletionStreamResponse) {
        chunks.append(chunk)
        
        if let deltaContent = chunk.choices.first?.delta.content {
            content += deltaContent
        }
        
        if let finishReason = chunk.choices.first?.finishReason, !finishReason.isEmpty {
            isComplete = true
        }
    }
    
    func getCollectedContent() -> String {
        return content
    }
    
    func getAllChunks() -> [ChatCompletionStreamResponse] {
        return chunks
    }
    
    func isStreamComplete() -> Bool {
        return isComplete
    }
    
    func getStatistics() -> StreamStatistics {
        return StreamStatistics(
            totalChunks: chunks.count,
            totalCharacters: content.count,
            estimatedTokens: content.count / 4, // Rough estimate
            isComplete: isComplete
        )
    }
}

// MARK: - Stream Statistics
internal struct StreamStatistics: Sendable {
    let totalChunks: Int
    let totalCharacters: Int
    let estimatedTokens: Int
    let isComplete: Bool
}

// MARK: - Async Stream Helpers
extension AsyncStream where Element == String {
    
    /// Collect all streamed content into a single string
    internal func collect() async throws -> String {
        var result = ""
        for try await chunk in self {
            result += chunk
        }
        return result
    }
}