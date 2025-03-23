import Fluent
import Vapor

/// Model for tracking feature flag enabled/disabled status.
final class FlagStatus: Model, Content {
    static let schema = "flag_statuses"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "feature_flag_id")
    var featureFlag: FeatureFlag
    
    @Field(key: "is_enabled")
    var isEnabled: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil, featureFlagId: UUID, isEnabled: Bool) {
        self.id = id
        self.$featureFlag.id = featureFlagId
        self.isEnabled = isEnabled
    }
}

// MARK: - Migrations
extension FlagStatus {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(FlagStatus.schema)
                .id()
                .field("feature_flag_id", .uuid, .required, .references(FeatureFlag.schema, "id", onDelete: .cascade))
                .field("is_enabled", .bool, .required)
                .field("created_at", .datetime)
                .field("updated_at", .datetime)
                .unique(on: "feature_flag_id")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(FlagStatus.schema).delete()
        }
    }
}

// MARK: - Sendable Conformance
extension FlagStatus: @unchecked Sendable { } 