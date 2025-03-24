import Vapor

/// DTO for displaying feature flag details in the UI.
struct FeatureFlagDetailDTO: Content {
    /// The feature flag's unique identifier.
    let id: UUID
    
    /// The feature flag's key.
    let key: String
    
    /// The type of the feature flag.
    let type: FeatureFlagType
    
    /// The default value for the feature flag.
    let defaultValue: String
    
    /// Optional description of the feature flag.
    let description: String?
    
    /// Whether the flag is currently enabled.
    let isEnabled: Bool
    
    /// When the flag was created.
    let createdAt: Date?
    
    /// When the flag was last updated.
    let updatedAt: Date?
    
    /// The organization ID this flag belongs to, if any.
    let organizationId: UUID?
    
    /// User-specific overrides for this flag.
    let userOverrides: [UserOverrideDTO]
    
    /// Audit log entries for this flag.
    let auditLogs: [AuditLogDTO]
    
    /// Organizations the user belongs to (for import functionality)
    var organizations: [OrganizationWithRoleDTO]?
}

/// DTO for user override information.
struct UserOverrideDTO: Content {
    /// The override's unique identifier.
    let id: UUID
    
    /// The user the override is for.
    let user: UserDTO
    
    /// The override value.
    let value: String
    
    /// When the override was last updated.
    let updatedAt: Date?
}

/// DTO for audit log entries.
struct AuditLogDTO: Content {
    /// The type of action performed.
    let type: String
    
    /// Description of what was changed.
    let message: String
    
    /// The user who made the change.
    let user: UserDTO
    
    /// When the change was made.
    let createdAt: Date
}

/// Simplified user DTO for references.
struct UserDTO: Content {
    /// The user's unique identifier.
    let id: UUID
    
    /// The user's email address.
    let email: String
}

// MARK: - Conversions
extension FeatureFlag {
    /// Convert to a detail DTO with related information.
    func toDetailDTO(
        isEnabled: Bool,
        userOverrides: [UserFeatureFlag],
        auditLogs: [AuditLog]
    ) -> FeatureFlagDetailDTO {
        FeatureFlagDetailDTO(
            id: id!,
            key: key,
            type: type,
            defaultValue: defaultValue,
            description: description,
            isEnabled: isEnabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
            organizationId: nil,
            userOverrides: userOverrides.map { $0.toDTO() },
            auditLogs: auditLogs.map { $0.toDTO() },
            organizations: nil
        )
    }
}

extension UserFeatureFlag {
    /// Convert to a user override DTO.
    func toDTO() -> UserOverrideDTO {
        // Create the DTO
        return UserOverrideDTO(
            id: id!,
            user: UserDTO(id: self.$user.id, email: "User \(self.$user.id)"),
            value: value,
            updatedAt: updatedAt
        )
    }
}

extension AuditLog {
    /// Convert to an audit log DTO.
    func toDTO() -> AuditLogDTO {
        AuditLogDTO(
            type: type,
            message: message,
            user: user.toDTO(),
            createdAt: createdAt!
        )
    }
} 