import Fluent
import Vapor

/// Protocol defining organization service operations
protocol OrganizationServiceProtocol {
    /// Create a new organization
    func create(_ dto: CreateOrganizationRequest, creatorId: UUID) async throws -> Organization
    
    /// Get an organization by ID
    func get(id: UUID) async throws -> Organization
    
    /// Update an organization
    func update(id: UUID, dto: UpdateOrganizationRequest) async throws -> Organization
    
    /// Delete an organization
    func delete(id: UUID) async throws
    
    /// Get all organizations for a user
    func getForUser(userId: UUID) async throws -> [OrganizationWithRoleDTO]
    
    /// Add a user to an organization
    func addUser(organizationId: UUID, dto: AddUserToOrganizationRequest, requesterId: UUID) async throws -> OrganizationMembershipDTO
    
    /// Remove a user from an organization
    func removeUser(organizationId: UUID, userId: UUID, requesterId: UUID) async throws
    
    /// Get all members of an organization
    func getMembers(organizationId: UUID, requesterId: UUID) async throws -> [OrganizationMemberDTO]
    
    /// Get organization with all its members
    func getWithMembers(id: UUID, requesterId: UUID) async throws -> OrganizationWithMembersDTO
    
    /// Update a user's role in an organization
    func updateUserRole(to organizationId: UUID, userId: UUID, role: OrganizationRole) async throws -> OrganizationUser
    
    /// Create an OrganizationDTO from an Organization
    func createOrganizationDTO(from organization: Organization) -> OrganizationDTO
}

/// Service for organization-related operations
struct OrganizationService: OrganizationServiceProtocol {
    let organizationRepository: OrganizationRepositoryProtocol
    let userRepository: UserRepositoryProtocol
    
    init(organizationRepository: OrganizationRepositoryProtocol, userRepository: UserRepositoryProtocol) {
        self.organizationRepository = organizationRepository
        self.userRepository = userRepository
    }
    
    func create(_ dto: CreateOrganizationRequest, creatorId: UUID) async throws -> Organization {
        // Create the organization
        let organization = Organization.create(from: dto)
        let created = try await organizationRepository.create(organization)
        
        // Add the creator as an admin
        _ = try await organizationRepository.addUser(
            to: created.id!,
            userId: creatorId,
            role: .admin
        )
        
        return created
    }
    
    func get(id: UUID) async throws -> Organization {
        guard let organization = try await organizationRepository.find(id: id) else {
            throw NotFoundError.organization(id)
        }
        
        return organization
    }
    
    func update(id: UUID, dto: UpdateOrganizationRequest) async throws -> Organization {
        guard let organization = try await organizationRepository.find(id: id) else {
            throw NotFoundError.organization(id)
        }
        
        organization.update(from: dto)
        try await organizationRepository.update(organization)
        
        return organization
    }
    
    func delete(id: UUID) async throws {
        guard let organization = try await organizationRepository.find(id: id) else {
            throw NotFoundError.organization(id)
        }
        
        try await organizationRepository.delete(organization)
    }
    
    func getForUser(userId: UUID) async throws -> [OrganizationWithRoleDTO] {
        // Debug logging
        print("Getting organizations for user ID: \(userId)")
        
        // Get all memberships for the user
        let memberships = try await organizationRepository.getMembershipsForUser(userId: userId)
        
        // More debug logging
        print("Found \(memberships.count) memberships for user \(userId)")
        for membership in memberships {
            print("Organization membership: orgId=\(membership.$organization.id), role=\(membership.role)")
        }
        
        // Convert to DTOs with role information
        let organizations = try await memberships.asyncMap { membership in
            let organization = try await get(id: membership.$organization.id)
            return OrganizationWithRoleDTO(organization: organization, role: membership.role)
        }
        
        // Final debug logging
        print("Returning \(organizations.count) organizations for user \(userId)")
        for org in organizations {
            print("Organization DTO: id=\(org.id), name=\(org.name), role=\(org.role)")
        }
        
        return organizations
    }
    
    func addUser(organizationId: UUID, dto: AddUserToOrganizationRequest, requesterId: UUID) async throws -> OrganizationMembershipDTO {
        // Check if requester is an admin of the organization
        if !(try await organizationRepository.isAdmin(userId: requesterId, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to add users to this organization")
        }
        
        // Add the user
        let membership = try await organizationRepository.addUser(
            to: organizationId,
            userId: dto.userId,
            role: dto.role
        )
        
        return try await membership.toDTO()
    }
    
    func removeUser(organizationId: UUID, userId: UUID, requesterId: UUID) async throws {
        // Check if requester is an admin of the organization
        if !(try await organizationRepository.isAdmin(userId: requesterId, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to remove users from this organization")
        }
        
        // Remove the user
        try await organizationRepository.removeUser(from: organizationId, userId: userId)
    }
    
    func getMembers(organizationId: UUID, requesterId: UUID) async throws -> [OrganizationMemberDTO] {
        // Check if requester is a member of the organization
        if !(try await organizationRepository.isMember(userId: requesterId, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be a member to view organization members")
        }
        
        // Get all members
        let members = try await organizationRepository.getMembers(organizationId: organizationId)
        
        return members.map { member in
            OrganizationMemberDTO(
                id: member.user.id!,
                email: member.user.email,
                role: member.role
            )
        }
    }
    
    func getWithMembers(id: UUID, requesterId: UUID) async throws -> OrganizationWithMembersDTO {
        // Get the organization
        let organization = try await get(id: id)
        
        // Get all memberships for the organization
        let memberships = try await organizationRepository.getAllMembershipsForOrganization(id: id)
        
        // Convert to DTOs
        let members = memberships.compactMap { membership -> OrganizationMemberDTO? in
            guard let user = membership.$user.value else {
                return nil
            }
            
            return OrganizationMemberDTO(
                id: user.id!,
                email: user.email,
                role: membership.role
            )
        }
        
        // Check if the requester is a member of the organization
        let isMember = try await organizationRepository.isMember(userId: requesterId, organizationId: id)
        if !isMember {
            throw AuthorizationError.notAuthorized(reason: "You are not a member of this organization")
        }
        
        // Create the DTO
        let organizationDTO = createOrganizationDTO(from: organization)
        return OrganizationWithMembersDTO(
            organization: organizationDTO,
            members: members
        )
    }
    
    func createOrganizationDTO(from organization: Organization) -> OrganizationDTO {
        return OrganizationDTO(
            id: organization.id!,
            name: organization.name,
            createdAt: organization.createdAt,
            updatedAt: organization.updatedAt
        )
    }
    
    func createOrganizationWithRoleDTO(organization: Organization, role: OrganizationRole) -> OrganizationWithRoleDTO {
        return OrganizationWithRoleDTO(organization: organization, role: role)
    }
    
    func updateUserRole(to organizationId: UUID, userId: UUID, role: OrganizationRole) async throws -> OrganizationUser {
        // First remove the user from the organization
        try await organizationRepository.removeUser(from: organizationId, userId: userId)
        
        // Then add the user with the new role
        return try await organizationRepository.addUser(to: organizationId, userId: userId, role: role)
    }
} 