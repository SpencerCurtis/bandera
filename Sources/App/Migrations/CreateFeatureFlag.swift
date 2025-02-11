import Fluent

struct CreateFeatureFlag: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(FeatureFlag.schema)
            .id()
            .field("key", .string, .required)
            .unique(on: "key")
            .field("type", .string, .required)
            .field("default_value", .string, .required)
            .field("description", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(FeatureFlag.schema).delete()
    }
} 