import Vapor

/// Context for the registration view
struct RegisterViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Initialize with base context
    /// - Parameter base: The base context
    init(base: BaseViewContext) {
        self.base = base
    }
    
    /// Initialize for a failed registration attempt
    /// - Parameters:
    ///   - base: The base context with error message
    static func failedRegistration(
        base: BaseViewContext
    ) -> Self {
        .init(base: base)
    }
} 