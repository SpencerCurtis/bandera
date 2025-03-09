import Vapor
import Fluent
@testable import App

/// A mock implementation of UserRepositoryProtocol for testing
final class MockUserRepository: UserRepositoryProtocol {
    // MARK: - Properties
    
    /// Users stored in the mock repository
    private var users: [UUID: User] = [:]
    
    /// Email to user mapping for quick lookups
    private var emailToUser: [String: User] = [:]
    
    // MARK: - UserRepositoryProtocol
    
    func get(id: UUID) async throws -> User? {
        return users[id]
    }
    
    func getByEmail(_ email: String) async throws -> User? {
        return emailToUser[email]
    }
    
    func exists(email: String) async throws -> Bool {
        return emailToUser[email] != nil
    }
    
    func save(_ user: User) async throws {
        // Generate an ID if one doesn't exist
        if user.id == nil {
            user.id = UUID()
        }
        
        // Store the user
        users[user.id!] = user
        emailToUser[user.email] = user
    }
    
    func delete(_ user: User) async throws {
        guard let id = user.id else { return }
        
        // Remove the user
        users.removeValue(forKey: id)
        emailToUser.removeValue(forKey: user.email)
    }
    
    // MARK: - Testing Helpers
    
    /// Reset all stored users
    func reset() {
        users = [:]
        emailToUser = [:]
    }
    
    /// Add a test user
    /// - Parameters:
    ///   - email: The user's email
    ///   - password: The user's password (will be hashed)
    ///   - isAdmin: Whether the user is an admin
    /// - Returns: The created user
    @discardableResult
    func addTestUser(email: String, password: String, isAdmin: Bool = false) throws -> User {
        let user = User(
            id: UUID(),
            email: email,
            passwordHash: try Bcrypt.hash(password),
            isAdmin: isAdmin
        )
        
        users[user.id!] = user
        emailToUser[user.email] = user
        
        return user
    }
} 