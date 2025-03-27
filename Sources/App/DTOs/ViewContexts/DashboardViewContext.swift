import Vapor

/// Context for the dashboard view
struct DashboardViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Feature flags
    let featureFlags: [FeatureFlagResponse]
    
    /// Organizations the user belongs to
    let organizations: [OrganizationDTO]
    
    /// Initialize with base context and feature flags
    /// - Parameters:
    ///   - base: The base context
    ///   - featureFlags: List of feature flags to display
    ///   - organizations: List of organizations the user belongs to
    init(
        base: BaseViewContext,
        featureFlags: [FeatureFlagResponse],
        organizations: [OrganizationDTO]
    ) {
        self.base = base
        self.featureFlags = featureFlags
        self.organizations = organizations
    }
} 