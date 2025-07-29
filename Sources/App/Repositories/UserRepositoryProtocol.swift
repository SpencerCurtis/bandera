import Vapor
import Fluent

/// Protocol defining the interface for user repository operations
protocol UserRepositoryProtocol {
    /// Get a user by ID
    /// - Parameters:
    ///   - id: The unique identifier of the user
    /// - Returns: The user if found, nil otherwise
    func get(id: UUID) async throws -> User?
    
    /// Alias for get(id:) - for better readability
    /// - Parameters:
    ///   - id: The unique identifier of the user  
    /// - Returns: The user if found, nil otherwise
    func getById(_ id: UUID) async throws -> User?
    
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
    
    /// Get all users with pagination (recommended default)
    /// - Parameters:
    ///   - params: Pagination parameters
    ///   - baseUrl: Base URL for pagination links
    /// - Returns: Paginated users
    func getAllUsers(params: PaginationParams, baseUrl: String) async throws -> PaginatedResult<User>
    
    /// Get ALL users without pagination
    /// ⚠️ DEPRECATED: Use getAllUsers(params:baseUrl:) instead for better performance
    /// ⚠️ WARNING: Use only for small, bounded datasets or migrations
    /// - Returns: All users in the system (use sparingly!)
    @available(*, deprecated, message: "Use getAllUsers(params:baseUrl:) instead for better performance and safety")
    func getAllUsersUnpaginated() async throws -> [User]
    
    /// Find a user by email
    /// - Parameter email: The email to search for
    /// - Returns: The user if found, nil otherwise
    func findByEmail(_ email: String) async throws -> User?
} 