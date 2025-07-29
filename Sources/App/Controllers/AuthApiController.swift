import Vapor
import Fluent
import JWT

/// API-focused authentication controller that returns JSON responses
struct AuthApiController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("api", "auth")
        
        // Public authentication endpoints
        auth.post("register", use: register)
        auth.post("login", use: login)
        auth.post("refresh", use: refreshToken)
        
        // Protected endpoints
        let protected = auth.grouped(JWTAuthMiddleware.api)
        protected.post("logout", use: logout)
        protected.get("me", use: getCurrentUser)
    }
    
    // MARK: - Public API Endpoints
    
    /// Register a new user via API
    @Sendable
    func register(req: Request) async throws -> AuthResponse {
        // Validate request
        try RegisterRequest.validate(content: req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        
        // Use AuthService for business logic
        let authService = req.services.authService
        let authResponse = try await authService.register(registerRequest)
        
        // Create personal organization for the user
        let personalOrgName = "\(registerRequest.email.split(separator: "@").first?.trimmingCharacters(in: .whitespaces) ?? "User")'s Personal Organization"
        let organizationService = req.services.organizationService
        
        // Get the newly created user ID from the auth response
        let userId = authResponse.user.id
        
        let _ = try await organizationService.create(
            CreateOrganizationRequest(name: personalOrgName),
            creatorId: userId
        )
        
        req.logger.info("API: Created personal organization for user \(userId)")
        
        return authResponse
    }
    
    /// Login a user via API
    @Sendable
    func login(req: Request) async throws -> AuthResponse {
        // Validate request
        try LoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(LoginRequest.self)
        
        // Use AuthService for business logic
        let authService = req.services.authService
        return try await authService.login(loginRequest)
    }
    
    /// Refresh JWT token
    @Sendable
    func refreshToken(req: Request) async throws -> TokenResponse {
        // Get current authenticated user
        let user = try req.auth.require(User.self)
        
        // Generate new token
        let authService = req.services.authService
        let newToken = try authService.generateToken(for: user)
        
        return TokenResponse(token: newToken)
    }
    
    // MARK: - Protected API Endpoints
    
    /// Logout (invalidate token on client side)
    @Sendable
    func logout(req: Request) async throws -> MessageResponse {
        // For JWT tokens, logout is typically handled client-side by discarding the token
        // In a more sophisticated setup, you might maintain a token blacklist
        return MessageResponse(message: "Successfully logged out")
    }
    
    /// Get current authenticated user information
    @Sendable
    func getCurrentUser(req: Request) async throws -> UserResponse {
        let user = try req.auth.require(User.self)
        return UserResponse(user: user)
    }
}

// MARK: - Response DTOs

/// Response for token-only operations
struct TokenResponse: Content {
    let token: String
}

/// Response for general messages
struct MessageResponse: Content {
    let message: String
} 