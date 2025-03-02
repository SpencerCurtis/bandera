import Vapor
import Fluent

/// Data Transfer Objects for Users
enum UserDTOs {
    // MARK: - Request DTOs
    
    /// DTO for creating a new user
    struct CreateRequest: Content, Validatable {
        /// User's email address
        let email: String
        
        /// User's password
        let password: String
        
        /// Whether the user should be an admin
        let isAdmin: Bool
        
        /// Validation rules for creating a user
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String.self, is: .count(8...))
        }
    }
    
    /// DTO for updating a user
    struct UpdateRequest: Content, Validatable {
        /// User's email address
        let email: String
        
        /// User's new password (optional)
        let password: String?
        
        /// Whether the user should be an admin
        let isAdmin: Bool
        
        /// Validation rules for updating a user
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String?.self, is: .nil || .count(8...))
        }
    }
    
    // MARK: - Response DTOs
    
    /// DTO for user response
    struct Response: Content {
        /// User's unique identifier
        let id: UUID
        
        /// User's email address
        let email: String
        
        /// Whether the user is an admin
        let isAdmin: Bool
        
        /// When the user was created
        let createdAt: Date?
        
        /// Initialize from a user model
        init(user: User) {
            self.id = user.id!
            self.email = user.email
            self.isAdmin = user.isAdmin
            self.createdAt = user.createdAt
        }
    }
} 