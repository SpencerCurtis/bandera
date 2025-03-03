import Vapor
import Fluent

/// Data Transfer Objects for Feature Flags.
///
/// This namespace contains all DTOs related to feature flags, including
/// request DTOs for creating and updating feature flags, and response DTOs
/// for returning feature flag data to clients.
///
/// DTOs are used to decouple the API contract from the internal model representation,
/// allowing each to evolve independently.
enum FeatureFlagDTOs {
    // MARK: - Request DTOs
    
    /// DTO for creating a new feature flag.
    ///
    /// This DTO is used when a client wants to create a new feature flag.
    /// It includes validation rules to ensure the data is valid before processing.
    struct CreateRequest: Content, Validatable {
        /// The unique key for the feature flag.
        /// Must be alphanumeric and unique within the user's flags.
        let key: String
        
        /// The type of the feature flag (boolean, string, number, json).
        /// Determines how the flag's value is interpreted by clients.
        let type: FeatureFlagType
        
        /// The default value for the feature flag.
        /// This is used when no user-specific override exists.
        let defaultValue: String
        
        /// Optional description of the feature flag's purpose.
        /// Helps document what the flag is used for.
        let description: String?
        
        /// Validation rules for creating a feature flag.
        ///
        /// These rules ensure that:
        /// - The key is not empty and contains only alphanumeric characters
        /// - The default value is not empty
        static func validations(_ validations: inout Validations) {
            validations.add("key", as: String.self, is: !.empty && .alphanumeric)
            validations.add("defaultValue", as: String.self, is: !.empty)
        }
    }
    
    /// DTO for updating an existing feature flag.
    ///
    /// This DTO is used when a client wants to update an existing feature flag.
    /// It includes validation rules to ensure the data is valid before processing.
    struct UpdateRequest: Content, Validatable {
        /// The unique identifier of the feature flag.
        /// This is optional in the request but will be set internally.
        var id: UUID?
        
        /// The unique key for the feature flag.
        /// Must be alphanumeric and unique within the user's flags.
        let key: String
        
        /// The type of the feature flag (boolean, string, number, json).
        /// Determines how the flag's value is interpreted by clients.
        let type: FeatureFlagType
        
        /// The default value for the feature flag.
        /// This is used when no user-specific override exists.
        let defaultValue: String
        
        /// Optional description of the feature flag's purpose.
        /// Helps document what the flag is used for.
        let description: String?
        
        /// Validation rules for updating a feature flag.
        ///
        /// These rules ensure that:
        /// - The key is not empty and contains only alphanumeric characters
        /// - The default value is not empty
        static func validations(_ validations: inout Validations) {
            validations.add("key", as: String.self, is: !.empty && .alphanumeric)
            validations.add("defaultValue", as: String.self, is: !.empty)
        }
    }
    
    // MARK: - Response DTOs
    
    /// DTO for feature flag response.
    ///
    /// This DTO is used when returning feature flag data to clients.
    /// It includes the flag's properties and information about any overrides.
    struct Response: Content {
        /// The unique identifier of the feature flag.
        let id: UUID
        
        /// The unique key for the feature flag.
        let key: String
        
        /// The type of the feature flag.
        let type: FeatureFlagType
        
        /// The effective value for the feature flag (may be overridden).
        /// This is either the default value or an override value if one exists.
        let value: String
        
        /// Whether the value is overridden from the default.
        /// Indicates if this flag has a user-specific override.
        let isOverridden: Bool
        
        /// Optional description of the feature flag's purpose.
        let description: String?
        
        /// Initialize from a feature flag model.
        ///
        /// - Parameters:
        ///   - flag: The feature flag model
        ///   - value: Optional override value
        ///   - isOverridden: Whether the value is overridden
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
    ///
    /// This DTO is used when returning multiple feature flags to clients.
    /// It organizes flags by their keys for easy lookup.
    struct FlagsContainer: Content {
        /// Dictionary of feature flags by key.
        /// This allows clients to easily look up flags by their keys.
        let flags: [String: Response]
        
        /// Whether the container is empty.
        /// Convenience property to check if there are any flags.
        let isEmpty: Bool
        
        /// Initialize with a dictionary of feature flags.
        ///
        /// - Parameter flags: Dictionary of feature flags by key
        init(flags: [String: Response]) {
            self.flags = flags
            self.isEmpty = flags.isEmpty
        }
    }
}

// MARK: - Controller Extension
extension FeatureFlagController {
    /// Shorthand access to FeatureFlagDTOs.
    /// This typealias makes it easier to reference DTOs in the controller.
    typealias DTOs = FeatureFlagDTOs
} 