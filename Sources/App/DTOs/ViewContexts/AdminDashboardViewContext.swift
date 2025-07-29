import Vapor

/// Context for the admin dashboard view
struct AdminDashboardViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// System health information
    struct HealthInfo: Content {
        let uptime: String
        let databaseConnected: Bool
        let redisConnected: Bool
        let memoryUsage: String
        let lastDeployment: String
    }
    
    /// List of all users
    let users: [UserResponse]
    
    /// List of all organizations
    let organizations: [OrganizationDTO]
    
    /// System health information
    let healthInfo: HealthInfo
    
    /// Pagination context for users (optional for backward compatibility)
    let usersPagination: PaginationContext?
    
    /// Pagination context for organizations (optional for backward compatibility)
    let organizationsPagination: PaginationContext?
    
    /// Initialize with admin dashboard data
    /// - Parameters:
    ///   - base: The base context
    ///   - users: List of all users
    ///   - organizations: List of all organizations
    ///   - healthInfo: System health information
    ///   - usersPagination: Pagination context for users (optional)
    ///   - organizationsPagination: Pagination context for organizations (optional)
    init(
        base: BaseViewContext,
        users: [UserResponse],
        organizations: [OrganizationDTO],
        healthInfo: HealthInfo,
        usersPagination: PaginationContext? = nil,
        organizationsPagination: PaginationContext? = nil
    ) {
        self.base = base
        self.users = users
        self.organizations = organizations
        self.healthInfo = healthInfo
        self.usersPagination = usersPagination
        self.organizationsPagination = organizationsPagination
    }
} 