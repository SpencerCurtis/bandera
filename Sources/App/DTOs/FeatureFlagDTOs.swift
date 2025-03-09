import Vapor
import Fluent

/// Data Transfer Objects for Feature Flags.
enum FeatureFlagDTOs {
    // MARK: - Request DTOs
    
    /// DTO for creating a new feature flag.
    struct CreateRequest: Content, Validatable {
        let key: String
        let type: FeatureFlagType
        let defaultValue: String
        let description: String?
        
        /// Validation rules for creating a feature flag.
        static func validations(_ validations: inout Validations) {
            validations.add("key", as: String.self, is: !.empty && .alphanumeric)
            validations.add("defaultValue", as: String.self, is: !.empty)
        }
    }
    
    /// DTO for updating an existing feature flag.
    struct UpdateRequest: Content, Validatable {
        var id: UUID?
        let key: String
        let type: FeatureFlagType
        let defaultValue: String
        let description: String?
        
        /// Validation rules for updating a feature flag.
        static func validations(_ validations: inout Validations) {
            validations.add("key", as: String.self, is: !.empty && .alphanumeric)
            validations.add("defaultValue", as: String.self, is: !.empty)
        }
    }
    
    // MARK: - Response DTOs
    
    /// DTO for feature flag response.
    struct Response: Content {
        let id: UUID
        let key: String
        let type: FeatureFlagType
        let value: String
        let isOverridden: Bool
        let description: String?
        
        /// Initialize from a feature flag model.
        init(flag: FeatureFlag, value: String? = nil, isOverridden: Bool = false) {
            self.id = flag.id!
            self.key = flag.key
            self.type = flag.type
            self.value = value ?? flag.defaultValue
            self.isOverridden = isOverridden
            self.description = flag.description
        }
    }
    
    /// Container for multiple feature flags.
    struct FlagsContainer: Content {
        let flags: [String: Response]
        let isEmpty: Bool
        
        init(flags: [String: Response]) {
            self.flags = flags
            self.isEmpty = flags.isEmpty
        }
    }
}

// MARK: - Controller Extension
extension FeatureFlagController {
    /// Shorthand access to FeatureFlagDTOs.
    typealias DTOs = FeatureFlagDTOs
}