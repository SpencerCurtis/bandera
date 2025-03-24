import Foundation
import Vapor
import Fluent

/// Container for development-only routes and utilities
struct DevRoutes {
    
    /// Register all development routes
    /// Only call this in development environment
    static func register(to app: Application) {
        // Group all dev routes under /dev
        let devGroup = app.grouped("dev")
        
        // Route to reset any user's password
        devGroup.get("reset-password", ":email") { req -> Response in
            guard let email = req.parameters.get("email") else {
                throw Abort(.badRequest, reason: "Email parameter is required")
            }
            
            let password = req.query[String.self, at: "password"] ?? "password"
            
            // Find the user by email
            guard let user = try await User.query(on: req.db)
                .filter(\.$email == email)
                .first() else {
                throw Abort(.notFound, reason: "User not found with email: \(email)")
            }
            
            // Update the password
            user.passwordHash = try Bcrypt.hash(password)
            try await user.save(on: req.db)
            
            // Return a simple success message
            req.logger.notice("Password for user \(email) has been reset to '\(password)'")
            return Response(status: .ok, body: .init(string: "Password for user \(email) has been reset to '\(password)'"))
        }
        
        // Route to list all users (helpful for development)
        devGroup.get("users") { req -> [UserDevInfo] in
            let users = try await User.query(on: req.db).all()
            return users.map { UserDevInfo(id: $0.id, email: $0.email, isAdmin: $0.isAdmin) }
        }
    }
}

/// Simple struct for returning user info in dev routes
struct UserDevInfo: Content {
    let id: UUID?
    let email: String
    let isAdmin: Bool
} 