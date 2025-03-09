import Vapor

/// View context for rendering templates
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