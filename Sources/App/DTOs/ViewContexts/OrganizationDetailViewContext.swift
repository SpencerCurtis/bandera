import Vapor

/// Context for the organization detail view
struct OrganizationDetailViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// The organization being viewed
    let organization: OrganizationDTO
    
    /// Feature flags for this organization
    let flags: [FeatureFlagResponse]
    
    /// Members of this organization
    let members: [UserResponse]
    
    /// Current user's ID (for member management)
    let currentUserId: UUID
    
    /// Initialize with organization detail data
    /// - Parameters:
    ///   - base: The base context
    ///   - organization: The organization being viewed
    ///   - flags: Feature flags for this organization
    ///   - members: Members of this organization
    ///   - currentUserId: Current user's ID
    init(
        base: BaseViewContext,
        organization: OrganizationDTO,
        flags: [FeatureFlagResponse],
        members: [UserResponse],
        currentUserId: UUID
    ) {
        self.base = base
        self.organization = organization
        self.flags = flags
        self.members = members
        self.currentUserId = currentUserId
    }
} 