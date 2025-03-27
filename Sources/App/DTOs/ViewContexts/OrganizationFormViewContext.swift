import Vapor

/// Context for the organization form view
struct OrganizationFormViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Whether we're editing an existing organization
    let editing: Bool
    
    /// The organization being edited (if editing)
    let organization: OrganizationDTO?
    
    /// Initialize with form data
    /// - Parameters:
    ///   - base: The base context
    ///   - editing: Whether we're editing an existing organization
    ///   - organization: The organization being edited (if editing)
    init(
        base: BaseViewContext,
        editing: Bool = false,
        organization: OrganizationDTO? = nil
    ) {
        self.base = base
        self.editing = editing
        self.organization = organization
    }
} 