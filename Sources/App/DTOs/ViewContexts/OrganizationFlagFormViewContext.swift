import Vapor

/// Context for the organization flag form view (create/edit)
struct OrganizationFlagFormViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// The organization this flag belongs to (if any)
    let organization: OrganizationDTO?
    
    /// Whether we're editing an existing flag
    let editing: Bool
    
    /// The flag being edited (if editing)
    let flag: FeatureFlagDetailDTO?
    
    /// Available organizations for selection (only when creating a personal flag)
    let organizations: [OrganizationDTO]?
    
    /// Initialize for creating a new flag
    /// - Parameters:
    ///   - base: The base context
    ///   - organization: The organization this flag will belong to (if any)
    ///   - organizations: Available organizations for selection (only when creating a personal flag)
    init(
        base: BaseViewContext,
        organization: OrganizationDTO? = nil,
        organizations: [OrganizationDTO]? = nil
    ) {
        self.base = base
        self.organization = organization
        self.editing = false
        self.flag = nil
        self.organizations = organizations
    }
    
    /// Initialize for editing an existing flag
    /// - Parameters:
    ///   - base: The base context
    ///   - organization: The organization this flag belongs to (if any)
    ///   - flag: The flag being edited
    init(
        base: BaseViewContext,
        organization: OrganizationDTO?,
        flag: FeatureFlagDetailDTO
    ) {
        self.base = base
        self.organization = organization
        self.editing = true
        self.flag = flag
        self.organizations = nil
    }
} 