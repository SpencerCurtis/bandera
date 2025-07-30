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
        
        // Try to get JWT token from multiple sources
        let token: String
        var authSource: String
        
        // First, check Authorization header (standard for REST APIs)
        if let bearerAuth = request.headers.bearerAuthorization {
            token = bearerAuth.token
            authSource = "Authorization header"
            request.logger.debug("JWTAuthMiddleware: Found JWT token in Authorization header: \(token.prefix(20))...")
        } 
        // Fall back to cookie (for web UI)
        else if let cookieToken = request.cookies[AppConstants.authCookieName]?.string {
            token = cookieToken
            authSource = "cookie"
            request.logger.debug("JWTAuthMiddleware: Found JWT token in cookie: \(token.prefix(20))...")
        }
        // No token found anywhere
        else {
            let cookieNames = request.cookies.all.keys.joined(separator: ", ")
            request.logger.warning("JWTAuthMiddleware: No JWT token found in Authorization header or '\(AppConstants.authCookieName)' cookie. Available cookies: \(cookieNames)")
            return try await handleAuthFailure(request)
        }
        
        do {
            // Verify and decode the JWT token
            let payload = try request.application.jwt.signers.verify(token, as: UserJWTPayload.self)
            request.logger.debug("JWTAuthMiddleware: Successfully verified JWT token from \(authSource) with subject: \(payload.subject.value)")
            
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
                // Clear the invalid token (only for cookie-based auth)
                let response = try await handleAuthFailure(request)
                if authSource == "cookie" {
                    response.cookies[AppConstants.authCookieName] = .expired
                }
                return response
            }
            
            request.logger.debug("JWTAuthMiddleware: Found user in database: \(user.email)")
            
            // Login both the payload and user
            request.auth.login(payload)
            request.auth.login(user)
            
            request.logger.debug("JWTAuthMiddleware: Authenticated user and payload in auth container")
            
            // Set session data (useful for web requests, harmless for API requests)
            request.session.data["user_id"] = userId.uuidString
            request.session.data["is_admin"] = String(payload.isAdmin)
            request.logger.debug("JWTAuthMiddleware: Set session data: user_id=\(userId.uuidString), is_admin=\(payload.isAdmin)")
            
            request.logger.debug("JWTAuthMiddleware: Authentication successful via \(authSource), continuing to next responder")
            return try await next.respond(to: request)
        } catch {
            // Always log the error
            request.logger.warning("JWTAuthMiddleware: JWT verification failed with error: \(error)")
            
            // Handle auth failure with proper response based on request type
            let response = try await handleAuthFailure(request)
            
            // Only clear cookie for cookie-based auth
            if authSource == "cookie" {
                response.cookies[AppConstants.authCookieName] = .expired
            }
            
            return response
        }
    }
    
    /// Handles authentication failures when no token is present
    private func handleAuthFailure(_ request: Request) async throws -> Response {
        if shouldRedirect {
            // Store the current path to redirect back after login
            let currentPath = request.url.path
            request.logger.warning("JWTAuthMiddleware: Authentication failed, redirecting to login with returnTo=\(currentPath)")
            
            // Create the response and expire the cookie
            let response = request.redirect(to: "/auth/login?returnTo=\(currentPath)")
            response.cookies[AppConstants.authCookieName] = .expired
            
            return response
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