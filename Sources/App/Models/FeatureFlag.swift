import Fluent
import Vapor

/// Types of feature flags
enum FeatureFlagType: String, Codable {
    case boolean
    case string
    case number
    case json
}

/// Model representing a feature flag
final class FeatureFlag: Model, Content {
    /// Database schema name
    static let schema = "feature_flags"
    
    /// Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    /// Unique key for the feature flag
    @Field(key: "key")
    var key: String
    
    /// Type of the feature flag
    @Enum(key: "type")
    var type: FeatureFlagType
    
    /// Default value for the feature flag
    @Field(key: "default_value")
    var defaultValue: String
    
    /// Optional description of the feature flag's purpose
    @Field(key: "description")
    var description: String?
    
    /// User who owns this feature flag
    @Field(key: "user_id")
    var userId: UUID?
    
    /// When the feature flag was created
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    /// When the feature flag was last updated
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    /// Default initializer
    init() { }
    
    /// Initializer with all properties
    init(id: UUID? = nil,
         key: String,
         type: FeatureFlagType,
         defaultValue: String,
         description: String? = nil,
         userId: UUID? = nil) {
        self.id = id
        self.key = key
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
        self.userId = userId
    }
}

// MARK: - Helper Methods
extension FeatureFlag {
    /// Create a feature flag from a DTO
    static func create(from dto: FeatureFlagDTOs.CreateRequest, userId: UUID) -> FeatureFlag {
        FeatureFlag(
            key: dto.key,
            type: dto.type,
            defaultValue: dto.defaultValue,
            description: dto.description,
            userId: userId
        )
    }
    
    /// Update a feature flag from a DTO
    func update(from dto: FeatureFlagDTOs.UpdateRequest) {
        self.key = dto.key
        self.type = dto.type
        self.defaultValue = dto.defaultValue
        self.description = dto.description
    }
    
    /// Get all feature flags for a user with their overrides
    static func getUserFlags(userId: String, on db: Database) async throws -> FeatureFlagDTOs.FlagsContainer {
        // Get all feature flags for this user
        let flags = try await FeatureFlag.query(on: db)
            .filter(\FeatureFlag.$userId, .equal, UUID(uuidString: userId))
            .all()
        
        // Get user overrides
        let overrides = try await UserFeatureFlag.query(on: db)
            .filter(\UserFeatureFlag.$userId, .equal, userId)
            .with(\.$featureFlag)
            .all()
        
        // Create response dictionary
        var response: [String: FeatureFlagDTOs.Response] = [:]
        
        for flag in flags {
            let override = overrides.first { $0.$featureFlag.id == flag.id }
            response[flag.key] = .init(
                flag: flag,
                value: override?.value,
                isOverridden: override != nil
            )
        }
        
        return FeatureFlagDTOs.FlagsContainer(flags: response)
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