import Vapor

/// View context for rendering templates
///
/// This struct provides a convenient way to create view contexts for
/// different types of views, including error pages.
struct ViewContext: Content {
    /// Page title
    let title: String
    
    /// Whether the user is authenticated
    var isAuthenticated: Bool = false
    
    /// Optional error message
    var error: String?
    
    /// Optional recovery suggestion for error
    var recoverySuggestion: String?
    
    /// Optional success message
    var success: String?
    
    /// Optional HTTP status code (for error pages)
    var statusCode: UInt?
    
    /// Optional request ID (for error pages)
    var requestId: String?
    
    /// Optional debug information (for error pages in development)
    var debugInfo: String?
    
    /// Create a context for an error page
    /// - Parameters:
    ///   - status: The HTTP status code
    ///   - reason: The error message
    ///   - suggestion: Optional recovery suggestion
    ///   - requestId: Optional request ID for tracking
    /// - Returns: A view context for the error page
    static func error(
        status: UInt,
        reason: String,
        suggestion: String? = nil,
        requestId: String? = nil
    ) -> ViewContext {
        var context = ViewContext(title: "Error \(status)")
        context.error = reason
        context.recoverySuggestion = suggestion
        context.statusCode = status
        context.requestId = requestId
        return context
    }
}

// MARK: - Legacy View Contexts (Deprecated)

@available(*, deprecated, message: "Use ViewContext instead")
typealias LegacyViewContext = ViewContextDTOs.BaseContext

@available(*, deprecated, message: "Use ViewContextDTOs.DashboardContext instead")
typealias DashboardContext = ViewContextDTOs.DashboardContext

@available(*, deprecated, message: "Use ViewContextDTOs.FeatureFlagFormContext instead")
typealias FeatureFlagFormContext = ViewContextDTOs.FeatureFlagFormContext 