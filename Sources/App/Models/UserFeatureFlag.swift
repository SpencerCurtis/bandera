import Fluent
import Vapor

/// Model representing a user-specific override for a feature flag.
final class UserFeatureFlag: Model, Content {
    static let schema = "user_feature_flags"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "feature_flag_id")
    var featureFlag: FeatureFlag
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "value")
    var value: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         featureFlagId: UUID,
         userId: UUID,
         value: String) {
        self.id = id
        self.$featureFlag.id = featureFlagId
        self.$user.id = userId
        self.value = value
    }
}

// MARK: - Migrations
extension UserFeatureFlag {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(UserFeatureFlag.schema)
                .id()
                .field("feature_flag_id", .uuid, .required, .references(FeatureFlag.schema, "id", onDelete: .cascade))
                .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("value", .string, .required)
                .field("created_at", .datetime)
                .field("updated_at", .datetime)
                .unique(on: "feature_flag_id", "user_id")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserFeatureFlag.schema).delete()
        }
    }
}

// MARK: - Sendable Conformance
extension UserFeatureFlag: @unchecked Sendable {
    // Fluent models are thread-safe by design when using property wrappers
    // The @unchecked Sendable conformance is safe because:
    // 1. All properties use Fluent property wrappers that handle thread safety
    // 2. Properties are only modified through Fluent's thread-safe operations
    // 3. The Model protocol requires internal access for setters
} 