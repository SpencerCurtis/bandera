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
        
        // Get recovery suggestion if available
        let suggestion = req.session.data["error_suggestion"]
        req.session.data["error_suggestion"] = nil
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Error",
            isAuthenticated: req.auth.get(UserJWTPayload.self) != nil,
            isAdmin: req.auth.get(UserJWTPayload.self)?.isAdmin ?? false,
            user: try? await User.find(UUID(uuidString: req.auth.get(UserJWTPayload.self)?.subject.value ?? ""), on: req.db),
            errorMessage: message,
            warningMessage: suggestion
        )
        
        // Create error context
        let context = ErrorViewContext(
            base: baseContext,
            statusCode: 500,
            reason: message,
            recoverySuggestion: suggestion,
            returnTo: true
        )
        
        return try await req.view.render("error", context)
    }
} 