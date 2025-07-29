import Fluent
import Vapor

/// Controller for organization member management web endpoints
struct OrganizationMemberWebController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Member management routes
        routes.post(":organizationId", "members", use: { @Sendable req in try await addMember(req: req) })
        routes.post(":organizationId", "members", ":userId", "remove", use: { @Sendable req in try await removeMember(req: req) })
        routes.post(":organizationId", "members", ":userId", "role", use: { @Sendable req in try await updateMemberRole(req: req) })
    }
    
    // MARK: - Member Management
    
    /// Add a member to an organization
    @Sendable
    private func addMember(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to add members to this organization")
        }
        
        // Parse form data (note: using email instead of userId in the form)
        struct AddMemberForm: Content {
            let email: String
            let role: String
        }
        let formData = try req.content.decode(AddMemberForm.self)
        
        // Look up the user by email
        let userRepository = req.services.userRepository
        guard let newUser = try await userRepository.findByEmail(formData.email) else {
            req.session.flash(.error, "User with email \(formData.email) not found")
            return req.redirect(to: "/dashboard/organizations/\(organizationId)")
        }
        
        // Add the user to the organization
        let dto = AddUserToOrganizationRequest(
            userId: newUser.id!,
            role: formData.role == "admin" ? .admin : .member
        )
        
        let organizationService = try req.organizationService()
        _ = try await organizationService.addUser(
            organizationId: organizationId,
            dto: dto,
            requesterId: user.id!
        )
        
        // Redirect to the organization detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)")
    }
    
    /// Remove a member from an organization
    @Sendable
    private func removeMember(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and user ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let targetUserId = req.parameters.get("userId", as: UUID.self) else {
            throw ValidationError.failed("Invalid user ID")
        }
        
        // Cannot remove yourself
        if targetUserId == user.id! {
            req.session.flash(.error, "You cannot remove yourself from the organization")
            return req.redirect(to: "/dashboard/organizations/\(organizationId)")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to remove members from this organization")
        }
        
        // Remove the member
        let organizationService = try req.organizationService()
        try await organizationService.removeUser(
            organizationId: organizationId,
            userId: targetUserId,
            requesterId: user.id!
        )
        
        // Redirect to the organization detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)")
    }
    
    /// Update a member's role
    @Sendable
    private func updateMemberRole(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and user ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let targetUserId = req.parameters.get("userId", as: UUID.self) else {
            throw ValidationError.failed("Invalid user ID")
        }
        
        // Parse form data
        struct RoleForm: Content {
            let role: String
        }
        let formData = try req.content.decode(RoleForm.self)
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to change member roles in this organization")
        }
        
        // Update the role
        let organizationService = try req.organizationService()
        _ = try await organizationService.updateUserRole(
            to: organizationId,
            userId: targetUserId,
            role: formData.role == "admin" ? OrganizationRole.admin : OrganizationRole.member
        )
        
        // Redirect to the organization detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)")
    }
} 