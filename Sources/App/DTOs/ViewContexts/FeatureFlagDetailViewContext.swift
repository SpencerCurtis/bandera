import Vapor

/// Context for the feature flag detail view
struct FeatureFlagDetailViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Feature flag
    let featureFlag: FeatureFlagResponse
    
    /// Initialize with base context and feature flag
    /// - Parameters:
    ///   - base: The base context
    ///   - featureFlag: The feature flag to display
    init(
        base: BaseViewContext,
        featureFlag: FeatureFlagResponse
    ) {
        self.base = base
        self.featureFlag = featureFlag
    }
} 