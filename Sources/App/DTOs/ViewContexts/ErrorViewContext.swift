import Vapor

/// Context for error pages
struct ErrorViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// HTTP status code of the error
    let statusCode: UInt?
    
    /// The reason for the error
    let reason: String
    
    /// Optional recovery suggestion
    let recoverySuggestion: String?
    
    /// Optional request ID for tracking
    let requestId: String?
    
    /// Optional debug information (only shown in development)
    let debugInfo: String?
    
    /// Whether to show a return link
    let returnTo: Bool
    
    /// Initialize for a basic error
    /// - Parameters:
    ///   - base: The base context
    ///   - statusCode: Optional HTTP status code
    ///   - reason: The reason for the error
    init(
        base: BaseViewContext,
        statusCode: UInt? = nil,
        reason: String
    ) {
        self.base = base
        self.statusCode = statusCode
        self.reason = reason
        self.recoverySuggestion = nil
        self.requestId = nil
        self.debugInfo = nil
        self.returnTo = true
    }
    
    /// Initialize for a detailed error
    /// - Parameters:
    ///   - base: The base context
    ///   - statusCode: Optional HTTP status code
    ///   - reason: The reason for the error
    ///   - recoverySuggestion: Optional recovery suggestion
    ///   - requestId: Optional request ID for tracking
    ///   - debugInfo: Optional debug information (only shown in development)
    ///   - returnTo: Whether to show a return link
    init(
        base: BaseViewContext,
        statusCode: UInt? = nil,
        reason: String,
        recoverySuggestion: String? = nil,
        requestId: String? = nil,
        debugInfo: String? = nil,
        returnTo: Bool = true
    ) {
        self.base = base
        self.statusCode = statusCode
        self.reason = reason
        self.recoverySuggestion = recoverySuggestion
        self.requestId = requestId
        self.debugInfo = debugInfo
        self.returnTo = returnTo
    }
    
    /// Convenience initializer for 404 errors
    /// - Parameter base: The base context
    static func notFound(base: BaseViewContext) -> Self {
        .init(
            base: base,
            statusCode: 404,
            reason: "The requested page could not be found."
        )
    }
} 