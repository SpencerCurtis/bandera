import Vapor

#if DEBUG
/// Controller containing test routes that are only available in debug builds
struct TestController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Create a route group for test endpoints
        let test = routes.grouped("_test")
        
        // Add warning about test routes
        test.get { req -> View in
            let context = ViewContext(
                title: "Test Routes",
                isAuthenticated: req.auth.get(UserJWTPayload.self) != nil,
                isAdmin: req.auth.get(UserJWTPayload.self)?.isAdmin ?? false,
                warning: "⚠️ These routes are only available in debug builds and should not be used in production."
            )
            return try await req.view.render("test/index", context)
        }
        
        // MARK: - Error Testing Routes
        
        let errors = test.grouped("errors")
        
        // Test rate limit error
        errors.get("rate-limit") { req -> Response in
            // Create a mock rate limit error
            let error = RateLimitError(
                retryAfter: 180,  // 3 minutes
                limit: 5,
                remaining: 0,
                reset: Int(Date().addingTimeInterval(180).timeIntervalSince1970)
            )
            
            // Create response
            let response = Response(status: .tooManyRequests)
            
            // Add rate limit headers
            response.headers.add(name: "X-RateLimit-Limit", value: "\(error.limit)")
            response.headers.add(name: "X-RateLimit-Remaining", value: "\(error.remaining)")
            response.headers.add(name: "X-RateLimit-Reset", value: "\(error.reset)")
            response.headers.add(name: "Retry-After", value: "\(error.retryAfter)")
            
            // Handle based on Accept header
            if req.headers.accept.first?.mediaType == .json {
                let errorResponse = ErrorResponse(
                    error: true,
                    reason: "Rate limit exceeded. Please try again later.",
                    statusCode: 429
                )
                try response.content.encode(errorResponse)
            } else {
                let retryInMinutes = Int(ceil(Double(error.retryAfter) / 60.0))
                let timeMessage = retryInMinutes <= 1 ? "1 minute" : "\(retryInMinutes) minutes"
                let message = "Too many requests. Please try again in \(timeMessage)."
                req.session.data["error"] = message
                response.headers.replaceOrAdd(name: .location, value: "/error")
            }
            
            return response
        }
        
        // Test generic error
        errors.get("generic") { req -> Response in
            req.session.data["error"] = "This is a test error message"
            return req.redirect(to: "/error")
        }
        
        // Test error with recovery suggestion
        errors.get("with-suggestion") { req -> Response in
            let context = ViewContext(
                title: "Error",
                error: "Test Error with Recovery",
                recoverySuggestion: "This is a test recovery suggestion. You might want to try X, Y, or Z."
            )
            return try await req.view.render("error", context).encodeResponse(for: req)
        }
    }
}

/// Helper struct for error responses (matching the one in RateLimitMiddleware)
private struct ErrorResponse: Content {
    let error: Bool
    let reason: String
    let statusCode: UInt
}
#endif 