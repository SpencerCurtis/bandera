import Vapor
import NIOCore

/// Middleware for rate limiting requests
struct RateLimitMiddleware: AsyncMiddleware {
    /// Maximum number of requests allowed in the time window
    let maxRequests: Int
    
    /// Time window in seconds
    let per: Int64
    
    /// Storage for rate limit counters
    let storage: RateLimitStorage
    
    /// Create a new rate limit middleware
    /// - Parameters:
    ///   - maxRequests: Maximum number of requests allowed in the time window
    ///   - per: Time window in seconds
    ///   - storage: Storage for rate limit counters
    init(maxRequests: Int, per: Int64, storage: RateLimitStorage) {
        self.maxRequests = maxRequests
        self.per = per
        self.storage = storage
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Get rate limit key for this request
        let key = try await getRateLimitKey(for: request)
        
        // Increment counter and get time remaining
        let (count, timeRemaining) = try await storage.increment(key: key, window: per)
        
        // Create response
        let response: Response
        if count > maxRequests {
            // Rate limit exceeded
            response = Response(status: .tooManyRequests)
            response.body = .init(string: "Rate limit exceeded. Try again in \(timeRemaining) seconds.")
        } else {
            // Request allowed, continue chain
            response = try await next.respond(to: request)
        }
        
        // Add rate limit headers
        response.headers.add(name: "X-RateLimit-Limit", value: "\(maxRequests)")
        response.headers.add(name: "X-RateLimit-Remaining", value: "\(maxRequests - count)")
        response.headers.add(name: "X-RateLimit-Reset", value: "\(timeRemaining)")
        
        return response
    }
    
    /// Get the rate limit key for a request
    /// - Parameter request: The request to get a key for
    /// - Returns: A unique key for rate limiting this request
    private func getRateLimitKey(for request: Request) async throws -> String {
        // For now, just use the client IP
        // In a real app, you might want to include the route, user ID, etc.
        let ip = request.remoteAddress?.ipAddress ?? "unknown"
        return "ratelimit:\(ip)"
    }
}

/// Error thrown when rate limit is exceeded
struct RateLimitExceededError: Error {
    let retryAfter: Int
    let limit: Int
    let remaining: Int
    let reset: Int
    
    static var generic: RateLimitExceededError {
        RateLimitExceededError(retryAfter: 60, limit: 0, remaining: 0, reset: Int(Date().addingTimeInterval(60).timeIntervalSince1970))
    }
}

/// Helper struct for error responses
private struct ErrorResponse: Content {
    let error: Bool
    let reason: String
    let statusCode: UInt
} 