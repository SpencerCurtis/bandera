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
    func register(_ dto: AuthenticationDTOs.RegisterRequest) async throws -> AuthenticationDTOs.AuthResponse {
        // Check if user with same email exists
        if try await userRepository.exists(email: dto.email) {
            throw BanderaError.resourceAlreadyExists("User with email '\(dto.email)'")
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
        return AuthenticationDTOs.AuthResponse(
            token: token,
            user: AuthenticationDTOs.UserResponse(user: user)
        )
    }
    
    /// Login a user
    /// - Parameter dto: The DTO with user login data
    /// - Returns: The authentication response with token and user data
    func login(_ dto: AuthenticationDTOs.LoginRequest) async throws -> AuthenticationDTOs.AuthResponse {
        // Find user by email
        guard let user = try await userRepository.getByEmail(dto.email) else {
            throw BanderaError.invalidCredentials
        }
        
        // Verify password
        guard try Bcrypt.verify(dto.password, created: user.passwordHash) else {
            throw BanderaError.invalidCredentials
        }
        
        // Generate token
        let token = try generateToken(for: user)
        
        // Return response
        return AuthenticationDTOs.AuthResponse(
            token: token,
            user: AuthenticationDTOs.UserResponse(user: user)
        )
    }
    
    /// Generate a JWT token for a user
    /// - Parameter user: The user to generate a token for
    /// - Returns: The generated JWT token
    func generateToken(for user: User) throws -> String {
        // Create JWT payload
        let payload = try UserJWTPayload(user: user)
        
        // Sign and return token
        return try jwtSigner.sign(payload)
    }
} 