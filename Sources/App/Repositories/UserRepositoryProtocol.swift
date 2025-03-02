import Vapor
import Fluent

/// Protocol defining the interface for user repository operations
protocol UserRepositoryProtocol {
    /// Get a user by ID
    /// - Parameters:
    ///   - id: The unique identifier of the user
    /// - Returns: The user if found, nil otherwise
    func get(id: UUID) async throws -> User?
    
    /// Get a user by email
    /// - Parameter email: The email of the user
    /// - Returns: The user if found, nil otherwise
    func getByEmail(_ email: String) async throws -> User?
    
    /// Check if a user with the given email exists
    /// - Parameter email: The email to check
    /// - Returns: True if a user with the given email exists, false otherwise
    func exists(email: String) async throws -> Bool
    
    /// Save a user
    /// - Parameter user: The user to save
    func save(_ user: User) async throws
    
    /// Delete a user
    /// - Parameter user: The user to delete
    func delete(_ user: User) async throws
} 