import Vapor

/// Context for the organization flags view
struct OrganizationFlagsViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// The organization whose flags are being displayed
    let organization: OrganizationDTO
    
    /// Whether the current user is an admin of this organization
    let isAdmin: Bool
    
    /// The organization's feature flags
    let flags: [FeatureFlagResponse]
    
    /// Pagination context for flags (optional for backward compatibility)
    let flagsPagination: PaginationContext?
    
    /// Initialize with organization flags data
    /// - Parameters:
    ///   - base: The base context
    ///   - organization: The organization whose flags are being displayed
    ///   - isAdmin: Whether the current user is an admin of this organization
    ///   - flags: The organization's feature flags
    ///   - flagsPagination: Pagination context for flags (optional)
    init(
        base: BaseViewContext,
        organization: OrganizationDTO,
        isAdmin: Bool,
        flags: [FeatureFlag],
        flagsPagination: PaginationContext? = nil
    ) {
        self.base = base
        self.organization = organization
        self.isAdmin = isAdmin
        self.flags = flags.map { FeatureFlagResponse(flag: $0) }
        self.flagsPagination = flagsPagination
    }
} 