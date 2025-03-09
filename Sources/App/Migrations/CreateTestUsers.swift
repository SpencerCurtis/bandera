import Fluent
import Vapor

/// Migration to create test users for development
struct CreateTestUsers: AsyncMigration {
    /// The environment in which the application is running
    let environment: Environment
    
    /// Initialize with the application environment
    init(environment: Environment) {
        self.environment = environment
    }
    
    /// Create test users
    func prepare(on database: Database) async throws {
        // Only create test users in development mode
        guard environment == .development else {
            database.logger.notice("Skipping test user creation: not in development environment")
            return
        }
        
        database.logger.notice("Starting test user creation...")
        
        do {
            // Check if admin user already exists
            let existingAdmin = try await User.query(on: database)
                .filter(\.$email == "admin@test.com")
                .first()
            
            if existingAdmin == nil {
                // Create a test admin user
                let adminUser = User(
                    email: "admin@test.com",
                    passwordHash: try Bcrypt.hash("adminpass"),
                    isAdmin: true
                )
                try await adminUser.save(on: database)
                database.logger.notice("Created admin test user: admin@test.com (password: adminpass)")
            } else {
                database.logger.notice("Admin test user already exists, skipping creation")
            }
            
            // Check if regular user already exists
            let existingUser = try await User.query(on: database)
                .filter(\.$email == "user@test.com")
                .first()
            
            if existingUser == nil {
                // Create a test regular user
                let regularUser = User(
                    email: "user@test.com",
                    passwordHash: try Bcrypt.hash("userpass"),
                    isAdmin: false
                )
                try await regularUser.save(on: database)
                database.logger.notice("Created regular test user: user@test.com (password: userpass)")
            } else {
                database.logger.notice("Regular test user already exists, skipping creation")
            }
            
            // Log all users for debugging
            let allUsers = try await User.query(on: database).all()
            database.logger.notice("All users in database: \(allUsers.map { $0.email }.joined(separator: ", "))")
            
        } catch {
            database.logger.error("Error creating test users: \(error)")
            throw error
        }
    }
    
    /// Remove test users
    func revert(on database: Database) async throws {
        // Only remove test users in development mode
        guard environment == .development else {
            return
        }
        
        database.logger.notice("Removing test users...")
        
        // Remove the test admin user
        try await User.query(on: database)
            .filter(\.$email == "admin@test.com")
            .delete()
        
        // Remove the test regular user
        try await User.query(on: database)
            .filter(\.$email == "user@test.com")
            .delete()
        
        database.logger.notice("Test users removed")
    }
} 