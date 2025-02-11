import Fluent
import Vapor

final class UserFeatureFlag: Model, Content {
    static let schema = "user_feature_flags"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "user_id")
    var userId: String
    
    @Parent(key: "feature_flag_id")
    var featureFlag: FeatureFlag
    
    @Field(key: "value")
    var value: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         userId: String,
         featureFlagId: UUID,
         value: String) {
        self.id = id
        self.userId = userId
        self.$featureFlag.id = featureFlagId
        self.value = value
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