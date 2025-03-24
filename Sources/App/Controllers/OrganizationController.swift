import Fluent
import Vapor

/// Controller for organization-related endpoints
struct OrganizationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let organizations = routes.grouped("api", "organizations")
        let protectedOrganizations = organizations.grouped(User.sessionAuthMiddleware())
        
        // Public endpoints
        
        // Protected endpoints
        protectedOrganizations.post(use: create)
        protectedOrganizations.get(use: getUserOrganizations)
        protectedOrganizations.get(":organizationId", use: getOrganization)
        protectedOrganizations.put(":organizationId", use: updateOrganization)
        protectedOrganizations.delete(":organizationId", use: deleteOrganization)
        
        protectedOrganizations.get(":organizationId", "members", use: getMembers)
        protectedOrganizations.post(":organizationId", "members", use: addMember)
        protectedOrganizations.delete(":organizationId", "members", ":userId", use: removeMember)
    }
    
    /// Create a new organization
    /// - Parameter req: The HTTP request
    /// - Returns: The created organization
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
    /// - Parameter req: The HTTP request
    /// - Returns: A list of organizations
    private func getUserOrganizations(_ req: Request) async throws -> UserOrganizationsDTO {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the user's organizations
        let organizationService = try req.organizationService()
        let organizations = try await organizationService.getForUser(userId: user.id!)
        
        return UserOrganizationsDTO(organizations: organizations)
    }
    
    /// Get a specific organization
    /// - Parameter req: The HTTP request
    /// - Returns: The organization with its members
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
    /// - Parameter req: The HTTP request
    /// - Returns: The updated organization
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
    /// - Parameter req: The HTTP request
    /// - Returns: A successful response
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
    /// - Parameter req: The HTTP request
    /// - Returns: A list of organization members
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
    /// - Parameter req: The HTTP request
    /// - Returns: The created membership
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
    /// - Parameter req: The HTTP request
    /// - Returns: A successful response
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