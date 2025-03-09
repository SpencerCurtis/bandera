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
        guard let token = request.cookies["bandera-auth-token"]?.string else {
            request.logger.debug("No auth cookie found")
            return false
        }
        
        request.logger.debug("Auth cookie found: \(token.prefix(10))...")
        
        do {
            let payload = try request.application.jwt.signers.verify(token, as: UserJWTPayload.self)
            request.auth.login(payload)
            request.logger.debug("JWT cookie authentication successful: \(payload.subject.value), isAdmin: \(payload.isAdmin)")
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
            throw AuthenticationError.authenticationRequired
        }
        
        // If authentication is optional, continue anyway
        return try await next.respond(to: request)
    }
}

// MARK: - Redirecting Authentication Middleware

/// Authentication middleware that redirects to login page instead of throwing an error
struct RedirectingAuthMiddleware: AsyncMiddleware {
    /// The authentication strategies to try, in order
    private let strategies: [any AuthenticationStrategy]
    
    /// Initialize with the given strategies
    /// - Parameter strategies: The authentication strategies to try, in order
    init(strategies: [any AuthenticationStrategy]) {
        self.strategies = strategies
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
        // Redirect to login page with returnTo parameter
        let currentPath = request.url.path
        let encodedPath = currentPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Only redirect for HTML requests, throw error for API requests
        if request.headers.accept.first?.mediaType == .html || 
           request.headers.accept.first?.mediaType == nil {
            // Use 302 Found instead of 303 See Other for better browser compatibility
            let response = Response(status: .found)
            response.headers.replaceOrAdd(name: .location, value: "/auth/login?returnTo=\(encodedPath)")
            return response
        } else {
            throw AuthenticationError.authenticationRequired
        }
    }
}

// MARK: - Role-Based Authorization Middleware

/// Middleware for checking if a user has admin role
struct RoleAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let payload = request.auth.get(UserJWTPayload.self) else {
            // If this is an HTML request, redirect to login
            if request.headers.accept.first?.mediaType == .html || 
               request.headers.accept.first?.mediaType == nil {
                let currentPath = request.url.path
                let encodedPath = currentPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                // Use 302 Found instead of 303 See Other for better browser compatibility
                let response = Response(status: .found)
                response.headers.replaceOrAdd(name: .location, value: "/auth/login?returnTo=\(encodedPath)")
                return response
            }
            throw AuthenticationError.authenticationRequired
        }
        
        // Check if user is admin
        guard payload.isAdmin else {
            // If this is an HTML request, redirect to dashboard with error
            if request.headers.accept.first?.mediaType == .html || 
               request.headers.accept.first?.mediaType == nil {
                // Use 302 Found instead of 303 See Other for better browser compatibility
                let response = Response(status: .found)
                response.headers.replaceOrAdd(name: .location, value: "/dashboard?error=You%20do%20not%20have%20permission%20to%20access%20this%20resource")
                return response
            }
            throw AuthenticationError.accessDenied
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

// MARK: - Redirecting Auth Middleware Extensions

extension RedirectingAuthMiddleware {
    /// Create a middleware that tries cookie auth then bearer auth and redirects to login if needed
    static var standard: RedirectingAuthMiddleware {
        RedirectingAuthMiddleware(strategies: [
            CookieAuthStrategy(),
            BearerAuthStrategy()
        ])
    }
}

// MARK: - Application Extensions

extension Application {
    /// Register the standard auth middleware
    func registerAuthMiddleware() {
        middleware.use(AuthMiddleware.standard)
    }
} 