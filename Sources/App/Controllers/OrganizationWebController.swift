import Fluent
import Vapor

/// Controller for organization core CRUD web endpoints
struct OrganizationWebController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Organization listing
        routes.get(use: { @Sendable req in try await index(req: req) })
        
        // Create organization
        routes.get("create", use: { @Sendable req in try await createForm(req: req) })
        routes.post("create", use: { @Sendable req in try await create(req: req) })
        
        // Organization detail
        routes.get(":organizationId", use: { @Sendable req in try await show(req: req) })
        
        // Edit organization
        routes.get(":organizationId", "edit", use: { @Sendable req in try await editForm(req: req) })
        routes.post(":organizationId", "edit", use: { @Sendable req in try await update(req: req) })
        
        // Delete organization
        routes.post(":organizationId", "delete", use: { @Sendable req in try await delete(req: req) })
    }
    
    // MARK: - Organization Management
    
    /// Show the organization listing page
    @Sendable
    private func index(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the user's organizations
        let organizations = try await req.services.organizationService.getForUser(userId: user.id!)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Organizations",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create organizations context
        let context = OrganizationsViewContext(
            base: baseContext,
            organizations: organizations.map { OrganizationDTO(from: $0) }
        )
        
        return try await req.view.render("organizations", context)
    }
    
    /// Display the organization creation form
    @Sendable
    private func createForm(req: Request) async throws -> View {
        do {
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized, reason: "User not authenticated")
            }
            
            req.logger.info("Rendering organization creation form for user \(user.email) with ID \(user.id?.uuidString ?? "unknown")")
            
            // Create base context
            let baseContext = BaseViewContext(
                title: "Create Organization",
                isAuthenticated: true,
                isAdmin: user.isAdmin,
                user: user
            )
            
            // Create organization form context
            let context = OrganizationCreateViewContext(base: baseContext)
            
            return try await req.view.render("organization-create-form", context)
        } catch {
            // Detailed error logging to help diagnose the issue
            req.logger.error("Error rendering organization form: \(error)")
            req.logger.error("Error type: \(type(of: error))")
            
            if let abortError = error as? AbortError {
                req.logger.error("Abort error status: \(abortError.status)")
            }
            
            // Create a detailed error context
            let baseContext = BaseViewContext(
                title: "Error",
                isAuthenticated: false,
                errorMessage: "Failed to load organization form: \(error.localizedDescription)"
            )
            
            let errorContext = ErrorViewContext(
                base: baseContext,
                statusCode: 500,
                reason: "Failed to load organization form: \(error.localizedDescription)"
            )
            
            return try await req.view.render("error", errorContext)
        }
    }
    
    /// Create a new organization
    @Sendable
    private func create(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        do {
            // Parse form data
            let formData = try req.content.decode(CreateOrganizationRequest.self)
            
            // Add detailed logging
            req.logger.info("Creating organization '\(formData.name)' for user \(user.email) with ID \(user.id?.uuidString ?? "unknown")")
            
            // Create the organization
            let organizationService = try req.organizationService()
            let organization = try await organizationService.create(formData, creatorId: user.id!)
            
            // Add more detailed logging about the created organization
            req.logger.info("Organization created with ID: \(organization.id?.uuidString ?? "unknown"), name: \(organization.name)")
            
            // Verify the user-organization relationship was created correctly
            let organizationRepository = try req.organizationRepository()
            let memberships = try await organizationRepository.getMembershipsForUser(userId: user.id!)
            
            req.logger.info("User has \(memberships.count) organization memberships after creation")
            for membership in memberships {
                req.logger.info("Membership: orgId=\(membership.$organization.id), role=\(membership.role)")
                
                // Verify this membership includes our new organization
                if membership.$organization.id == organization.id {
                    req.logger.info("Found membership for newly created organization with role: \(membership.role)")
                }
            }
            
            // Also verify by checking if user is a member of the organization
            let isMember = try await organizationRepository.isMember(userId: user.id!, organizationId: organization.id!)
            req.logger.info("User is member of organization: \(isMember)")
            
            // Redirect to the organization detail page
            return req.redirect(to: "/dashboard/organizations/\(organization.id!)")
        } catch {
            // Log the error
            req.logger.error("Error creating organization: \(error)")
            
            // Render the form again with an error message
            let context = ViewContext.error(
                status: 500,
                reason: "Failed to create organization: \(error.localizedDescription)"
            )
            
            return try await req.view.render("error", context).encodeResponse(for: req)
        }
    }
    
    /// Show organization details
    private func show(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organizationWithMembers = try await organizationService.getWithMembers(id: organizationId, requesterId: user.id!)
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        let isOrgAdmin = try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)
        
        // Get the organization's feature flags
        let featureFlagRepository = req.services.featureFlagRepository
        let flags = try await featureFlagRepository.getAllForOrganization(organizationId: organizationId)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Organization Details",
            isAuthenticated: true,
            isAdmin: isOrgAdmin,
            user: user
        )
        
        // Create organization detail context
        let context = OrganizationDetailViewContext(
            base: baseContext,
            organization: OrganizationDTO(from: organizationWithMembers),
            flags: flags.map { FeatureFlagResponse(flag: $0) },
            members: organizationWithMembers.members.map { UserResponse(user: $0.user) },
            currentUserId: user.id!
        )
        
        return try await req.view.render("organization-detail", context)
    }
    
    /// Show form to edit an organization
    @Sendable
    private func editForm(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to edit this organization")
        }
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Edit Organization",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create organization form context
        let context = OrganizationEditViewContext(
            base: baseContext,
            organization: organizationService.createOrganizationDTO(from: organization)
        )
        
        req.logger.info("Rendering organization-edit-form template for editing organization \(organizationId)")
        return try await req.view.render("organization-edit-form", context)
    }
    
    /// Update an organization
    @Sendable
    private func update(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to update this organization")
        }
        
        // Parse form data
        let formData = try req.content.decode(UpdateOrganizationRequest.self)
        
        // Update the organization
        let organizationService = try req.organizationService()
        _ = try await organizationService.update(id: organizationId, dto: formData)
        
        // Redirect to the organization detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)")
    }
    
    /// Delete an organization
    @Sendable
    private func delete(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to delete this organization")
        }
        
        // Delete the organization
        let organizationService = try req.organizationService()
        try await organizationService.delete(id: organizationId)
        
        // Redirect to the organizations list
        return req.redirect(to: "/dashboard/organizations")
    }
} 
