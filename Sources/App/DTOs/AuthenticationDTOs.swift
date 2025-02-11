import Vapor

enum AuthenticationDTOs {
    // Request DTOs
    struct LoginRequest: Content {
        let email: String
        let password: String
    }
    
    // Response DTOs
    struct AuthResponse: Content {
        let token: String
        let user: UserResponse
    }
    
    struct UserResponse: Content {
        let id: UUID
        let email: String
        let isAdmin: Bool
        
        init(user: User) {
            self.id = user.id!
            self.email = user.email
            self.isAdmin = user.isAdmin
        }
    }
}

// Extension to make the DTOs easily accessible
extension AuthController {
    typealias DTOs = AuthenticationDTOs
} 