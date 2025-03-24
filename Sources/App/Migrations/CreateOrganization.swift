import Fluent

/// Migration to create the organizations table
struct CreateOrganization: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Organization.schema)
            .id()
            .field("name", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Organization.schema).delete()
    }
} 