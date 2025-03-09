import Vapor

/// Data Transfer Objects for View Contexts
///
/// This namespace contains all DTOs related to view contexts, which are used
/// to pass data to the Leaf templates for rendering.

// MARK: - Base Context

/// Base context for all views
///
/// This context is used as the base for all views and includes common
/// information like the page title, authentication status, and any
/// error or success messages.
struct BaseViewContext: Content {
    /// Page title
    let title: String
    
    /// Whether the user is authenticated
    let isAuthenticated: Bool
    
    /// Optional error message
    let error: String?
    
    /// Optional recovery suggestion for error
    let recoverySuggestion: String?
    
    /// Optional success message
    let success: String?
    
    /// Initialize with title and authentication status
    /// - Parameters:
    ///   - title: The page title
    ///   - isAuthenticated: Whether the user is authenticated
    ///   - error: Optional error message
    ///   - recoverySuggestion: Optional recovery suggestion for error
    ///   - success: Optional success message
    init(
        title: String,
        isAuthenticated: Bool = false,
        error: String? = nil,
        recoverySuggestion: String? = nil,
        success: String? = nil
    ) {
        self.title = title
        self.isAuthenticated = isAuthenticated
        self.error = error
        self.recoverySuggestion = recoverySuggestion
        self.success = success
    }
}

// MARK: - Dashboard Context

/// Context for the dashboard view
struct DashboardViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Feature flags
    let featureFlags: [FeatureFlagResponse]
    
    /// Initialize with base context and feature flags
    init(
        base: BaseViewContext,
        featureFlags: [FeatureFlagResponse]
    ) {
        self.base = base
        self.featureFlags = featureFlags
    }
}

// MARK: - Login Context

/// Context for the login view
struct LoginViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Initialize with base context
    init(base: BaseViewContext) {
        self.base = base
    }
}

// MARK: - Register Context

/// Context for the register view
struct RegisterViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Initialize with base context
    init(base: BaseViewContext) {
        self.base = base
    }
}

// MARK: - Feature Flag Detail Context

/// Context for the feature flag detail view
struct FeatureFlagDetailViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Feature flag
    let featureFlag: FeatureFlagResponse
    
    /// Initialize with base context and feature flag
    init(
        base: BaseViewContext,
        featureFlag: FeatureFlagResponse
    ) {
        self.base = base
        self.featureFlag = featureFlag
    }
}

// MARK: - Feature Flag Create Context

/// Context for the feature flag create view
struct FeatureFlagCreateViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Initialize with base context
    init(base: BaseViewContext) {
        self.base = base
    }
} 