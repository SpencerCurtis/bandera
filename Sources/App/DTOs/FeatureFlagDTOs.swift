import Vapor
import Fluent

/// Data Transfer Objects for Feature Flags
enum FeatureFlagDTOs {
    // MARK: - Request DTOs
    
    /// DTO for creating a new feature flag
    struct CreateRequest: Content, Validatable {
        /// The unique key for the feature flag
        let key: String
        
        /// The type of the feature flag (boolean, string, number, json)
        let type: FeatureFlagType
        
        /// The default value for the feature flag
        let defaultValue: String
        
        /// Optional description of the feature flag's purpose
        let description: String?
        
        /// Validation rules for creating a feature flag
        static func validations(_ validations: inout Validations) {
            validations.add("key", as: String.self, is: !.empty && .alphanumeric)
            validations.add("defaultValue", as: String.self, is: !.empty)
        }
    }
    
    /// DTO for updating an existing feature flag
    struct UpdateRequest: Content, Validatable {
        /// The unique identifier of the feature flag
        var id: UUID?
        
        /// The unique key for the feature flag
        let key: String
        
        /// The type of the feature flag (boolean, string, number, json)
        let type: FeatureFlagType
        
        /// The default value for the feature flag
        let defaultValue: String
        
        /// Optional description of the feature flag's purpose
        let description: String?
        
        /// Validation rules for updating a feature flag
        static func validations(_ validations: inout Validations) {
            validations.add("key", as: String.self, is: !.empty && .alphanumeric)
            validations.add("defaultValue", as: String.self, is: !.empty)
        }
    }
    
    // MARK: - Response DTOs
    
    /// DTO for feature flag response
    struct Response: Content {
        /// The unique identifier of the feature flag
        let id: UUID
        
        /// The unique key for the feature flag
        let key: String
        
        /// The type of the feature flag
        let type: FeatureFlagType
        
        /// The effective value for the feature flag (may be overridden)
        let value: String
        
        /// Whether the value is overridden from the default
        let isOverridden: Bool
        
        /// Optional description of the feature flag's purpose
        let description: String?
        
        /// Initialize from a feature flag model
        init(flag: FeatureFlag, value: String? = nil, isOverridden: Bool = false) {
            self.id = flag.id!
            self.key = flag.key
            self.type = flag.type
            self.value = value ?? flag.defaultValue
            self.isOverridden = isOverridden
            self.description = flag.description
        }
    }
    
    /// Container for multiple feature flags
    struct FlagsContainer: Content {
        /// Dictionary of feature flags by key
        let flags: [String: Response]
        
        /// Whether the container is empty
        let isEmpty: Bool
        
        /// Initialize with a dictionary of feature flags
        init(flags: [String: Response]) {
            self.flags = flags
            self.isEmpty = flags.isEmpty
        }
    }
}

// MARK: - Controller Extension
extension FeatureFlagController {
    /// Shorthand access to FeatureFlagDTOs
    typealias DTOs = FeatureFlagDTOs
} 