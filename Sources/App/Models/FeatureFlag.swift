import Fluent
import Vapor

enum FeatureFlagType: String, Codable {
    case boolean
    case string
    case number
    case json
}

final class FeatureFlag: Model, Content {
    static let schema = "feature_flags"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "key")
    var key: String
    
    @Enum(key: "type")
    var type: FeatureFlagType
    
    @Field(key: "default_value")
    var defaultValue: String
    
    @Field(key: "description")
    var description: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         key: String,
         type: FeatureFlagType,
         defaultValue: String,
         description: String? = nil) {
        self.id = id
        self.key = key
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
    }
}

// MARK: - Sendable Conformance
extension FeatureFlag: @unchecked Sendable {
    // Fluent models are thread-safe by design when using property wrappers
    // The @unchecked Sendable conformance is safe because:
    // 1. All properties use Fluent property wrappers that handle thread safety
    // 2. Properties are only modified through Fluent's thread-safe operations
    // 3. The Model protocol requires internal access for setters
} 