import Vapor

struct ErrorController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let error = routes.grouped("error")
        error.get(use: errorPage)
    }
    
    /// Handler for displaying error page
    @Sendable
    func errorPage(req: Request) async throws -> View {
        // Get error message from session and clear it
        let message = req.session.data["error"] ?? "An error occurred"
        req.session.data["error"] = nil
        
        // Create context with error message
        let context = ViewContext(
            title: "Error",
            isAuthenticated: req.auth.get(UserJWTPayload.self) != nil,
            isAdmin: req.auth.get(UserJWTPayload.self)?.isAdmin ?? false,
            errorMessage: message,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A"
        )
        
        return try await req.view.render("error", context)
    }
} 