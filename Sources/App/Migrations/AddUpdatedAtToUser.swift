import Fluent

struct AddUpdatedAtToUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .field("updated_at", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema(User.schema)
            .deleteField("updated_at")
            .update()
    }
} 