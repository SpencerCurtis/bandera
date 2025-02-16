import Fluent
import Vapor

struct CreateAdminUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        let adminUser = User(
            email: "admin@example.com",
            passwordHash: try Bcrypt.hash("admin123"),
            isAdmin: true
        )
        try await adminUser.save(on: database)
    }

    func revert(on database: Database) async throws {
        try await User.query(on: database)
            .filter(\.$email == "admin@example.com")
            .delete()
    }
} 