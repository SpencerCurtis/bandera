import Vapor

/// Unified context for feature flag detail view
struct UnifiedFlagDetailContext: Content {
    /// Basic view context
    var title: String
    var isAuthenticated: Bool
    var canEdit: Bool
    
    /// Flag details
    var flag: FeatureFlagDetailDTO
    
    /// Organization context (nil for personal flags)
    var organization: OrganizationDTO?
    
    /// User overrides
    var members: [User]?
    var overrides: [UserOverrideDTO]
    
    /// Audit logs
    var auditLogs: [AuditLogDTO]
    
    /// System info (optional)
    var environment: String?
    var uptime: String?
    var databaseConnected: Bool?
    var redisConnected: Bool?
    var memoryUsage: String?
    var lastDeployment: String?
    
    /// Whether this is a personal flag (derived from flag.isPersonal)
    var isPersonal: Bool {
        flag.isPersonal
    }
    
    /// Initialize for a personal flag
    static func personal(
        flag: FeatureFlagDetailDTO,
        canEdit: Bool,
        members: [User]? = nil
    ) -> UnifiedFlagDetailContext {
        UnifiedFlagDetailContext(
            title: "Feature Flag: \(flag.key)",
            isAuthenticated: true,
            canEdit: canEdit,
            flag: flag,
            organization: nil,
            members: members,
            overrides: flag.userOverrides,
            auditLogs: flag.auditLogs
        )
    }
    
    /// Initialize for an organization flag
    static func organizational(
        flag: FeatureFlagDetailDTO,
        organization: OrganizationDTO,
        canEdit: Bool,
        members: [User]? = nil
    ) -> UnifiedFlagDetailContext {
        UnifiedFlagDetailContext(
            title: "Feature Flag: \(flag.key)",
            isAuthenticated: true,
            canEdit: canEdit,
            flag: flag,
            organization: organization,
            members: members,
            overrides: flag.userOverrides,
            auditLogs: flag.auditLogs
        )
    }
} 