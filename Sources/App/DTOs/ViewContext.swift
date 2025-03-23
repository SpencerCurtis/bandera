import Vapor

/// View context for rendering templates
struct ViewContext: Content {
    /// Page title
    let title: String
    
    /// Whether the user is authenticated
    var isAuthenticated: Bool = false
    
    /// Whether the user is an admin
    var isAdmin: Bool = false
    
    /// Optional error message
    var error: String?
    
    /// Optional recovery suggestion for error
    var recoverySuggestion: String?
    
    /// Optional success message
    var success: String?
    
    /// Optional warning message
    var warning: String?
    
    /// Optional HTTP status code (for error pages)
    var statusCode: UInt?
    
    /// Optional request ID (for error pages)
    var requestId: String?
    
    /// Optional debug information (for error pages in development)
    var debugInfo: String?
    
    /// Optional return path for redirecting after login
    var returnTo: String?
    
    /// Environment name (for health check)
    var environment: String?
    
    /// System uptime (for health check)
    var uptime: String?
    
    /// Database connection status (for health check)
    var databaseConnected: Bool?
    
    /// Redis connection status (for health check)
    var redisConnected: Bool?
    
    /// Memory usage (for health check)
    var memoryUsage: String?
    
    /// Last deployment time (for health check)
    var lastDeployment: String?
    
    /// Optional feature flag data
    var flag: FeatureFlagDetailDTO?
    
    /// Optional list of feature flags
    var flags: [FeatureFlag]?
    
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
    
    init(
        title: String,
        isAuthenticated: Bool = false,
        isAdmin: Bool = false,
        error: String? = nil,
        recoverySuggestion: String? = nil,
        success: String? = nil,
        warning: String? = nil,
        flag: FeatureFlagDetailDTO? = nil,
        flags: [FeatureFlag]? = nil
    ) {
        self.title = title
        self.isAuthenticated = isAuthenticated
        self.isAdmin = isAdmin
        self.error = error
        self.recoverySuggestion = recoverySuggestion
        self.success = success
        self.warning = warning
        self.flag = flag
        self.flags = flags
    }
}