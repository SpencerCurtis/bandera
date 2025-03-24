import Fluent

struct CreateUserFeatureFlag: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(UserFeatureFlag.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("feature_flag_id", .uuid, .required, .references(FeatureFlag.schema, "id", onDelete: .cascade))
            .field("value", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "feature_flag_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(UserFeatureFlag.schema).delete()
    }
} 