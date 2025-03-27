import Vapor

/// Context for the organization creation form view
struct OrganizationCreateViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Initialize with base context
    /// - Parameter base: The base context
    init(base: BaseViewContext) {
        self.base = base
    }
}

/// Context for the organization edit form view
struct OrganizationEditViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// The organization being edited
    let organization: OrganizationDTO
    
    /// Initialize with base context and organization
    /// - Parameters:
    ///   - base: The base context
    ///   - organization: The organization being edited
    init(base: BaseViewContext, organization: OrganizationDTO) {
        self.base = base
        self.organization = organization
    }
} 