import Vapor
import Fluent

struct ViewContext: Content {
    let title: String
    let isAuthenticated: Bool
    let isAdmin: Bool
    var errorMessage: String?
    var successMessage: String?
    var warningMessage: String?
    var infoMessage: String?
    let statusCode: UInt?
    let requestId: String?
    var debugInfo: String?
    let user: User?
    let currentUserId: UUID?
    let returnTo: String?
    let environment: String
    let uptime: String
    let databaseConnected: Bool
    let redisConnected: Bool
    let memoryUsage: String
    let lastDeployment: String
    let flags: [FeatureFlag]?
    let organizations: [OrganizationDTO]?
    let users: [UserResponse]?
    let organization: OrganizationDTO?
    let members: [UserResponse]?
    let editing: Bool?
    let flag: FeatureFlag?
    
    init(
        title: String,
        isAuthenticated: Bool,
        isAdmin: Bool,
        errorMessage: String? = nil,
        successMessage: String? = nil,
        warningMessage: String? = nil,
        infoMessage: String? = nil,
        statusCode: UInt? = nil,
        requestId: String? = nil,
        debugInfo: String? = nil,
        user: User? = nil,
        currentUserId: UUID? = nil,
        returnTo: String? = nil,
        environment: String = "development",
        uptime: String = "N/A",
        databaseConnected: Bool = true,
        redisConnected: Bool = true,
        memoryUsage: String = "N/A",
        lastDeployment: String = "N/A",
        flags: [FeatureFlag]? = nil,
        organizations: [OrganizationDTO]? = nil,
        users: [UserResponse]? = nil,
        organization: OrganizationDTO? = nil,
        members: [UserResponse]? = nil,
        editing: Bool? = nil,
        flag: FeatureFlag? = nil
    ) {
        self.title = title
        self.isAuthenticated = isAuthenticated
        self.isAdmin = isAdmin
        self.errorMessage = errorMessage
        self.successMessage = successMessage
        self.warningMessage = warningMessage
        self.infoMessage = infoMessage
        self.statusCode = statusCode
        self.requestId = requestId
        self.debugInfo = debugInfo
        self.user = user
        self.currentUserId = currentUserId
        self.returnTo = returnTo
        self.environment = environment
        self.uptime = uptime
        self.databaseConnected = databaseConnected
        self.redisConnected = redisConnected
        self.memoryUsage = memoryUsage
        self.lastDeployment = lastDeployment
        self.flags = flags
        self.organizations = organizations
        self.users = users
        self.organization = organization
        self.members = members
        self.editing = editing
        self.flag = flag
    }

    /// Create an error context
    static func error(
        status: UInt,
        reason: String,
        title: String = "Error",
        isAuthenticated: Bool = true,
        isAdmin: Bool = false,
        user: User? = nil
    ) -> ViewContext {
        ViewContext(
            title: title,
            isAuthenticated: isAuthenticated,
            isAdmin: isAdmin,
            errorMessage: reason,
            statusCode: status,
            user: user,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A"
        )
    }
} 