import Vapor

/// Data Transfer Objects for View Contexts
///
/// This namespace contains all DTOs related to view contexts, which are used
/// to pass data to the Leaf templates for rendering.
enum ViewContextDTOs {
    // MARK: - Base Context
    
    /// Base context for all views
    ///
    /// This context is used as the base for all views and includes common
    /// information like the page title, authentication status, and any
    /// error or success messages.
    struct BaseContext: Content {
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
    struct DashboardContext: Content {
        /// Base context
        let base: BaseContext
        
        /// Feature flags to display
        let flags: [FeatureFlag]
        
        /// Initialize a dashboard context
        init(flags: [FeatureFlag], isAuthenticated: Bool = false, error: String? = nil, success: String? = nil) {
            self.base = BaseContext(
                title: "Dashboard",
                isAuthenticated: isAuthenticated,
                error: error,
                success: success
            )
            self.flags = flags
        }
    }
    
    // MARK: - Feature Flag Form Context
    
    /// Context for the feature flag form view
    struct FeatureFlagFormContext: Content {
        /// Base context
        let base: BaseContext
        
        /// Feature flag to edit (nil for create)
        let flag: FeatureFlag?
        
        /// Initialize for creating a new feature flag
        init(isAuthenticated: Bool = false, error: String? = nil) {
            self.base = BaseContext(
                title: "Create Feature Flag",
                isAuthenticated: isAuthenticated,
                error: error
            )
            self.flag = nil
        }
        
        /// Initialize for editing an existing feature flag
        init(flag: FeatureFlag, isAuthenticated: Bool = false, error: String? = nil) {
            self.base = BaseContext(
                title: "Edit Feature Flag",
                isAuthenticated: isAuthenticated,
                error: error
            )
            self.flag = flag
        }
        
        /// Initialize from a create request
        init(create: FeatureFlagDTOs.CreateRequest, isAuthenticated: Bool = false, error: String? = nil) {
            self.base = BaseContext(
                title: "Create Feature Flag",
                isAuthenticated: isAuthenticated,
                error: error
            )
            self.flag = FeatureFlag(
                key: create.key,
                type: create.type,
                defaultValue: create.defaultValue,
                description: create.description
            )
        }
        
        /// Initialize from an update request
        init(update: FeatureFlagDTOs.UpdateRequest, isAuthenticated: Bool = false, error: String? = nil) {
            self.base = BaseContext(
                title: "Edit Feature Flag",
                isAuthenticated: isAuthenticated,
                error: error
            )
            self.flag = FeatureFlag(
                id: update.id,
                key: update.key,
                type: update.type,
                defaultValue: update.defaultValue,
                description: update.description
            )
        }
    }
    
    // MARK: - Login Context
    
    /// Context for the login view
    struct LoginContext: Content {
        /// Base context
        let base: BaseContext
        
        /// Initialize a login context
        init(error: String? = nil) {
            self.base = BaseContext(
                title: "Login",
                error: error
            )
        }
    }
    
    // MARK: - Error Context
    
    /// Context for the error view
    struct ErrorContext: Content {
        /// Base context
        let base: BaseContext
        
        /// HTTP status code
        let status: Int
        
        /// Error reason
        let reason: String
        
        /// Initialize an error context
        init(status: Int, reason: String, isAuthenticated: Bool = false) {
            self.base = BaseContext(
                title: "Error \(status)",
                isAuthenticated: isAuthenticated,
                error: reason
            )
            self.status = status
            self.reason = reason
        }
    }
} 