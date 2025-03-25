import Vapor

// MARK: - Request DTOs

/// DTO for login requests
struct LoginRequest: Content, Validatable {
    /// User's email address
    let email: String
    
    /// User's password
    let password: String
    
    /// Validation rules for login
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: !.empty)
    }
}

/// DTO for registration requests
struct RegisterRequest: Content, Validatable {
    /// User's email address
    let email: String
    
    /// User's password
    let password: String
    
    /// Whether the user should be an admin, defaults to false
    let isAdmin: Bool = false
    
    /// Validation rules for registration
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

// MARK: - Response DTOs

/// DTO for authentication responses
struct AuthResponse: Content {
    /// JWT token for the authenticated user
    let token: String
    
    /// User information
    let user: UserResponse
}

/// DTO for user information in responses
struct UserResponse: Content {
    /// User's unique identifier
    let id: UUID
    
    /// User's email address
    let email: String
    
    /// Whether the user is an admin
    let isAdmin: Bool
    
    /// Initialize from a user model
    init(user: User) {
        self.id = user.id!
        self.email = user.email
        self.isAdmin = user.isAdmin
    }
}

/// Credentials for login
struct LoginCredentials: Content {
    let email: String
    let password: String
}

