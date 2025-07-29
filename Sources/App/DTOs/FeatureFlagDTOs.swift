import Vapor
import Fluent

// MARK: - Request DTOs

/// DTO for creating a new feature flag.
struct CreateFeatureFlagRequest: Content, Validatable {
    let key: String
    let type: FeatureFlagType
    let defaultValue: String
    let description: String?
    let organizationId: UUID?
    
    /// Validation rules for creating a feature flag.
    static func validations(_ validations: inout Validations) {
        validations.add("key", as: String.self, is: !.empty && .alphanumeric && .count(2...50))
        validations.add("defaultValue", as: String.self, is: !.empty)
        // Description validation happens through sanitization in controllers
    }
}

/// DTO for updating an existing feature flag.
struct UpdateFeatureFlagRequest: Content, Validatable {
    var id: UUID?
    let key: String
    let type: FeatureFlagType
    let defaultValue: String
    let description: String?
    
    /// Validation rules for updating a feature flag.
    static func validations(_ validations: inout Validations) {
        validations.add("key", as: String.self, is: !.empty && .alphanumeric && .count(2...50))
        validations.add("defaultValue", as: String.self, is: !.empty)
        // Description validation happens through sanitization in controllers
    }
}

/// DTO for creating a feature flag override.
struct CreateOverrideRequest: Content, Validatable {
    let userId: String
    let value: String
    
    /// Validation rules for creating a feature flag override.
    static func validations(_ validations: inout Validations) {
        validations.add("userId", as: String.self, is: !.empty)
        validations.add("value", as: String.self, is: !.empty)
    }
}

// MARK: - Response DTOs

/// DTO for feature flag response.
struct FeatureFlagResponse: Content {
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
struct FeatureFlagsContainer: Content {
    let flags: [String: FeatureFlagResponse]
    let isEmpty: Bool
    
    init(flags: [String: FeatureFlagResponse]) {
        self.flags = flags
        self.isEmpty = flags.isEmpty
    }
}
