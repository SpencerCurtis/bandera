import Fluent
import Vapor

/// Controller for organization-related web endpoints
struct OrganizationWebController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Since this controller is registered in configure.swift directly on the app,
        // we need to specify the full path and add JWTAuthMiddleware
        let basePath = routes.grouped("dashboard").grouped(JWTAuthMiddleware.standard)
        let organizations = basePath.grouped("organizations")
        
        // Organization listing
        organizations.get(use: index)
        
        // Create organization
        organizations.get("create", use: createForm)
        organizations.post("create", use: create)
        
        // Organization detail
        organizations.get(":organizationId", use: show)
        
        // Edit organization
        organizations.get(":organizationId", "edit", use: editForm)
        organizations.post(":organizationId", "edit", use: update)
        
        // Delete organization
        organizations.post(":organizationId", "delete", use: delete)
        
        // Member management
        organizations.post(":organizationId", "members", use: addMember)
        organizations.post(":organizationId", "members", ":userId", "remove", use: removeMember)
        organizations.post(":organizationId", "members", ":userId", "role", use: updateMemberRole)
        
        // Feature flag management
        organizations.get(":organizationId", "flags", use: flagIndex)
        organizations.get(":organizationId", "flags", "create", use: createFlagForm)
        organizations.post(":organizationId", "flags", "create", use: createFlag)
        organizations.get(":organizationId", "flags", ":flagId", use: showFlag)
        organizations.get(":organizationId", "flags", ":flagId", "edit", use: editFlagForm)
        organizations.post(":organizationId", "flags", ":flagId", "edit", use: updateFlag)
        organizations.post(":organizationId", "flags", ":flagId", "delete", use: deleteFlag)
        
        // Feature flag overrides
        organizations.post(":organizationId", "flags", ":flagId", "overrides", use: addOverride)
        organizations.post(":organizationId", "flags", ":flagId", "overrides", ":overrideId", "delete", use: deleteOverride)
    }
    
    // MARK: - Organization Management
    
    /// Display a list of organizations
    private func index(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get all organizations the user is a member of
        let organizations = try await req.services.organizationService.getForUser(userId: user.id!)
        
        // Render the organizations page
        let context = ViewContext(
            title: "Organizations",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            organizations: organizations
        )
        
        return try await req.view.render("organizations", context)
    }
    
    /// Display the organization creation form
    private func createForm(req: Request) async throws -> View {
        do {
            guard let user = req.auth.get(User.self) else {
                throw Abort(.unauthorized, reason: "User not authenticated")
            }
            
            req.logger.info("Rendering organization creation form for user \(user.email) with ID \(user.id?.uuidString ?? "unknown")")
            
            // Create a proper context directly with the ViewContext initializer
            let context = ViewContext(
                title: "Create Organization",
                isAuthenticated: true,
                isAdmin: user.isAdmin,
                user: user
            )
            
            return try await req.view.render("organization-create-form", context)
        } catch {
            // Detailed error logging to help diagnose the issue
            req.logger.error("Error rendering organization form: \(error)")
            req.logger.error("Error type: \(type(of: error))")
            
            if let abortError = error as? AbortError {
                req.logger.error("Abort error status: \(abortError.status)")
            }
            
            // Create a detailed error context with debugging info
            let errorContext = ViewContext.error(
                status: 500,
                reason: "Failed to load organization form: \(error.localizedDescription)"
            )
            
            // Log the templates available
            req.logger.info("Attempting to render error template...")
            return try await req.view.render("error", errorContext)
        }
    }
    
    /// Create a new organization
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
        
        // Create context
        let context = ViewContext(
            title: organizationWithMembers.name,
            isAuthenticated: true,
            isAdmin: isOrgAdmin,
            currentUserId: user.id!,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            organization: OrganizationDTO(
                id: organizationWithMembers.id,
                name: organizationWithMembers.name,
                createdAt: organizationWithMembers.createdAt,
                updatedAt: organizationWithMembers.updatedAt
            ),
            members: organizationWithMembers.members
        )
        
        return try await req.view.render("organization-detail", context)
    }
    
    /// Show form to edit an organization
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
        
        // Create context with editing explicitly set to true
        let context = ViewContext(
            title: "Edit Organization",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A", 
            lastDeployment: "N/A",
            organization: organizationService.createOrganizationDTO(from: organization),
            editing: true
        )
        
        req.logger.info("Rendering organization-form template for editing organization \(organizationId) with editing=\(String(describing: context.editing))")
        return try await req.view.render("organization-form", context)
    }
    
    /// Update an organization
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
    
    /// Show all feature flags for an organization
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
        
        // Get the organization's feature flags
        let featureFlagRepository = req.services.featureFlagRepository
        let flags = try await featureFlagRepository.getAllForOrganization(organizationId: organizationId)
        
        // Create context
        let context = ViewContext(
            title: "Organization Feature Flags",
            isAuthenticated: true,
            isAdmin: isOrgAdmin,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            flags: flags,
            organization: organizationService.createOrganizationDTO(from: organization)
        )
        
        return try await req.view.render("organization-flags", context)
    }
    
    /// Show form to create a new feature flag
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
        
        // Create context
        let context = ViewContext(
            title: "Create Feature Flag",
            isAuthenticated: true,
            isAdmin: true,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            organization: organizationService.createOrganizationDTO(from: organization),
            editing: false
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Create a new feature flag
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
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Get user overrides for this flag
        let overrides = try await featureFlagRepository.getOverrides(flagId: flagId)
        
        // Get organization members for the override form
        let members = try await organizationRepository.getMembers(organizationId: organizationId)
        
        // Create context
        let context = ViewContext(
            title: flag.key,
            isAuthenticated: true,
            isAdmin: isOrgAdmin,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            flag: flag,
            allUsers: members.map { member in 
                member.user
            },
            overrides: overrides,
            organization: organizationService.createOrganizationDTO(from: organization)
        )
        
        return try await req.view.render("organization-flag-detail", context)
    }
    
    /// Show form to edit a feature flag
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
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Create context
        let context = ViewContext(
            title: "Edit Feature Flag",
            isAuthenticated: true,
            isAdmin: true,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            flag: flag,
            organization: organizationService.createOrganizationDTO(from: organization),
            editing: true
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Update a feature flag
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
    
    // MARK: - Feature Flag Overrides
    
    /// Add an override for a feature flag
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
} 