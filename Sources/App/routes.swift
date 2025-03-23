import Vapor

/// Register your application's routes here.
public func routes(_ app: Application) throws {
    // MARK: - Root Route
    
    // Root route - redirect to dashboard if authenticated, login if not
    app.get { req async throws -> Response in
        if req.auth.has(User.self) {
            return req.redirect(to: "/dashboard")
        } else {
            return req.redirect(to: "/auth/login")
        }
    }
    
    // MARK: - Health Check Routes
    
    // Register health check routes
    try app.register(collection: HealthController())
    
    // MARK: - Authentication Routes
    
    // Register authentication routes (login, register, logout)
    try app.register(collection: AuthController(app: app))
    
    // MARK: - Dashboard Routes
    
    // Register dashboard routes (protected by authentication)
    try app.register(collection: DashboardController())
    
    // MARK: - Feature Flag Routes
    
    // Register feature flag routes (protected by admin role)
    try app.register(collection: FeatureFlagController())
    
    // MARK: - Test Routes
    
    // Register test routes in non-production environments
    #if DEBUG
    try app.register(collection: TestController())
    #endif
}
