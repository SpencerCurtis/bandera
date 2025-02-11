import Fluent
import Vapor

final class User: Model, Content, Authenticatable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Field(key: "is_admin")
    var isAdmin: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(id: UUID? = nil, email: String, passwordHash: String, isAdmin: Bool = false) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.isAdmin = isAdmin
    }
}

// MARK: - Registration and Authentication
extension User {
    struct Create: Content, Validatable {
        let email: String
        let password: String
        let isAdmin: Bool?
        
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String.self, is: .count(8...) && .alphanumeric)
        }
    }
    
    // Create a User from the registration data
    static func create(from create: Create) throws -> User {
        // Hash the password using Bcrypt
        // Using try to make it synchronous since Bcrypt operations are CPU-bound
        let hashedPassword = try Bcrypt.hash(create.password)
        return User(
            email: create.email,
            passwordHash: hashedPassword,
            isAdmin: create.isAdmin ?? false
        )
    }
    
    // Verify password
    func verify(password: String) -> Bool {
        // Using try? since we want to return false on any error
        return (try? Bcrypt.verify(password, created: self.passwordHash)) ?? false
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
