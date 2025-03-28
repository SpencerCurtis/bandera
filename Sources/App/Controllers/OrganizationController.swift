import Fluent
import Vapor

/// Controller for organization-related endpoints
struct OrganizationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // API routes should use JWTAuthMiddleware.api which throws instead of redirecting
        let organizations = routes.grouped("api", "organizations")
            .grouped(JWTAuthMiddleware.api)
        
        // Protected endpoints
        organizations.post(use: { @Sendable req in try await create(req) })
        organizations.get(use: { @Sendable req in try await getUserOrganizations(req) })
        organizations.get(":organizationId", use: { @Sendable req in try await getOrganization(req) })
        organizations.put(":organizationId", use: { @Sendable req in try await updateOrganization(req) })
        organizations.delete(":organizationId", use: { @Sendable req in try await deleteOrganization(req) })
        
        organizations.get(":organizationId", "members", use: { @Sendable req in try await getMembers(req) })
        organizations.post(":organizationId", "members", use: { @Sendable req in try await addMember(req) })
        organizations.delete(":organizationId", "members", ":userId", use: { @Sendable req in try await removeMember(req) })
    }
    
    /// Create a new organization
    /// - Parameter req: The HTTP request
    /// - Returns: The created organization
    @Sendable
    private func create(_ req: Request) async throws -> OrganizationDTO {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Parse the request data
        let dto = try req.content.decode(CreateOrganizationRequest.self)
        
        // Create the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.create(dto, creatorId: user.id!)
        
        return organization.toDTO()
    }
    
    /// Get all organizations for the authenticated user
    @Sendable
    private func getUserOrganizations(_ req: Request) async throws -> UserOrganizationsDTO {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the user's organizations
        let organizationService = try req.organizationService()
        let organizations = try await organizationService.getForUser(userId: user.id!)
        
        return UserOrganizationsDTO(organizations: organizations)
    }
    
    /// Get a specific organization
    @Sendable
    private func getOrganization(_ req: Request) async throws -> OrganizationWithMembersDTO {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Get the organization with its members
        let organizationService = try req.organizationService()
        return try await organizationService.getWithMembers(id: organizationId, requesterId: user.id!)
    }
    
    /// Update an organization
    @Sendable
    private func updateOrganization(_ req: Request) async throws -> OrganizationDTO {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Parse the request data
        let dto = try req.content.decode(UpdateOrganizationRequest.self)
        
        // Verify user is an admin
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to update this organization")
        }
        
        // Update the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.update(id: organizationId, dto: dto)
        
        return organization.toDTO()
    }
    
    /// Delete an organization
    @Sendable
    private func deleteOrganization(_ req: Request) async throws -> HTTPStatus {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Verify user is an admin
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to delete this organization")
        }
        
        // Delete the organization
        let organizationService = try req.organizationService()
        try await organizationService.delete(id: organizationId)
        
        return .ok
    }
    
    /// Get all members of an organization
    @Sendable
    private func getMembers(_ req: Request) async throws -> [OrganizationMemberDTO] {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Get the organization members
        let organizationService = try req.organizationService()
        return try await organizationService.getMembers(organizationId: organizationId, requesterId: user.id!)
    }
    
    /// Add a member to an organization
    @Sendable
    private func addMember(_ req: Request) async throws -> OrganizationMembershipDTO {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Parse the request data
        let dto = try req.content.decode(AddUserToOrganizationRequest.self)
        
        // Add the member
        let organizationService = try req.organizationService()
        return try await organizationService.addUser(
            organizationId: organizationId,
            dto: dto,
            requesterId: user.id!
        )
    }
    
    /// Remove a member from an organization
    @Sendable
    private func removeMember(_ req: Request) async throws -> HTTPStatus {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and user ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw ValidationError.failed("Invalid user ID")
        }
        
        // Remove the member
        let organizationService = try req.organizationService()
        try await organizationService.removeUser(
            organizationId: organizationId,
            userId: userId,
            requesterId: user.id!
        )
        
        return .ok
    }
} 