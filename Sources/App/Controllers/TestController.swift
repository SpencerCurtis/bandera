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
                warningMessage: "⚠️ These routes are only available in debug builds and should not be used in production.",
                environment: "development",
                uptime: "N/A",
                databaseConnected: true,
                redisConnected: true,
                memoryUsage: "N/A",
                lastDeployment: "N/A"
            )
            return try await req.view.render("test/index", context)
        }
        
        // MARK: - Error Testing Routes
        
        let errors = test.grouped("errors")
        
        // Test rate limit error
        errors.get("rate-limit") { req -> Response in
            // Create a mock rate limit error
            let error = RateLimitExceededError(
                retryAfter: 180,  // 3 minutes
                limit: 5,
                remaining: 0,
                reset: Int(Date().addingTimeInterval(180).timeIntervalSince1970)
            )
            throw error
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
                isAuthenticated: true,
                isAdmin: true,
                errorMessage: "Test Error with Recovery",
                warningMessage: "This is a test recovery suggestion. You might want to try X, Y, or Z.",
                environment: "development",
                uptime: "N/A",
                databaseConnected: true,
                redisConnected: true,
                memoryUsage: "N/A",
                lastDeployment: "N/A"
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