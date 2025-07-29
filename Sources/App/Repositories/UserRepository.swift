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
    
    /// Get all users with pagination (recommended default)
    /// - Parameters:
    ///   - params: Pagination parameters
    ///   - baseUrl: Base URL for pagination links
    /// - Returns: Paginated users
    func getAllUsers(params: PaginationParams, baseUrl: String) async throws -> PaginatedResult<User> {
        let query = User.query(on: database)
        return try await PaginationUtilities.paginate(
            query,
            params: params,
            sortBy: \User.$email,
            direction: .ascending,
            baseUrl: baseUrl
        )
    }
    
    /// Get ALL users without pagination
    /// ⚠️ DEPRECATED: Use getAllUsers(params:baseUrl:) instead for better performance
    /// ⚠️ WARNING: Use only for small, bounded datasets or migrations
    /// - Returns: All users in the system (use sparingly!)
    @available(*, deprecated, message: "Use getAllUsers(params:baseUrl:) instead for better performance and safety")
    func getAllUsersUnpaginated() async throws -> [User] {
        // Phase 3: Add safety limit
        let count = try await User.query(on: database).count()
        guard count <= 1000 else {
            throw Abort(.payloadTooLarge, reason: "Dataset too large (\(count) users). Use paginated method instead.")
        }
        return try await User.query(on: database).all()
    }
    
    func findByEmail(_ email: String) async throws -> User? {
        return try await User.query(on: database)
            .filter(\.$email == email)
            .first()
    }
} 