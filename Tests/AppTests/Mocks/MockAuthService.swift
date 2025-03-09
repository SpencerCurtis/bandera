import Vapor
import JWT
@testable import App

/// A mock implementation of AuthServiceProtocol for testing
final class MockAuthService: AuthServiceProtocol {
    // MARK: - Properties
    
    /// The mock user repository
    let userRepository: MockUserRepository
    
    /// The JWT signer for token generation
    let jwtSigner: JWTSigners
    
    /// Tracking of login attempts
    private(set) var loginAttempts: [LoginRequest] = []
    
    /// Tracking of registration attempts
    private(set) var registrationAttempts: [RegisterRequest] = []
    
    /// Tracking of token generation attempts
    private(set) var tokenGenerationAttempts: [User] = []
    
    // MARK: - Initialization
    
    init(userRepository: MockUserRepository, jwtSigner: JWTSigners) {
        self.userRepository = userRepository
        self.jwtSigner = jwtSigner
    }
    
    // MARK: - AuthServiceProtocol
    
    func register(_ dto: RegisterRequest) async throws -> AuthResponse {
        // Record the attempt
        registrationAttempts.append(dto)
        
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
    
    func login(_ dto: LoginRequest) async throws -> AuthResponse {
        // Record the attempt
        loginAttempts.append(dto)
        
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
    
    func generateToken(for user: User) throws -> String {
        // Record the attempt
        tokenGenerationAttempts.append(user)
        
        // Create payload
        let payload = UserJWTPayload(
            subject: .init(value: user.id!.uuidString),
            expiration: .init(value: Date().addingTimeInterval(86400)), // 24 hours
            isAdmin: user.isAdmin
        )
        
        // Sign payload
        return try jwtSigner.sign(payload)
    }
    
    // MARK: - Testing Helpers
    
    /// Reset all recorded data
    func reset() {
        loginAttempts = []
        registrationAttempts = []
        tokenGenerationAttempts = []
    }
} 