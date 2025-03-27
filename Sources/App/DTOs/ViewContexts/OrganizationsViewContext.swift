import Vapor

/// Context for the organizations list view
struct OrganizationsViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// List of organizations the user belongs to
    let organizations: [OrganizationDTO]
    
    /// Initialize with organizations list
    /// - Parameters:
    ///   - base: The base context
    ///   - organizations: List of organizations to display
    init(
        base: BaseViewContext,
        organizations: [OrganizationDTO]
    ) {
        self.base = base
        self.organizations = organizations
    }
} 