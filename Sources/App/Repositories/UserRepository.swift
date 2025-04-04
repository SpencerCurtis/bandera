import Vapor
import Fluent

/// Repository for user data access
/// Implementation of the user repository
struct UserRepository: UserRepositoryProtocol {
    /// The database to use for queries
    let database: Database
    
    /// Initialize a new user repository
    /// - Parameter database: The database to use for queries
    init(database: Database) {
        self.database = database
    }
    
    /// Get a user by ID
    /// - Parameters:
    ///   - id: The unique identifier of the user
    /// - Returns: The user if found, nil otherwise
    func get(id: UUID) async throws -> User? {
        try await User.find(id, on: database)
    }
    
    /// Alias for get(id:) - for better readability
    /// - Parameters:
    ///   - id: The unique identifier of the user  
    /// - Returns: The user if found, nil otherwise
    func getById(_ id: UUID) async throws -> User? {
        try await get(id: id)
    }
    
    /// Get a user by email
    /// - Parameter email: The email of the user
    /// - Returns: The user if found, nil otherwise
    func getByEmail(_ email: String) async throws -> User? {
        try await User.query(on: database)
            .filter(\User.$email == email)
            .first()
    }
    
    /// Check if a user with the given email exists
    /// - Parameter email: The email to check
    /// - Returns: True if a user with the given email exists, false otherwise
    func exists(email: String) async throws -> Bool {
        try await User.query(on: database)
            .filter(\User.$email == email)
            .first() != nil
    }
    
    /// Save a user
    /// - Parameter user: The user to save
    func save(_ user: User) async throws {
        try await user.save(on: database)
    }
    
    /// Delete a user
    /// - Parameter user: The user to delete
    func delete(_ user: User) async throws {
        try await user.delete(on: database)
    }
    
    /// Get all users
    /// - Returns: All users in the system
    func getAllUsers() async throws -> [User] {
        try await User.query(on: database).all()
    }
    
    func findByEmail(_ email: String) async throws -> User? {
        return try await User.query(on: database)
            .filter(\.$email == email)
            .first()
    }
} 