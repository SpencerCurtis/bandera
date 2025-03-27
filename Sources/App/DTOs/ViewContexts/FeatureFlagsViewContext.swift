import Vapor

/// Context for the feature flags index page
struct FeatureFlagsViewContext: Content {
    /// Base view context
    let base: BaseViewContext
    
    /// List of feature flags to display
    let flags: [FeatureFlag]
    
    /// Initialize with base context and flags
    init(base: BaseViewContext, flags: [FeatureFlag]) {
        self.base = base
        self.flags = flags
    }
} 