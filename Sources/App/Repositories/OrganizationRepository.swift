import Fluent
import Vapor

/// Protocol defining organization repository operations
protocol OrganizationRepositoryProtocol {
    /// Create a new organization
    func create(_ organization: Organization) async throws -> Organization
    
    /// Get an organization by ID
    func find(id: UUID) async throws -> Organization?
    
    /// Get all organizations with pagination (recommended default)
    /// - Parameters:
    ///   - params: Pagination parameters
    ///   - baseUrl: Base URL for pagination links
    /// - Returns: Paginated organizations
    func all(params: PaginationParams, baseUrl: String) async throws -> PaginatedResult<Organization>
    
    /// Get ALL organizations without pagination
    /// ⚠️ DEPRECATED: Use all(params:baseUrl:) instead for better performance
    /// ⚠️ WARNING: Use only for small, bounded datasets or migrations
    /// - Returns: All organizations (use sparingly!)
    @available(*, deprecated, message: "Use all(params:baseUrl:) instead for better performance and safety")
    func allUnpaginated() async throws -> [Organization]
    
    /// Update an organization
    func update(_ organization: Organization) async throws
    
    /// Delete an organization
    func delete(_ organization: Organization) async throws
    
    /// Get organizations for a user
    func getForUser(userId: UUID) async throws -> [Organization]
    
    /// Get organizations for a user with pagination
    /// - Parameters:
    ///   - userId: The unique identifier of the user
    ///   - params: Pagination parameters
    ///   - baseUrl: Base URL for pagination links
    /// - Returns: Paginated organizations for the user
    func getForUser(userId: UUID, params: PaginationParams, baseUrl: String) async throws -> PaginatedResult<Organization>
    
    /// Add a user to an organization
    func addUser(to organizationId: UUID, userId: UUID, role: OrganizationRole) async throws -> OrganizationUser
    
    /// Remove a user from an organization
    func removeUser(from organizationId: UUID, userId: UUID) async throws
    
    /// Get all members of an organization
    func getMembers(organizationId: UUID) async throws -> [OrganizationUser]
    
    /// Check if a user is a member of an organization
    func isMember(userId: UUID, organizationId: UUID) async throws -> Bool
    
    /// Check if a user is an admin of an organization
    func isAdmin(userId: UUID, organizationId: UUID) async throws -> Bool
    
    /// Get all memberships for a user
    func getMembershipsForUser(userId: UUID) async throws -> [OrganizationUser]
    
    /// Get all memberships for an organization
    func getAllMembershipsForOrganization(id: UUID) async throws -> [OrganizationUser]
}

/// Repository for organization-related database operations
struct OrganizationRepository: OrganizationRepositoryProtocol {
    let db: Database
    
    init(db: Database) {
        self.db = db
    }
    
    func create(_ organization: Organization) async throws -> Organization {
        try await organization.create(on: db)
        return organization
    }
    
    func find(id: UUID) async throws -> Organization? {
        try await Organization.find(id, on: db)
    }
    
    func all(params: PaginationParams, baseUrl: String) async throws -> PaginatedResult<Organization> {
        let query = Organization.query(on: db)
        return try await PaginationUtilities.paginate(
            query,
            params: params,
            sortBy: \Organization.$name,
            direction: .ascending,
            baseUrl: baseUrl
        )
    }
    
    @available(*, deprecated, message: "Use all(params:baseUrl:) instead for better performance and safety")
    func allUnpaginated() async throws -> [Organization] {
        try await Organization.query(on: db).all()
    }
    
    func update(_ organization: Organization) async throws {
        try await organization.update(on: db)
    }
    
    func delete(_ organization: Organization) async throws {
        try await organization.delete(on: db)
    }
    
    func getForUser(userId: UUID) async throws -> [Organization] {
        try await OrganizationUser.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .with(\.$organization)
            .all()
            .map { $0.organization }
    }
    
    func getForUser(userId: UUID, params: PaginationParams, baseUrl: String) async throws -> PaginatedResult<Organization> {
        // Get total count first
        let totalItems = try await OrganizationUser.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .count()
        
        // Get paginated memberships with organization data
        let memberships = try await OrganizationUser.query(on: db)
            .filter(\.$user.$id, .equal, userId)
            .with(\.$organization)
            .offset(params.offset)
            .limit(params.perPage)
            .all()
        
        // Extract organizations
        let organizations = memberships.map { $0.organization }
        
        // Create pagination context
        let pagination = PaginationContext(
            currentPage: params.page,
            totalItems: totalItems,
            perPage: params.perPage,
            baseUrl: baseUrl
        )
        
        return PaginatedResult(data: organizations, pagination: pagination)
    }
    
    func addUser(to organizationId: UUID, userId: UUID, role: OrganizationRole) async throws -> OrganizationUser {
        // Check if the user is already a member
        if try await OrganizationUser.query(on: db)
            .filter(\.$organization.$id, .equal, organizationId)
            .filter(\.$user.$id, .equal, userId)
            .first() != nil {
            throw ValidationError.failed("User is already a member of this organization")
        }
        
        // Add the user to the organization
        let membership = OrganizationUser(
            organizationId: organizationId,
            userId: userId,
            role: role
        )
        
        try await membership.create(on: db)
        return membership
    }
    
    func removeUser(from organizationId: UUID, userId: UUID) async throws {
        guard let membership = try await OrganizationUser.query(on: db)
            .filter(\.$organization.$id, .equal, organizationId)
            .filter(\.$user.$id, .equal, userId)
            .first() else {
            throw ValidationError.failed("User is not a member of this organization")
        }
        
        try await membership.delete(on: db)
    }
    
    /// Get all members of an organization
    /// ✅ OPTIMIZED: Uses eager loading to prevent N+1 queries
    func getMembers(organizationId: UUID) async throws -> [OrganizationUser] {
        try await OrganizationUser.query(on: db)
            .filter(\.$organization.$id, .equal, organizationId)
            .with(\.$user)         // ✅ Eager load user relationship
            .with(\.$organization) // ✅ Eager load organization relationship
            .all()
    }
    
    func isMember(userId: UUID, organizationId: UUID) async throws -> Bool {
        try await OrganizationUser.query(on: db)
            .filter(\.$organization.$id, .equal, organizationId)
            .filter(\.$user.$id, .equal, userId)
            .first() != nil
    }
    
    func isAdmin(userId: UUID, organizationId: UUID) async throws -> Bool {
        guard let membership = try await OrganizationUser.query(on: db)
            .filter(\.$organization.$id, .equal, organizationId)
            .filter(\.$user.$id, .equal, userId)
            .first() else {
            return false
        }
        
        return membership.role == .admin
    }
    
    /// Get all memberships for a user
    /// ✅ OPTIMIZED: Uses eager loading to prevent N+1 queries
    func getMembershipsForUser(userId: UUID) async throws -> [OrganizationUser] {
        return try await OrganizationUser.query(on: db)
            .filter(\.$user.$id == userId)
            .with(\.$organization)  // ✅ Eager load organization relationship
            .with(\.$user)         // ✅ Eager load user relationship
            .all()
    }
    
    /// Get all memberships for an organization
    func getAllMembershipsForOrganization(id: UUID) async throws -> [OrganizationUser] {
        return try await OrganizationUser.query(on: db)
            .filter(\.$organization.$id == id)
            .with(\.$user)
            .all()
    }
} 