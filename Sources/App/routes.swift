import Vapor

func routes(_ app: Application) throws {
    // Register auth routes
    try app.register(collection: AuthController())
    
    // Register feature flag routes
    try app.register(collection: FeatureFlagController())
    
    // Register admin routes
    try app.register(collection: AdminController())
    
    // Register WebSocket routes
    try app.register(collection: WebSocketController())
    
    // Basic health check route
    app.get("health") { req async -> String in
        "OK"
    }
}
