import Vapor
import JWT

/// Service for authentication business logic
struct AuthService: AuthServiceProtocol {
    /// The repository for user data access
    let userRepository: UserRepositoryProtocol
    
    /// The JWT signer for token generation
    let jwtSigner: JWTSigners
    
    /// Initialize a new authentication service
    /// - Parameters:
    ///   - userRepository: The repository for user data access
    ///   - jwtSigner: The JWT signer for token generation
    init(userRepository: UserRepositoryProtocol, jwtSigner: JWTSigners) {
        self.userRepository = userRepository
        self.jwtSigner = jwtSigner
    }
    
    /// Register a new user
    /// - Parameter dto: The DTO with user registration data
    /// - Returns: The authentication response with token and user data
    func register(_ dto: RegisterRequest) async throws -> AuthResponse {
        // Check if user with same email exists
        if try await userRepository.exists(email: dto.email) {
            throw ResourceError.alreadyExists("User with email '\(dto.email)'")
        }
        
        // Create new user
        let user = User(
            email: dto.email,
            passwordHash: try Bcrypt.hash(dto.password),
            isAdmin: dto.isAdmin
        )
        
        // Save user
        try await userRepository.save(user)
        
        // Generate token
        let token = try generateToken(for: user)
        
        // Return response
        return AuthResponse(
            token: token,
            user: UserResponse(user: user)
        )
    }
    
    /// Login a user
    /// - Parameter dto: The DTO with user login data
    /// - Returns: The authentication response with token and user data
    func login(_ dto: LoginRequest) async throws -> AuthResponse {
        // Find user by email
        guard let user = try await userRepository.getByEmail(dto.email) else {
            throw AuthenticationError.invalidCredentials
        }
        
        // Verify password
        guard try user.verify(password: dto.password) else {
            throw AuthenticationError.invalidCredentials
        }
        
        // Generate token
        let token = try generateToken(for: user)
        
        // Return response
        return AuthResponse(
            token: token,
            user: UserResponse(user: user)
        )
    }
    
    /// Generate a JWT token for a user
    /// - Parameter user: The user to generate a token for
    /// - Returns: The generated JWT token
    func generateToken(for user: User) throws -> String {
        // Create payload
        let payload = UserJWTPayload(
            subject: .init(value: user.id!.uuidString),
            expiration: .init(value: Date().addingTimeInterval(7 * 86400)), // 7 days instead of 24 hours
            isAdmin: user.isAdmin
        )
        
        // Sign payload
        return try jwtSigner.sign(payload)
    }
    
    /// Validate that a user has permission to act on behalf of a target user
    /// - Parameters:
    ///   - requestedUserId: The ID of the user to act on behalf of
    ///   - authenticatedUserId: The ID of the authenticated user
    /// - Returns: The validated target user ID
    /// - Throws: AuthenticationError.insufficientPermissions if the user doesn't have permission
    func validateTargetUser(requestedUserId: UUID, authenticatedUserId: UUID) async throws -> UUID {
        // Get the authenticated user
        guard let user = try await userRepository.getById(authenticatedUserId) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Admins can act on behalf of any user
        if user.isAdmin {
            return requestedUserId
        }
        
        // Non-admins can only act on their own behalf
        if requestedUserId == authenticatedUserId {
            return authenticatedUserId
        }
        
        // Otherwise, insufficient permissions
        throw AuthenticationError.insufficientPermissions
    }
} 