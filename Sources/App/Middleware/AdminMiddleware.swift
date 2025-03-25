import Vapor

/// Middleware to ensure that only admin users can access protected routes
struct AdminMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Get the authenticated user from the JWT payload
        guard let payload = request.auth.get(UserJWTPayload.self) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Check if the user is an admin
        guard payload.isAdmin else {
            throw AuthenticationError.insufficientPermissions
        }
        
        // If the user is an admin, continue with the request
        return try await next.respond(to: request)
    }
} 