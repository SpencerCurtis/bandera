import Vapor
import JWT

struct UserAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let token = request.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing authentication token")
        }
        
        // Verify and decode the JWT
        let payload = try request.jwt.verify(token, as: UserJWTPayload.self)
        
        // Get user ID from payload
        guard let userId = UUID(uuidString: payload.subject.value) else {
            throw Abort(.unauthorized, reason: "Invalid user ID in token")
        }
        
        // Find the user
        guard let user = try await User.find(userId, on: request.db) else {
            throw Abort(.unauthorized, reason: "User not found")
        }
        
        // Store the authenticated user in the request for later use
        request.auth.login(user)
        
        return try await next.respond(to: request)
    }
}

// Middleware specifically for admin routes
struct AdminAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let token = request.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing authentication token")
        }
        
        // Verify and decode the JWT
        let payload = try request.jwt.verify(token, as: UserJWTPayload.self)
        
        // Check if user is admin
        guard payload.isAdmin else {
            throw Abort(.forbidden, reason: "Admin access required")
        }
        
        return try await next.respond(to: request)
    }
} 