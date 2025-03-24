import Vapor
import JWT

/// Protocol defining the interface for authentication service operations
protocol AuthServiceProtocol {
    /// Register a new user
    /// - Parameter dto: The DTO with user registration data
    /// - Returns: The authentication response with token and user data
    func register(_ dto: RegisterRequest) async throws -> AuthResponse
    
    /// Login a user
    /// - Parameter dto: The DTO with user login data
    /// - Returns: The authentication response with token and user data
    func login(_ dto: LoginRequest) async throws -> AuthResponse
    
    /// Generate a JWT token for a user
    /// - Parameter user: The user to generate a token for
    /// - Returns: The generated JWT token
    func generateToken(for user: User) throws -> String
    
    /// Validate that a user has permission to act on behalf of a target user
    /// - Parameters:
    ///   - requestedUserId: The ID of the user to act on behalf of
    ///   - authenticatedUserId: The ID of the authenticated user
    /// - Returns: The validated target user ID
    /// - Throws: AuthenticationError.insufficientPermissions if the user doesn't have permission
    func validateTargetUser(requestedUserId: UUID, authenticatedUserId: UUID) async throws -> UUID
} 