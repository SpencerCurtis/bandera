import Vapor
import Fluent

final class FeatureFlagUserOverride: Model, Content {
    static let schema = "feature_flag_user_overrides"
    
    typealias IDValue = UUID
    
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
    
    init(id: UUID? = nil, featureFlagId: UUID, userId: UUID, value: String) {
        self.id = id
        self.$featureFlag.id = featureFlagId
        self.$user.id = userId
        self.value = value
    }
} 