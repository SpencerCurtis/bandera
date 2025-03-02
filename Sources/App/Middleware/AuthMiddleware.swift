import Vapor
import JWT

// MARK: - Authentication Strategy Protocol

/// Protocol defining an authentication strategy
protocol AuthenticationStrategy: Sendable {
    /// Attempt to authenticate a request
    /// - Parameter request: The incoming request
    /// - Returns: Whether authentication was successful
    func authenticate(_ request: Request) async throws -> Bool
}

// MARK: - Authentication Strategies

/// Strategy for authenticating via JWT in cookies
struct CookieAuthStrategy: AuthenticationStrategy {
    func authenticate(_ request: Request) async throws -> Bool {
        guard let token = request.cookies["vapor-auth-token"]?.string else {
            return false
        }
        
        do {
            let payload = try request.application.jwt.signers.verify(token, as: UserJWTPayload.self)
            request.auth.login(payload)
            request.logger.debug("JWT cookie authentication successful: \(payload.subject.value)")
            return true
        } catch {
            request.logger.debug("JWT cookie verification failed: \(error)")
            return false
        }
    }
}

/// Strategy for authenticating via Bearer token in Authorization header
struct BearerAuthStrategy: AuthenticationStrategy {
    func authenticate(_ request: Request) async throws -> Bool {
        guard let token = request.headers.bearerAuthorization?.token else {
            return false
        }
        
        do {
            let payload = try request.jwt.verify(token, as: UserJWTPayload.self)
            request.auth.login(payload)
            request.logger.debug("Bearer token authentication successful: \(payload.subject.value)")
            return true
        } catch {
            request.logger.debug("Bearer token verification failed: \(error)")
            return false
        }
    }
}

// MARK: - Main Authentication Middleware

/// Unified authentication middleware that can use multiple strategies
struct AuthMiddleware: AsyncMiddleware {
    /// The authentication strategies to try, in order
    private let strategies: [any AuthenticationStrategy]
    
    /// Whether to require authentication
    private let requireAuth: Bool
    
    /// Initialize with the given strategies
    /// - Parameters:
    ///   - strategies: The authentication strategies to try, in order
    ///   - requireAuth: Whether to require authentication
    init(strategies: [any AuthenticationStrategy], requireAuth: Bool = true) {
        self.strategies = strategies
        self.requireAuth = requireAuth
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Try each strategy in order
        for strategy in strategies {
            if try await strategy.authenticate(request) {
                // Authentication succeeded with this strategy
                return try await next.respond(to: request)
            }
        }
        
        // If we get here, no strategy succeeded
        if requireAuth {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        
        // If authentication is optional, continue anyway
        return try await next.respond(to: request)
    }
}

// MARK: - Role-Based Authorization Middleware

/// Middleware for checking if a user has admin role
struct RoleAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let payload = request.auth.get(UserJWTPayload.self) else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        
        guard payload.isAdmin else {
            throw Abort(.forbidden, reason: "Admin access required")
        }
        
        return try await next.respond(to: request)
    }
}

// MARK: - Convenience Extensions

extension AuthMiddleware {
    /// Create a middleware that tries cookie auth then bearer auth
    static var standard: AuthMiddleware {
        AuthMiddleware(strategies: [
            CookieAuthStrategy(),
            BearerAuthStrategy()
        ])
    }
    
    /// Create a middleware that tries cookie auth then bearer auth, but doesn't require auth
    static var optional: AuthMiddleware {
        AuthMiddleware(strategies: [
            CookieAuthStrategy(),
            BearerAuthStrategy()
        ], requireAuth: false)
    }
}

// MARK: - Application Extensions

extension Application {
    /// Register the standard auth middleware
    func registerAuthMiddleware() {
        middleware.use(AuthMiddleware.standard)
    }
} 