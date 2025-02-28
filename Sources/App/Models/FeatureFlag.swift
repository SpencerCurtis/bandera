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
    
    @Field(key: "user_id")
    var userId: UUID?
    
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
         userId: UUID? = nil) {
        self.id = id
        self.key = key
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
        self.userId = userId
    }
}

// MARK: - DTOs
extension FeatureFlag {
    struct Create: Content, Validatable {
        let key: String
        let type: FeatureFlagType
        let defaultValue: String
        let description: String?
        
        static func validations(_ validations: inout Validations) {
            validations.add("key", as: String.self, is: !.empty)
            validations.add("defaultValue", as: String.self, is: !.empty)
        }
    }
    
    struct Update: Content {
        var id: UUID?
        let key: String
        let type: FeatureFlagType
        let defaultValue: String
        let description: String?
    }
    
    struct FlagsContainer: Content {
        let flags: [String: Response]
        let isEmpty: Bool
        
        init(flags: [String: Response]) {
            self.flags = flags
            self.isEmpty = flags.isEmpty
        }
        
        static func getUserFlags(userId: String, on db: Database) async throws -> FlagsContainer {
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
            var response: [String: Response] = [:]
            
            for flag in flags {
                let override = overrides.first { $0.$featureFlag.id == flag.id }
                response[flag.key] = .init(
                    id: flag.id!,
                    key: flag.key,
                    type: flag.type,
                    value: override?.value ?? flag.defaultValue,
                    isOverridden: override != nil,
                    description: flag.description
                )
            }
            
            return FlagsContainer(flags: response)
        }
    }
    
    struct Response: Content {
        let id: UUID
        let key: String
        let type: FeatureFlagType
        let value: String
        let isOverridden: Bool
        let description: String?
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