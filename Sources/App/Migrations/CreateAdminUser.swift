import Fluent
import Vapor

/// Migration that creates the admin user
struct CreateAdminUser: AsyncMigration {
    /// Prepare creates the admin user
    func prepare(on database: Database) async throws {
        // Generate a password hash for "admin"
        let passwordHash = try Bcrypt.hash("password")
        
        // Create the admin user
        let user = User(
            id: nil,
            email: "admin@example.com",
            passwordHash: passwordHash,
            isAdmin: true
        )
        
        // Save the user to the database
        try await user.save(on: database)
    }
    
    /// Revert removes the admin user
    func revert(on database: Database) async throws {
        try await User.query(on: database)
            .filter(\.$email == "admin@example.com")
            .delete()
    }
} 