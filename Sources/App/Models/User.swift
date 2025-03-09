import Fluent
import Vapor

/// Model representing a user in the system.
final class User: Model, Content, SessionAuthenticatable, Authenticatable {
    /// Database schema name
    static let schema = "users"
    
    /// Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    /// User's email address
    @Field(key: "email")
    var email: String
    
    /// Hashed password
    @Field(key: "password_hash")
    var passwordHash: String
    
    /// Whether the user is an admin
    @Field(key: "is_admin")
    var isAdmin: Bool
    
    /// When the user was created
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    /// When the user was last updated
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    /// Default initializer
    init() { }
    
    /// Initializer with all properties
    init(id: UUID? = nil, email: String, passwordHash: String, isAdmin: Bool = false) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.isAdmin = isAdmin
    }
    
    // MARK: - SessionAuthenticatable
    
    /// Session identifier
    var sessionID: String {
        id?.uuidString ?? ""
    }
    
    // MARK: - Password Verification
    
    /// Verify a password against the stored hash
    /// - Parameter password: The password to verify
    /// - Returns: Whether the password is valid
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

// MARK: - Helper Methods
extension User {
    /// Create a user from a DTO
    static func create(from dto: CreateUserRequest) throws -> User {
        do {
            return User(
                email: dto.email,
                passwordHash: try Bcrypt.hash(dto.password),
                isAdmin: dto.isAdmin
            )
        } catch {
            throw ServerError.internal("Failed to hash password: \(error.localizedDescription)")
        }
    }
    
    /// Create a user from an authentication DTO
    static func create(from dto: RegisterRequest) throws -> User {
        do {
            return User(
                email: dto.email,
                passwordHash: try Bcrypt.hash(dto.password),
                isAdmin: dto.isAdmin
            )
        } catch {
            throw ServerError.internal("Failed to hash password: \(error.localizedDescription)")
        }
    }
    
    /// Update a user from a DTO
    func update(from dto: UpdateUserRequest) throws {
        self.email = dto.email
        self.isAdmin = dto.isAdmin
        
        if let password = dto.password {
            do {
                self.passwordHash = try Bcrypt.hash(password)
            } catch {
                throw ServerError.internal("Failed to hash password: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Sendable Conformance
extension User: @unchecked Sendable {
    // Fluent models are thread-safe by design when using property wrappers
    // The @unchecked Sendable conformance is safe because:
    // 1. All properties use Fluent property wrappers that handle thread safety
    // 2. Properties are only modified through Fluent's thread-safe operations
    // 3. The Model protocol requires internal access for setters
} 
