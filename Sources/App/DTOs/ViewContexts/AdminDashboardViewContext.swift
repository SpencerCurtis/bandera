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
    
    /// Initialize with admin dashboard data
    /// - Parameters:
    ///   - base: The base context
    ///   - users: List of all users
    ///   - organizations: List of all organizations
    ///   - healthInfo: System health information
    init(
        base: BaseViewContext,
        users: [UserResponse],
        organizations: [OrganizationDTO],
        healthInfo: HealthInfo
    ) {
        self.base = base
        self.users = users
        self.organizations = organizations
        self.healthInfo = healthInfo
    }
} 