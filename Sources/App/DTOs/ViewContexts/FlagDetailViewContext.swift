import Vapor

/// Context for the feature flag detail view
struct FlagDetailViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// The feature flag being viewed
    let flag: FeatureFlagDetailDTO
    
    /// Organization context (nil for personal flags)
    let organization: OrganizationDTO?
    
    /// Whether this is a personal flag
    var isPersonal: Bool {
        organization?.isPersonal ?? true
    }
    
    /// Whether the user can edit this flag
    let canEdit: Bool
    
    /// Members who can have overrides (if any)
    let members: [User]?
    
    /// Initialize with flag detail data
    /// - Parameters:
    ///   - base: The base context
    ///   - flag: The feature flag being viewed
    ///   - organization: The organization this flag belongs to (nil for personal flags)
    ///   - canEdit: Whether the user can edit this flag
    ///   - members: Members who can have overrides (if any)
    init(
        base: BaseViewContext,
        flag: FeatureFlagDetailDTO,
        organization: OrganizationDTO? = nil,
        canEdit: Bool,
        members: [User]? = nil
    ) {
        self.base = base
        self.flag = flag
        self.organization = organization
        self.canEdit = canEdit
        self.members = members
    }
} 