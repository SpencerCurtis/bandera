import Fluent
import Vapor

/// Types of feature flags supported by the application.
/// Each type determines how the flag's value is interpreted.
enum FeatureFlagType: String, Codable {
    /// Boolean flag (true/false)
    case boolean
    
    /// String flag (text value)
    case string
    
    /// Number flag (numeric value)
    case number
    
    /// JSON flag (structured data)
    case json
}

/// Model representing a feature flag in the system.
/// 
/// Feature flags are used to enable or disable features in client applications,
/// or to configure feature behavior with different values. Each flag has a unique
/// key, a type that determines how its value is interpreted, and a default value.
/// Flags can be overridden for specific users.
final class FeatureFlag: Model, Content {
    /// Database schema name for feature flags
    static let schema = "feature_flags"
    
    /// Unique identifier for the feature flag
    @ID(key: .id)
    var id: UUID?
    
    /// Unique key for the feature flag
    /// This is used by client applications to identify the flag
    @Field(key: "key")
    var key: String
    
    /// Type of the feature flag (boolean, string, number, json)
    /// This determines how the flag's value is interpreted
    @Enum(key: "type")
    var type: FeatureFlagType
    
    /// Default value for the feature flag
    /// This is used when no user-specific override exists
    @Field(key: "default_value")
    var defaultValue: String
    
    /// Optional description of the feature flag's purpose
    /// This helps document what the flag is used for
    @Field(key: "description")
    var description: String?
    
    /// User who owns this feature flag
    /// This allows for user-specific feature flags
    @Field(key: "user_id")
    var userId: UUID?
    
    /// When the feature flag was created
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    /// When the feature flag was last updated
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    /// Default initializer required by Fluent
    init() { }
    
    /// Initializer with all properties
    /// 
    /// - Parameters:
    ///   - id: Optional unique identifier
    ///   - key: Unique key for the feature flag
    ///   - type: Type of the feature flag
    ///   - defaultValue: Default value for the feature flag
    ///   - description: Optional description of the feature flag's purpose
    ///   - userId: Optional user who owns this feature flag
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
    /// 
    /// - Parameters:
    ///   - dto: The DTO containing feature flag data
    ///   - userId: The ID of the user creating the flag
    /// - Returns: A new feature flag instance
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
    /// 
    /// - Parameter dto: The DTO containing updated feature flag data
    func update(from dto: FeatureFlagDTOs.UpdateRequest) {
        self.key = dto.key
        self.type = dto.type
        self.defaultValue = dto.defaultValue
        self.description = dto.description
    }
    
    /// Get all feature flags for a user with their overrides
    /// 
    /// This method retrieves all feature flags for a specific user,
    /// including any user-specific overrides that may exist.
    /// 
    /// - Parameters:
    ///   - userId: The ID of the user to get flags for
    ///   - db: The database to query
    /// - Returns: A container with all feature flags and their overrides
    /// - Throws: An error if the database query fails
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