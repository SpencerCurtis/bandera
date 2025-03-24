import Vapor

/// A middleware that handles JWT authentication and optional role checking
struct JWTAuthMiddleware: AsyncMiddleware {
    /// Whether to redirect to login page on authentication failure
    let shouldRedirect: Bool
    
    /// Whether admin role is required
    let requireAdmin: Bool
    
    /// Initialize the middleware
    /// - Parameters:
    ///   - shouldRedirect: Whether to redirect to login page on authentication failure
    ///   - requireAdmin: Whether admin role is required
    init(shouldRedirect: Bool = true, requireAdmin: Bool = false) {
        self.shouldRedirect = shouldRedirect
        self.requireAdmin = requireAdmin
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check for JWT token in cookie
        guard let token = request.cookies["bandera-auth-token"]?.string else {
            return try await handleAuthFailure(request)
        }
        
        do {
            // Verify and decode the JWT token
            let payload = try request.application.jwt.signers.verify(token, as: UserJWTPayload.self)
            
            // If we need admin role, verify it
            if requireAdmin && !payload.isAdmin {
                throw AuthenticationError.insufficientPermissions
            }
            
            // If we have a valid user ID, fetch and login the user
            guard let userId = UUID(payload.subject.value) else {
                request.logger.warning("Invalid user ID in JWT: \(payload.subject.value)")
                return try await handleAuthFailure(request)
            }
            
            // Try to find the user
            guard let user = try await User.find(userId, on: request.db) else {
                request.logger.warning("User not found for ID: \(userId)")
                // Clear the invalid token
                let response = try await handleAuthFailure(request)
                response.cookies["bandera-auth-token"] = .expired
                return response
            }
            
            // Login both the payload and user
            request.auth.login(payload)
            request.auth.login(user)
            
            // Set session data
            request.session.data["user_id"] = userId.uuidString
            request.session.data["is_admin"] = String(payload.isAdmin)
            
            return try await next.respond(to: request)
        } catch {
            request.logger.warning("JWT verification failed: \(error)")
            // Clear the invalid token
            let response = try await handleAuthFailure(request)
            response.cookies["bandera-auth-token"] = .expired
            return response
        }
    }
    
    private func handleAuthFailure(_ request: Request) async throws -> Response {
        if shouldRedirect {
            // Store the current path to redirect back after login
            let currentPath = request.url.path
            return request.redirect(to: "/auth/login?returnTo=\(currentPath)")
        } else {
            throw AuthenticationError.authenticationRequired
        }
    }
}

// Convenience extensions
extension JWTAuthMiddleware {
    /// Standard auth middleware that redirects to login
    static var standard: JWTAuthMiddleware {
        JWTAuthMiddleware(shouldRedirect: true, requireAdmin: false)
    }
    
    /// Auth middleware that throws instead of redirecting
    static var api: JWTAuthMiddleware {
        JWTAuthMiddleware(shouldRedirect: false, requireAdmin: false)
    }
    
    /// Auth middleware that requires admin role and redirects
    static var admin: JWTAuthMiddleware {
        JWTAuthMiddleware(shouldRedirect: true, requireAdmin: true)
    }
    
    /// Auth middleware that requires admin role and throws
    static var adminAPI: JWTAuthMiddleware {
        JWTAuthMiddleware(shouldRedirect: false, requireAdmin: true)
    }
} 