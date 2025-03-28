import Fluent
import Vapor

/// Controller for organization-related web endpoints
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
        
        // Member management
        routes.post(":organizationId", "members", use: { @Sendable req in try await addMember(req: req) })
        routes.post(":organizationId", "members", ":userId", "remove", use: { @Sendable req in try await removeMember(req: req) })
        routes.post(":organizationId", "members", ":userId", "role", use: { @Sendable req in try await updateMemberRole(req: req) })
        
        // Feature flag management
        routes.get(":organizationId", "flags", use: { @Sendable req in try await flagIndex(req: req) })
        routes.get(":organizationId", "flags", "create", use: { @Sendable req in try await createFlagForm(req: req) })
        routes.post(":organizationId", "flags", "create", use: { @Sendable req in try await createFlag(req: req) })
        routes.get(":organizationId", "flags", ":flagId", use: { @Sendable req in try await showFlag(req: req) })
        routes.get(":organizationId", "flags", ":flagId", "edit", use: { @Sendable req in try await editFlagForm(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "edit", use: { @Sendable req in try await updateFlag(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "delete", use: { @Sendable req in try await deleteFlag(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "export", use: { @Sendable req in try await exportFlag(req: req) })
        
        // Feature flag overrides
        routes.get(":organizationId", "flags", ":flagId", "overrides", "create", use: { @Sendable req in try await createOverrideForm(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "overrides", use: { @Sendable req in try await addOverride(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "overrides", ":overrideId", "delete", use: { @Sendable req in try await deleteOverride(req: req) })
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
    
    // MARK: - Feature Flag Management
    
    /// Show the feature flags for an organization
    @Sendable
    private func flagIndex(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is a member of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isMember(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be a member of this organization to view its feature flags")
        }
        
        // Check if user is an admin of this organization
        let isOrgAdmin = try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Get the organization's feature flags
        let featureFlagRepository = req.services.featureFlagRepository
        let flags = try await featureFlagRepository.getAllForOrganization(organizationId: organizationId)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "\(organization.name) Feature Flags",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create organization flags context
        let context = OrganizationFlagsViewContext(
            base: baseContext,
            organization: orgDTO,
            isAdmin: isOrgAdmin,
            flags: flags
        )
        
        return try await req.view.render("organization-flags", context)
    }
    
    /// Show form to create a new feature flag
    @Sendable
    private func createFlagForm(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to create feature flags for this organization")
        }
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Create Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create context
        let context = OrganizationFlagFormViewContext(
            base: baseContext,
            organization: orgDTO
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Create a new feature flag
    @Sendable
    private func createFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to create feature flags for this organization")
        }
        
        // Parse form data
        let formData = try req.content.decode(CreateFeatureFlagRequest.self)
        
        // Create the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        let flag = FeatureFlag.create(from: formData, userId: user.id!, organizationId: organizationId)
        try await featureFlagRepository.save(flag)
        
        // Redirect to the organization's feature flags list
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags")
    }
    
    /// Show feature flag details
    @Sendable
    private func showFlag(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is a member of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isMember(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be a member of this organization to view its feature flags")
        }
        
        // Check if user is an admin of this organization
        let isOrgAdmin = try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Get the feature flag details
        let featureFlagService = req.services.featureFlagService
        let flag = try await featureFlagService.getFlagDetails(id: flagId, userId: user.id!)
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Get organization members for the override form
        let members = try await organizationRepository.getMembers(organizationId: organizationId)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Feature Flag: \(flag.key)",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create flag detail context
        let context = FlagDetailViewContext(
            base: baseContext,
            flag: flag,
            organization: orgDTO,
            canEdit: isOrgAdmin,
            members: members.map { $0.user }
        )
        
        return try await req.view.render("flag-detail", context)
    }
    
    /// Show form to edit a feature flag
    @Sendable
    private func editFlagForm(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to edit feature flags for this organization")
        }
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Get the feature flag details
        let featureFlagService = req.services.featureFlagService
        let flag = try await featureFlagService.getFlagDetails(id: flagId, userId: user.id!)
        
        // Verify this flag belongs to this organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Edit Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create context
        let context = OrganizationFlagFormViewContext(
            base: baseContext,
            organization: orgDTO,
            flag: flag
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Update a feature flag
    @Sendable
    private func updateFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to edit feature flags for this organization")
        }
        
        // Parse form data
        let formData = try req.content.decode(UpdateFeatureFlagRequest.self)
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Update the flag
        flag.update(from: formData)
        try await featureFlagRepository.save(flag)
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags/\(flagId)")
    }
    
    /// Delete a feature flag
    @Sendable
    private func deleteFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to delete feature flags for this organization")
        }
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Delete the flag
        try await featureFlagRepository.delete(flag)
        
        // Redirect to the organization's feature flags list
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags")
    }
    
    /// Show form to create a feature flag override
    @Sendable
    private func createOverrideForm(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to add overrides for this organization")
        }
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Get organization members for the override form
        let members = try await organizationRepository.getMembers(organizationId: organizationId)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Add Feature Flag Override",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create override form context
        let context = FeatureFlagOverrideFormViewContext(
            base: baseContext,
            flag: flag,
            organization: orgDTO,
            allUsers: members.map { UserResponse(user: $0.user) }
        )
        
        return try await req.view.render("feature-flag-override-form", context)
    }
    
    // MARK: - Feature Flag Overrides
    
    /// Add an override for a feature flag
    @Sendable
    private func addOverride(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to add overrides for this organization")
        }
        
        // Parse form data
        struct OverrideForm: Content {
            let userId: UUID
            let value: String
        }
        let formData = try req.content.decode(OverrideForm.self)
        
        // Verify the user is a member of this organization
        if !(try await organizationRepository.isMember(userId: formData.userId, organizationId: organizationId)) {
            req.session.flash(.error, "The selected user is not a member of this organization")
            return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags/\(flagId)")
        }
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Create or update the override
        let override = UserFeatureFlag(
            featureFlagId: flagId,
            userId: formData.userId,
            value: formData.value
        )
        try await featureFlagRepository.saveOverride(override)
        
        // Create audit log
        try await featureFlagRepository.createAuditLog(
            type: "override_created",
            message: "Created override for user \(formData.userId)",
            flagId: flagId,
            userId: user.id!
        )
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags/\(flagId)")
    }
    
    /// Delete an override for a feature flag
    @Sendable
    private func deleteOverride(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID, flag ID, and override ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        guard let overrideId = req.parameters.get("overrideId", as: UUID.self) else {
            throw ValidationError.failed("Invalid override ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to delete overrides for this organization")
        }
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Get the override
        guard let override = try await featureFlagRepository.findOverride(id: overrideId) else {
            throw ResourceError.notFound("Override with ID \(overrideId)")
        }
        
        // Verify the override belongs to this flag
        if override.$featureFlag.id != flagId {
            throw AuthorizationError.notAuthorized(reason: "This override does not belong to this feature flag")
        }
        
        // Verify the override belongs to a user in this organization
        if !(try await organizationRepository.isMember(userId: override.$user.id, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "This override does not belong to a user in this organization")
        }
        
        // Delete the override
        try await featureFlagRepository.deleteOverride(override)
        
        // Create audit log
        try await featureFlagRepository.createAuditLog(
            type: "override_deleted",
            message: "Deleted override for user \(override.$user.id)",
            flagId: flagId,
            userId: user.id!
        )
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags/\(flagId)")
    }
    
    /// Export a feature flag to user's personal flags
    @Sendable
    private func exportFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Export the flag
        let featureFlagService = req.services.featureFlagService
        let exportedFlag = try await featureFlagService.exportFlagToPersonal(
            flagId: flagId,
            userId: user.id!
        )
        
        // Set success message as a flash message
        req.session.data["success"] = "Feature flag '\(exportedFlag.key)' exported to your personal flags successfully"
        
        // Redirect to the dashboard page with feature flags
        return req.redirect(to: "/dashboard")
    }
} 
