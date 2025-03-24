import Vapor
import JWT

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
        request.logger.debug("JWTAuthMiddleware: Processing request for path \(request.url.path)")
        
        // Log all cookies for debugging
        let cookieNames = request.cookies.all.keys.joined(separator: ", ")
        request.logger.debug("JWTAuthMiddleware: Request cookies: \(cookieNames)")
        
        // Check for JWT token in cookie
        guard let token = request.cookies["bandera-auth-token"]?.string else {
            request.logger.warning("JWTAuthMiddleware: No 'bandera-auth-token' JWT token found in cookies")
            return try await handleAuthFailure(request)
        }
        
        request.logger.debug("JWTAuthMiddleware: Found JWT token in cookie: \(token.prefix(20))...")
        
        do {
            // Verify and decode the JWT token
            let payload = try request.application.jwt.signers.verify(token, as: UserJWTPayload.self)
            request.logger.debug("JWTAuthMiddleware: Successfully verified JWT token with subject: \(payload.subject.value)")
            
            // If we need admin role, verify it
            if requireAdmin && !payload.isAdmin {
                request.logger.warning("JWTAuthMiddleware: User is not an admin, but admin role is required")
                throw AuthenticationError.insufficientPermissions
            }
            
            // If we have a valid user ID, fetch and login the user
            guard let userId = UUID(payload.subject.value) else {
                request.logger.warning("JWTAuthMiddleware: Invalid user ID in JWT: \(payload.subject.value)")
                return try await handleAuthFailure(request)
            }
            
            request.logger.debug("JWTAuthMiddleware: Parsed valid UUID from subject: \(userId)")
            
            // Try to find the user
            guard let user = try await User.find(userId, on: request.db) else {
                request.logger.warning("JWTAuthMiddleware: User not found for ID: \(userId)")
                // Clear the invalid token
                let response = try await handleAuthFailure(request)
                response.cookies["bandera-auth-token"] = .expired
                return response
            }
            
            request.logger.debug("JWTAuthMiddleware: Found user in database: \(user.email)")
            
            // Login both the payload and user
            request.auth.login(payload)
            request.auth.login(user)
            
            request.logger.debug("JWTAuthMiddleware: Authenticated user and payload in auth container")
            
            // Set session data
            request.session.data["user_id"] = userId.uuidString
            request.session.data["is_admin"] = String(payload.isAdmin)
            request.logger.debug("JWTAuthMiddleware: Set session data: user_id=\(userId.uuidString), is_admin=\(payload.isAdmin)")
            
            request.logger.debug("JWTAuthMiddleware: Authentication successful, continuing to next responder")
            return try await next.respond(to: request)
        } catch let jwtError where jwtError is JWTKit.JWTError {
            request.logger.warning("JWTAuthMiddleware: JWT verification failed with JWT error: \(jwtError)")
            
            // Clear the invalid token
            let response = try await handleAuthFailure(request)
            response.cookies["bandera-auth-token"] = .expired
            request.logger.debug("JWTAuthMiddleware: Cleared invalid token cookie")
            return response
        } catch {
            request.logger.warning("JWTAuthMiddleware: JWT verification failed with error: \(error)")
            
            // Clear the invalid token
            let response = try await handleAuthFailure(request)
            response.cookies["bandera-auth-token"] = .expired
            request.logger.debug("JWTAuthMiddleware: Cleared invalid token cookie")
            return response
        }
    }
    
    private func handleAuthFailure(_ request: Request) async throws -> Response {
        if shouldRedirect {
            // Store the current path to redirect back after login
            let currentPath = request.url.path
            request.logger.warning("JWTAuthMiddleware: Authentication failed, redirecting to login with returnTo=\(currentPath)")
            return request.redirect(to: "/auth/login?returnTo=\(currentPath)")
        } else {
            request.logger.debug("JWTAuthMiddleware: Throwing authentication required error")
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