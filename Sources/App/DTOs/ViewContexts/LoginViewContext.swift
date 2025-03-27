import Vapor

/// Context for the login view
struct LoginViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Optional URL to return to after login
    let returnTo: String?
    
    /// Initialize with base context and optional return URL
    /// - Parameters:
    ///   - base: The base context
    ///   - returnTo: Optional URL to return to after login
    init(
        base: BaseViewContext,
        returnTo: String? = nil
    ) {
        self.base = base
        self.returnTo = returnTo
    }
    
    /// Initialize for a failed login attempt
    /// - Parameters:
    ///   - base: The base context with error message
    ///   - returnTo: Optional URL to return to after login
    static func failedLogin(
        base: BaseViewContext,
        returnTo: String? = nil
    ) -> Self {
        .init(
            base: base,
            returnTo: returnTo
        )
    }
} 