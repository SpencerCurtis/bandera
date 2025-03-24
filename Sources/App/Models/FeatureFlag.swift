import Fluent
import Vapor

/// Types of feature flags supported by the application.
enum FeatureFlagType: String, Codable {
    case boolean
    case string
    case number
    case json
}

/// Model representing a feature flag in the system.
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
    
    @Field(key: "user_id")
    var userId: UUID?
    
    @Field(key: "organization_id")
    var organizationId: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         key: String,
         type: FeatureFlagType,
         defaultValue: String,
         description: String? = nil,
         userId: UUID? = nil,
         organizationId: UUID? = nil) {
        self.id = id
        self.key = key
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
        self.userId = userId
        self.organizationId = organizationId
    }
}

// MARK: - Helper Methods
extension FeatureFlag {
    /// Create a feature flag from a DTO
    static func create(from dto: CreateFeatureFlagRequest, userId: UUID, organizationId: UUID? = nil) -> FeatureFlag {
        FeatureFlag(
            key: dto.key,
            type: dto.type,
            defaultValue: dto.defaultValue,
            description: dto.description,
            userId: userId,
            organizationId: organizationId
        )
    }
    
    /// Update a feature flag from a DTO
    func update(from dto: UpdateFeatureFlagRequest) {
        self.key = dto.key
        self.type = dto.type
        self.defaultValue = dto.defaultValue
        self.description = dto.description
    }
    
    /// Get all feature flags for a user with their overrides
    static func getUserFlags(userId: String, on db: Database) async throws -> FeatureFlagsContainer {
        guard let uuid = UUID(uuidString: userId) else {
            throw ValidationError.failed("Invalid user ID")
        }
        
        // Get all feature flags for this user
        let flags = try await FeatureFlag.query(on: db)
            .filter(\FeatureFlag.$userId, .equal, uuid)
            .all()
        
        // Get user overrides
        let overrides = try await UserFeatureFlag.query(on: db)
            .filter(\.$user.$id, .equal, uuid)
            .with(\.$featureFlag)
            .all()
        
        // Create response dictionary
        var response: [String: FeatureFlagResponse] = [:]
        
        for flag in flags {
            let override = overrides.first { $0.$featureFlag.id == flag.id }
            response[flag.key] = .init(
                flag: flag,
                value: override?.value,
                isOverridden: override != nil
            )
        }
        
        return FeatureFlagsContainer(flags: response)
    }
    
    /// Get all feature flags for an organization with their overrides
    static func getOrganizationFlags(organizationId: String, on db: Database) async throws -> FeatureFlagsContainer {
        guard let uuid = UUID(uuidString: organizationId) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Get all feature flags for this organization
        let flags = try await FeatureFlag.query(on: db)
            .filter(\FeatureFlag.$organizationId, .equal, uuid)
            .all()
            
        // Create response dictionary
        var response: [String: FeatureFlagResponse] = [:]
        
        for flag in flags {
            response[flag.key] = .init(
                flag: flag,
                value: nil,
                isOverridden: false
            )
        }
        
        return FeatureFlagsContainer(flags: response)
    }
}

// MARK: - Sendable Conformance
extension FeatureFlag: @unchecked Sendable {} 