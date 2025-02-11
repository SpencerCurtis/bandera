import Vapor

func routes(_ app: Application) throws {
    // Register auth routes
    try app.register(collection: AuthController())
    
    // Basic health check route
    app.get("health") { req async -> String in
        "OK"
    }
}
