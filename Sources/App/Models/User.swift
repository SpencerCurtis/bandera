import Fluent
import Vapor

final class User: Model, Content, SessionAuthenticatable, Authenticatable {
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
    
    // MARK: - SessionAuthenticatable
    var sessionID: String {
        id?.uuidString ?? ""
    }
    
    // MARK: - Password Verification
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

// MARK: - Create DTO
extension User {
    struct Create: Content, Validatable {
        let email: String
        let password: String
        let isAdmin: Bool
        
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String.self, is: .count(8...))
        }
    }
    
    static func create(from dto: Create) throws -> User {
        User(
            email: dto.email,
            passwordHash: try Bcrypt.hash(dto.password),
            isAdmin: dto.isAdmin
        )
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
