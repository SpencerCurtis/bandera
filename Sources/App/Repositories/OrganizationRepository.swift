import Fluent
import Vapor

/// Protocol defining organization repository operations
protocol OrganizationRepositoryProtocol {
    /// Create a new organization
    func create(_ organization: Organization) async throws -> Organization
    
    /// Get an organization by ID
    func find(id: UUID) async throws -> Organization?
    
    /// Get all organizations
    func all() async throws -> [Organization]
    
    /// Update an organization
    func update(_ organization: Organization) async throws
    
    /// Delete an organization
    func delete(_ organization: Organization) async throws
    
    /// Get organizations for a user
    func getForUser(userId: UUID) async throws -> [Organization]
    
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
    
    func all() async throws -> [Organization] {
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
    
    func getMembers(organizationId: UUID) async throws -> [OrganizationUser] {
        try await OrganizationUser.query(on: db)
            .filter(\.$organization.$id, .equal, organizationId)
            .with(\.$user)
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
    func getMembershipsForUser(userId: UUID) async throws -> [OrganizationUser] {
        return try await OrganizationUser.query(on: db)
            .filter(\.$user.$id == userId)
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