import Vapor

/// Registers all routes for the application.
///
/// This function sets up all the route collections and individual routes for the application.
/// It organizes routes by functionality (auth, feature flags, dashboard, etc.) and
/// registers them with the application.
///
/// - Parameter app: The Vapor application to register routes with
/// - Throws: An error if route registration fails
func routes(_ app: Application) throws {
    // MARK: - Authentication Routes
    
    // Register authentication routes (login, register, logout)
    // These routes handle user authentication and session management
    try app.register(collection: AuthController())
    
    // MARK: - Feature Flag Routes
    
    // Register feature flag routes (CRUD operations)
    // These routes handle feature flag management
    try app.register(collection: FeatureFlagController())
    
    // MARK: - Dashboard Routes
    
    // Register dashboard routes (web interface)
    // These routes provide a web interface for managing feature flags
    try app.register(collection: DashboardController())
    
    // MARK: - WebSocket Routes
    
    // Register WebSocket routes for real-time updates
    // These routes handle WebSocket connections for real-time feature flag updates
    try app.register(collection: WebSocketController())
    
    // MARK: - Routes Page
    
    // Register routes controller for displaying all available routes
    try app.register(collection: RoutesController())
    
    // MARK: - Health Check Route
    
    // Basic health check route for monitoring
    // This route is used to verify that the application is running
    let healthRoute = app.get("health") { req async -> String in
        "OK"
    }
    healthRoute.userInfo["description"] = "Health check endpoint to verify the application is running"
}
