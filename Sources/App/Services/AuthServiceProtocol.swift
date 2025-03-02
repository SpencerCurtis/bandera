import Vapor
import JWT

/// Protocol defining the interface for authentication service operations
protocol AuthServiceProtocol {
    /// Register a new user
    /// - Parameter dto: The DTO with user registration data
    /// - Returns: The authentication response with token and user data
    func register(_ dto: AuthenticationDTOs.RegisterRequest) async throws -> AuthenticationDTOs.AuthResponse
    
    /// Login a user
    /// - Parameter dto: The DTO with user login data
    /// - Returns: The authentication response with token and user data
    func login(_ dto: AuthenticationDTOs.LoginRequest) async throws -> AuthenticationDTOs.AuthResponse
    
    /// Generate a JWT token for a user
    /// - Parameter user: The user to generate a token for
    /// - Returns: The generated JWT token
    func generateToken(for user: User) throws -> String
} 