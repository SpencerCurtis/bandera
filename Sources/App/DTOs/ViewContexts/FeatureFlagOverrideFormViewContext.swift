import Vapor

/// Context for the feature flag override form view
struct FeatureFlagOverrideFormViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// The feature flag being overridden
    let flag: FeatureFlagDetailDTO
    
    /// The organization the flag belongs to (nil for personal flags)
    let organization: OrganizationDTO?
    
    /// List of all users that can be selected for the override
    let allUsers: [UserResponse]?
    
    /// Initialize with base context and required data
    /// - Parameters:
    ///   - base: The base context
    ///   - flag: The feature flag being overridden
    ///   - organization: The organization the flag belongs to (nil for personal flags)
    ///   - allUsers: Optional list of all users that can be selected
    init(
        base: BaseViewContext,
        flag: FeatureFlagDetailDTO,
        organization: OrganizationDTO?,
        allUsers: [UserResponse]? = nil
    ) {
        self.base = base
        self.flag = flag
        self.organization = organization
        self.allUsers = allUsers
    }
    
    /// Initialize with a FeatureFlag model
    /// - Parameters:
    ///   - base: The base context
    ///   - flag: The feature flag being overridden
    ///   - organization: The organization the flag belongs to (nil for personal flags)
    ///   - allUsers: Optional list of all users that can be selected
    init(
        base: BaseViewContext,
        flag: FeatureFlag,
        organization: OrganizationDTO?,
        allUsers: [UserResponse]? = nil
    ) {
        self.base = base
        self.flag = FeatureFlagDetailDTO(
            id: flag.id!,
            key: flag.key,
            type: flag.type,
            defaultValue: flag.defaultValue,
            description: flag.description,
            isEnabled: false, // TODO: Get actual enabled status
            createdAt: flag.createdAt,
            updatedAt: flag.updatedAt,
            organizationId: flag.organizationId,
            userOverrides: [],
            auditLogs: []
        )
        self.organization = organization
        self.allUsers = allUsers
    }
} 