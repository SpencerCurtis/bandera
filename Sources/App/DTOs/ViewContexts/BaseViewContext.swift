import Vapor

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
    
    /// Whether the user is an admin
    let isAdmin: Bool
    
    /// The authenticated user
    let user: User?
    
    /// Optional error message
    let errorMessage: String?
    
    /// Optional success message
    let successMessage: String?
    
    /// Optional warning message
    let warningMessage: String?
    
    /// Optional info message
    let infoMessage: String?
    
    /// Initialize with title and authentication status
    /// - Parameters:
    ///   - title: The page title
    ///   - isAuthenticated: Whether the user is authenticated
    ///   - isAdmin: Whether the user is an admin
    ///   - user: The authenticated user
    ///   - errorMessage: Optional error message
    ///   - successMessage: Optional success message
    ///   - warningMessage: Optional warning message
    ///   - infoMessage: Optional info message
    init(
        title: String,
        isAuthenticated: Bool = false,
        isAdmin: Bool = false,
        user: User? = nil,
        errorMessage: String? = nil,
        successMessage: String? = nil,
        warningMessage: String? = nil,
        infoMessage: String? = nil
    ) {
        self.title = title
        self.isAuthenticated = isAuthenticated
        self.isAdmin = isAdmin
        self.user = user
        self.errorMessage = errorMessage
        self.successMessage = successMessage
        self.warningMessage = warningMessage
        self.infoMessage = infoMessage
    }
} 