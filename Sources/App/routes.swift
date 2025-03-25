import Vapor
import Fluent

/// Register your application's routes here.
func routes(_ app: Application) throws {
    // Public routes
    app.get { req async throws -> Response in
        // If user is authenticated, redirect to dashboard, otherwise to login
        if req.auth.has(User.self) {
            return req.redirect(to: "/dashboard")
        }
        return req.redirect(to: "/auth/login")
    }
    
    // Convenience redirect from /login to /auth/login
    app.get("login") { req -> Response in
        return req.redirect(to: "/auth/login")
    }
    
    // Register the auth controller
    let authController = AuthController()
    try app.register(collection: authController)
    
    // Apply JWT middleware to all dashboard routes
    let dashboard = app.grouped(["dashboard"])
        .grouped(JWTAuthMiddleware.standard)
    
    // Dashboard home route
    dashboard.get { req async throws -> View in
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get all flags for the user
        let flags = try await req.services.featureFlagService.getAllFlags(userId: user.id!)
        
        // Create view context
        let context = ViewContext(
            title: "Dashboard",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            flags: flags
        )
        
        return try await req.view.render("dashboard", context)
    }
    
    // Feature flag routes under dashboard/feature-flags
    let featureFlagController = FeatureFlagController()
    try dashboard.grouped("feature-flags")
        .register(collection: featureFlagController)
    
    // Organization API routes (separate from dashboard)
    let organizationController = OrganizationController()
    try app.register(collection: organizationController)
    
    // WebSocket routes - these use the API middleware that throws instead of redirects
    let webSocketController = WebSocketController()
    try app.grouped(JWTAuthMiddleware.api)
        .register(collection: webSocketController)
    
    // Error test routes (only in development)
    if app.environment == .development {
        app.get("error") { req -> Response in
            throw Abort(.internalServerError, reason: "Test error")
        }
    }
    
    // Fallback route for 404s
    app.get(.catchall) { req -> Response in
        throw Abort(.notFound)
    }
}
