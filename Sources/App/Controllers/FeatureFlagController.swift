import Vapor
import Fluent
import Leaf

/// Controller for feature flag-related routes.
struct FeatureFlagController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Routes are already protected by JWTAuthMiddleware.standard in routes.swift
        // So we don't need to apply authentication middleware again
        
        // Base routes
        routes.get(use: index)
        routes.get(":id", use: detail)
        routes.get("create", use: plainCreateForm)
        routes.post("create", use: create)
        routes.get(":id", "edit", use: editForm)
        routes.post(":id", "edit", use: update)
        
        // Flag actions
        routes.post(":id", "toggle", use: toggleFlag)
        routes.delete(":id", use: deleteFlag)
        
        // Import/Export endpoints
        routes.post(":id", "import", ":organizationId", use: importFlag)
        
        // User overrides
        routes.get(":id", "overrides", "new", use: createOverrideForm)
        routes.post(":id", "overrides", "new", use: createOverride)
        routes.post(":id", "overrides", ":overrideId", "delete", use: deleteOverride)
    }
    
    /// Renders the create feature flag form
    @Sendable
    func createForm(req: Request) async throws -> View {
        // Get the authenticated user from the session
        guard let userIdString = req.session.data["user_id"],
              let userId = UUID(userIdString) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Log the user ID we're using
        req.logger.info("Creating feature flag form for user ID: \(userId)")
        
        // Get the user from the database
        guard let user = try await User.find(userId, on: req.db) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Use the standard service approach to get organizations
        let organizations = try await req.services.organizationService.getForUser(userId: userId)
        
        // Log the organizations for debugging
        req.logger.info("Found \(organizations.count) organizations for user \(userId)")
        for org in organizations {
            req.logger.info("Organization: \(org.id) - \(org.name) (Role: \(org.role))")
        }
        
        // Create context for the view
        let context = ViewContext(
            title: "Create Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user,
            organizations: organizations.map { OrganizationDTO(from: $0) },
            editing: false
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Plain HTML form that bypasses JWT verification issues
    @Sendable
    func plainCreateForm(req: Request) async throws -> View {
        // Get the authenticated user 
        let user = try req.auth.require(User.self)
        
        // Get the user's organizations
        let organizations = (try? await req.services.organizationService.getForUser(userId: user.id!)) ?? []
        
        // Create context for the view with explicit organizations array
        let context = ViewContext(
            title: "Create Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user,
            organizations: organizations.map { OrganizationDTO(from: $0) },
            editing: false
        )
        
        // Render the organization flag form template
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Index page for feature flags
    @Sendable
    func index(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get all flags for the user
        let flags = try await req.services.featureFlagService.getAllFlags(userId: user.id!)
        
        // Create view context
        let context = ViewContext(
            title: "Feature Flags",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            flags: flags
        )
        
        return try await req.view.render("feature-flags", context)
    }
    
    /// Renders the edit form for a feature flag
    @Sendable
    func editForm(req: Request) async throws -> View {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the flag details
        let flag = try await req.services.featureFlagService.getFlagDetails(id: id, userId: user.id!)
        
        req.logger.debug("Flag details retrieved: id=\(flag.id), key=\(flag.key)")
        
        // Create view context
        let context = ViewContext(
            title: "Edit Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user,
            organizations: try await req.services.organizationService.getForUser(userId: user.id!).map { OrganizationDTO(from: $0) },
            editing: true
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    // MARK: - User Routes
    
    /// Creates a new feature flag.
    @Sendable
    func create(req: Request) async throws -> Response {
        // Validate the request content against the DTO's validation rules
        try CreateFeatureFlagRequest.validate(content: req)
        let create = try req.content.decode(CreateFeatureFlagRequest.self)
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Validate that an organization is selected
        guard let organizationId = create.organizationId else {
            throw ValidationError.failed("You must select an organization")
        }
        
        // Check if the user is a member of the organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isMember(userId: userId, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You are not a member of this organization")
        }
        
        // Use the feature flag service to create the flag
        let flag = try await req.services.featureFlagService.createFlag(create, userId: userId)
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/feature-flags/\(flag.id!)")
    }
    
    /// Updates an existing feature flag.
    @Sendable
    func update(req: Request) async throws -> FeatureFlag {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Validate and decode the update request
        try UpdateFeatureFlagRequest.validate(content: req)
        let update = try req.content.decode(UpdateFeatureFlagRequest.self)
        
        // Use the feature flag service to update the flag
        return try await req.services.featureFlagService.updateFlag(id: id, update, userId: userId)
    }
    
    /// Deletes a feature flag.
    @Sendable
    func deleteFlag(req: Request) async throws -> HTTPStatus {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Verify the user is an admin
        guard payload.isAdmin else {
            throw AuthenticationError.insufficientPermissions
        }
        
        // Use the feature flag service to delete the flag
        try await req.services.featureFlagService.deleteFlag(id: id, userId: userId)
        
        return .ok
    }
    
    /// Gets all feature flags for a specific user.
    @Sendable
    func getForUser(req: Request) async throws -> FeatureFlagsContainer {
        // Get the user ID from the request parameters
        guard let userId = req.parameters.get("userId") else {
            throw ValidationError.failed("Invalid user ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Only allow access to own flags or if admin
        if !payload.isAdmin && payload.subject.value != userId {
            throw AuthenticationError.insufficientPermissions
        }
        
        // Use the feature flag service to get flags with overrides
        return try await req.services.featureFlagService.getFlagsWithOverrides(userId: userId)
    }
    
    /// Gets detailed information about a specific feature flag.
    @Sendable
    func detail(req: Request) async throws -> View {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        do {
            // Get the flag details from the service
            let flag = try await req.services.featureFlagService.getFlagDetails(id: id, userId: user.id!)
            
            req.logger.debug("Flag details retrieved: id=\(flag.id), key=\(flag.key)")
            
            // Create a safe version of the flag for display
            var safeFlag = createSafeFlag(from: flag)
            
            // Ensure organizations is never nil to avoid Leaf template issues
            if safeFlag.organizations == nil {
                safeFlag.organizations = []
            }
            
            // Get members for user overrides if user is admin
            let members = user.isAdmin ? try await req.services.userRepository.getAllUsers() : []
            
            // Create context based on whether this is a personal or organization flag
            var context: UnifiedFlagDetailContext
            if let orgId = flag.organizationId {
                // Get organization details
                let orgService = try req.organizationService()
                let organization = try await orgService.get(id: orgId)
                let orgDTO = orgService.createOrganizationDTO(from: organization)
                
                // Check if user is an admin of this organization
                let isOrgAdmin = try await req.organizationRepository().isAdmin(userId: user.id!, organizationId: orgId)
                
                context = .organizational(
                    flag: safeFlag,
                    organization: orgDTO,
                    canEdit: isOrgAdmin,
                    members: members
                )
            } else {
                // Create a personal organization DTO
                let personalOrgDTO = OrganizationDTO(
                    id: UUID(),
                    name: "Personal",
                    isPersonal: true
                )
                
                context = .personal(
                    flag: safeFlag,
                    canEdit: true, // User can always edit their personal flags
                    members: members
                )
                
                // Set the organization after creation since personal() factory doesn't take it
                context.organization = personalOrgDTO
            }
            
            return try await req.view.render("flag-detail", context)
        } catch {
            req.logger.error("Error retrieving flag details: \(error)")
            throw error
        }
    }
    
    /// Creates a safe version of a feature flag for display, handling potential date formatting issues
    private func createSafeFlag(from flag: FeatureFlagDetailDTO) -> FeatureFlagDetailDTO {
        // Format dates as strings to avoid Leaf date conversion issues
        let safeCreatedAt = flag.createdAt ?? Date(timeIntervalSince1970: 0)
        let safeUpdatedAt = flag.updatedAt ?? Date(timeIntervalSince1970: 0)
        
        // Create a copy of audit logs with safely formatted dates
        let safeAuditLogs = [AuditLogDTO(
            type: "unknown",
            message: "N/A",
            user: UserDTO(id: UUID(), email: "N/A"),
            createdAt: safeCreatedAt
        )]
        
        // Create a copy of user overrides with safely formatted dates
        let safeUserOverrides = [UserOverrideDTO(
            id: UUID(),
            user: UserDTO(id: UUID(), email: "N/A"),
            value: "N/A",
            updatedAt: safeUpdatedAt
        )]
        
        // Return a new DTO with safe values
        return FeatureFlagDetailDTO(
            id: flag.id,
            key: flag.key,
            type: flag.type,
            defaultValue: flag.defaultValue,
            description: flag.description,
            isEnabled: flag.isEnabled,
            createdAt: safeCreatedAt,
            updatedAt: safeUpdatedAt,
            organizationId: flag.organizationId,
            userOverrides: safeUserOverrides,
            auditLogs: safeAuditLogs,
            organizations: flag.organizations ?? []
        )
    }
    
    /// Toggles a feature flag on/off.
    @Sendable
    func toggleFlag(req: Request) async throws -> Response {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Toggle the flag using the service
        _ = try await req.services.featureFlagService.toggleFlag(id: id, userId: userId)
        
        // Redirect back to the detail page
        return req.redirect(to: "/dashboard/feature-flags/\(id)")
    }
    
    /// Renders the create override form for a feature flag.
    @Sendable
    func createOverrideForm(req: Request) async throws -> View {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the flag details from the service
        _ = try await req.services.featureFlagService.getFlagDetails(id: id, userId: user.id!)
        
        // Get users for the select dropdown (admins only can set for any user)
        let users = user.isAdmin ? try await req.services.userRepository.getAllUsers() : []
        
        // Create view context
        let context = ViewContext(
            title: "Add Feature Flag Override",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            users: users.map { UserResponse(user: $0) }
        )
        
        // Render the view
        return try await req.view.render("feature-flag-override-form", context)
    }
    
    /// Creates a new override for a feature flag.
    @Sendable
    func createOverride(req: Request) async throws -> Response {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Validate and decode the create override request
        try CreateOverrideRequest.validate(content: req)
        let create = try req.content.decode(CreateOverrideRequest.self)
        
        // Convert string userId to UUID
        guard let targetUserIdUUID = UUID(create.userId) else {
            throw ValidationError.failed("Invalid user ID format. Must be a valid UUID.")
        }
        
        // Get target user ID (admin can create override for any user, non-admin only for self)
        let targetUserId = try await req.services.authService.validateTargetUser(
            requestedUserId: targetUserIdUUID,
            authenticatedUserId: userId
        )
        
        // Use the feature flag service to create the override
        try await req.services.featureFlagService.createOverride(
            flagId: id,
            userId: targetUserId,
            value: create.value,
            createdBy: userId
        )
        
        // Redirect back to the flag detail page
        return req.redirect(to: "/dashboard/feature-flags/\(id)")
    }
    
    /// Deletes a feature flag override.
    @Sendable
    func deleteOverride(req: Request) async throws -> Response {
        // Get the flag ID and override ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self),
              let overrideId = req.parameters.get("overrideId", as: UUID.self) else {
            throw ValidationError.failed("Invalid ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Use the feature flag service to delete the override
        try await req.services.featureFlagService.deleteOverride(id: overrideId, userId: userId)
        
        // Redirect back to the flag detail page
        return req.redirect(to: "/dashboard/feature-flags/\(id)")
    }
    
    /// Import a feature flag to an organization
    @Sendable
    func importFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the flag ID from the request parameters
        guard let flagId = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the organization ID from the request parameters
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Import the flag
        let featureFlagService = req.services.featureFlagService
        let importedFlag = try await featureFlagService.importFlagToOrganization(
            flagId: flagId,
            organizationId: organizationId,
            userId: user.id!
        )
        
        // Set success message as a flash message
        req.session.data["success"] = "Feature flag '\(importedFlag.key)' imported to organization successfully"
        
        // Redirect to the organization's flags page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags")
    }
}