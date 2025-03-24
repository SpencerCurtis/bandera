import Vapor

/// Context for rendering views with Leaf
struct ViewContext: Content {
    // Basic page info
    var title: String
    var isAuthenticated: Bool
    var isAdmin: Bool
    
    // Health information
    var environment: String
    var uptime: String
    var databaseConnected: Bool
    var redisConnected: Bool
    var memoryUsage: String
    var lastDeployment: String
    
    // Messages
    var errorMessage: String?
    var successMessage: String?
    var warningMessage: String?
    var infoMessage: String?
    
    // Debug info
    var statusCode: UInt?
    var requestId: String?
    var debugInfo: [String: String]?
    
    // User info
    var user: User?
    var currentUserId: UUID?
    var returnTo: String?
    
    // Feature flags
    var flag: FeatureFlag?
    var flagDetail: FeatureFlagDetailDTO?
    var flags: [FeatureFlag]?
    
    // Users
    var allUsers: [User]?
    var overrides: [UserFeatureFlag]?
    
    // Organizations
    var organizations: [OrganizationWithRoleDTO]?
    var organization: OrganizationDTO?
    var members: [OrganizationMemberDTO]?
    
    // Form state
    var editing: Bool?
    
    // Pagination
    var pagination: Pagination?
    
    init(
        title: String,
        isAuthenticated: Bool = false,
        isAdmin: Bool = false,
        errorMessage: String? = nil,
        successMessage: String? = nil,
        warningMessage: String? = nil,
        infoMessage: String? = nil,
        statusCode: UInt? = nil,
        requestId: String? = nil,
        debugInfo: [String: String]? = nil,
        user: User? = nil,
        currentUserId: UUID? = nil,
        returnTo: String? = nil,
        environment: String = "development",
        uptime: String = "N/A",
        databaseConnected: Bool = true,
        redisConnected: Bool = true,
        memoryUsage: String = "N/A",
        lastDeployment: String = "N/A",
        flag: FeatureFlag? = nil,
        flagDetail: FeatureFlagDetailDTO? = nil,
        flags: [FeatureFlag]? = nil,
        allUsers: [User]? = nil,
        overrides: [UserFeatureFlag]? = nil,
        organizations: [OrganizationWithRoleDTO]? = nil,
        organization: OrganizationDTO? = nil,
        members: [OrganizationMemberDTO]? = nil,
        editing: Bool? = nil,
        pagination: Pagination? = nil
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
        self.flag = flag
        self.flagDetail = flagDetail
        self.flags = flags
        self.allUsers = allUsers
        self.overrides = overrides
        self.organizations = organizations
        self.organization = organization
        self.members = members
        self.editing = editing
        self.pagination = pagination
    }
}

/// Pagination helper for views
struct Pagination: Content {
    var page: Int
    var perPage: Int
    var total: Int
    var totalPages: Int
    var hasNextPage: Bool
    var hasPreviousPage: Bool
    
    init(page: Int, perPage: Int, total: Int) {
        self.page = page
        self.perPage = perPage
        self.total = total
        self.totalPages = Int(ceil(Double(total) / Double(perPage)))
        self.hasNextPage = page < totalPages
        self.hasPreviousPage = page > 1
    }
}

/// Factory methods for ViewContext
extension ViewContext {
    /// Create an error context
    static func error(
        status: UInt,
        reason: String,
        file: String = #file,
        line: UInt = #line
    ) -> ViewContext {
        return ViewContext(
            title: "Error \(status)",
            isAuthenticated: false,
            isAdmin: false,
            errorMessage: reason,
            statusCode: status,
            requestId: UUID().uuidString,
            debugInfo: [
                "file": file,
                "line": "\(line)"
            ]
        )
    }
}

/// Context for feature flag forms
struct FeatureFlagFormContext: Content {
    var title: String
    var isAuthenticated: Bool
    var isAdmin: Bool
    var errorMessage: String?
    var recoverySuggestion: String?
    var successMessage: String?
    var flag: FeatureFlag?
} 