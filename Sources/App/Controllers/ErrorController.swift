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
        
        // Use standardized error context creation
        let error = Abort(.internalServerError, reason: message, suggestedFixes: suggestion != nil ? [suggestion!] : [])
        let context = await ErrorHandling.createErrorViewContext(
            for: req,
            error: error,
            statusCode: 500,
            returnTo: true,
            title: "Error"
        )
        
        return try await req.view.render("error", context)
    }
} 