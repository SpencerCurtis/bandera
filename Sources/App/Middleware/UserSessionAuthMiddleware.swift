import Vapor

/// Middleware to authenticate users via session
struct UserSessionAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.debug("UserSessionAuthMiddleware: processing request for path \(request.url.path)")
        
        // Check if user is already authenticated
        if request.auth.has(User.self) {
            request.logger.debug("UserSessionAuthMiddleware: User already authenticated in auth container")
            return try await next.respond(to: request)
        }
        
        // Check if user is authenticated via JWT
        if let payload = request.auth.get(UserJWTPayload.self) {
            request.logger.debug("UserSessionAuthMiddleware: Found JWT payload with subject: \(payload.subject.value)")
            
            // Get the user from the database
            if let userId = UUID(payload.subject.value),
               let user = try await request.services.userRepository.get(id: userId) {
                // Authenticate the user
                request.logger.debug("UserSessionAuthMiddleware: Authenticating user from JWT: \(user.email)")
                request.auth.login(user)
                return try await next.respond(to: request)
            } else {
                request.logger.warning("UserSessionAuthMiddleware: Failed to get user from JWT payload subject: \(payload.subject.value)")
            }
        } else {
            request.logger.debug("UserSessionAuthMiddleware: No JWT payload found in auth container")
        }
        
        // Check if user is authenticated via session
        if let userId = request.session.data["user_id"] {
            request.logger.debug("UserSessionAuthMiddleware: Found user_id in session: \(userId)")
            
            if let uuid = UUID(userId),
               let user = try await request.services.userRepository.get(id: uuid) {
                // Authenticate the user
                request.logger.debug("UserSessionAuthMiddleware: Authenticating user from session: \(user.email)")
                request.auth.login(user)
                return try await next.respond(to: request)
            } else {
                request.logger.warning("UserSessionAuthMiddleware: Failed to get user from session user_id: \(userId)")
            }
        } else {
            request.logger.debug("UserSessionAuthMiddleware: No user_id found in session")
        }
        
        // If we reach here, the user is not authenticated - redirect to login
        // Check if it looks like a browser request by checking Accept header
        let isHtmlRequest = request.headers["Accept"].contains { header in 
            header.contains("text/html") 
        }
        
        request.logger.debug("UserSessionAuthMiddleware: Authentication failed, isHtmlRequest: \(isHtmlRequest)")
        
        if isHtmlRequest {
            // For web requests, redirect to login page
            request.logger.debug("UserSessionAuthMiddleware: Redirecting to /login")
            return request.redirect(to: "/login")
        } else {
            // For API requests, return 401 Unauthorized
            request.logger.debug("UserSessionAuthMiddleware: Throwing unauthorized error for API request")
            throw Abort(.unauthorized, reason: "Authentication required")
        }
    }
}

extension User {
    /// Create a session authentication middleware
    static func sessionAuthMiddleware() -> UserSessionAuthMiddleware {
        return UserSessionAuthMiddleware()
    }
} 