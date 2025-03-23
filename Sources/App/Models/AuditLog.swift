import Fluent
import Vapor

/// Model for tracking feature flag audit logs.
final class AuditLog: Model, Content {
    static let schema = "audit_logs"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "type")
    var type: String
    
    @Field(key: "message")
    var message: String
    
    @Parent(key: "feature_flag_id")
    var featureFlag: FeatureFlag
    
    @Parent(key: "user_id")
    var user: User
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         type: String,
         message: String,
         featureFlagId: UUID,
         userId: UUID) {
        self.id = id
        self.type = type
        self.message = message
        self.$featureFlag.id = featureFlagId
        self.$user.id = userId
    }
}

// MARK: - Migrations
extension AuditLog {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(AuditLog.schema)
                .id()
                .field("type", .string, .required)
                .field("message", .string, .required)
                .field("feature_flag_id", .uuid, .required, .references(FeatureFlag.schema, "id", onDelete: .cascade))
                .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("created_at", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(AuditLog.schema).delete()
        }
    }
}

// MARK: - Sendable Conformance
extension AuditLog: @unchecked Sendable { } 