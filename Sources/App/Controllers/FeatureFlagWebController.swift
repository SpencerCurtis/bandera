import Vapor
import Fluent
import Leaf

/// Web-focused controller for feature flag management with view rendering
struct FeatureFlagWebController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Base routes for web interface
        routes.get(use: index)
        routes.get(":id", use: detail)
        routes.get("create", use: createForm)
        routes.post("create", use: create)
        routes.get(":id", "edit", use: editForm)
        routes.post(":id", "edit", use: update)
        
        // Flag actions (web-focused with redirects)
        routes.post(":id", "toggle", use: toggleFlag)
        routes.post(":id", "delete", use: deleteFlag)
        
        // Import/Export endpoints
        routes.post(":id", "import", ":organizationId", use: importFlag)
        
        // User overrides (web interface)
        routes.get(":id", "overrides", "new", use: createOverrideForm)
        routes.post(":id", "overrides", "new", use: createOverride)
        routes.post(":id", "overrides", ":overrideId", "delete", use: deleteOverride)
    }
    
    // MARK: - View Rendering Methods
    
    /// Index page for feature flags
    @Sendable
    func index(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get all flags for the user
        let flags = try await req.services.featureFlagService.getAllFlags(userId: user.id!)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Feature Flags",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create context
        let context = FeatureFlagsViewContext(
            base: baseContext,
            flags: flags
        )
        
        return try await req.view.render("feature-flags", context)
    }
    
    /// Gets detailed information about a specific feature flag and renders the view
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
            
            // Get members for user overrides if user is admin (use pagination to limit results)
            let members: [User]
            if user.isAdmin {
                let paginationParams = PaginationParams(page: 1, perPage: 50) // Limit to first 50 users for dropdown
                let paginatedUsers = try await req.services.userRepository.getAllUsers(
                    params: paginationParams,
                    baseUrl: req.url.string
                )
                members = paginatedUsers.data
            } else {
                members = []
            }
            
            // Create base context
            let baseContext = BaseViewContext(
                title: "Feature Flag: \(flag.key)",
                isAuthenticated: true,
                isAdmin: user.isAdmin,
                user: user
            )
            
            // Create context based on whether this is a personal or organization flag
            if let orgId = flag.organizationId {
                // Get organization details
                let orgService = req.services.organizationService
                let organization = try await orgService.get(id: orgId)
                let orgDTO = OrganizationDTO(from: organization)
                
                // Check if user is an admin of this organization
                let isOrgAdmin = try await req.services.organizationRepository.isAdmin(userId: user.id!, organizationId: orgId)
                
                // Create flag detail context
                let context = FlagDetailViewContext(
                    base: baseContext,
                    flag: flag,
                    organization: orgDTO,
                    canEdit: isOrgAdmin,
                    members: members
                )
                
                return try await req.view.render("flag-detail", context)
            } else {
                // Create a personal organization DTO
                let personalOrgDTO = OrganizationDTO(
                    id: UUID(),
                    name: "Personal",
                    isPersonal: true
                )
                
                // Create flag detail context
                let context = FlagDetailViewContext(
                    base: baseContext,
                    flag: flag,
                    organization: personalOrgDTO,
                    canEdit: true, // User can always edit their personal flags
                    members: members
                )
                
                return try await req.view.render("flag-detail", context)
            }
        } catch {
            req.logger.error("Error retrieving flag details: \(error)")
            throw error
        }
    }
    
    /// Renders the create feature flag form
    @Sendable
    func createForm(req: Request) async throws -> View {
        // Get the authenticated user 
        let user = try req.auth.require(User.self)
        
        // Get the user's organizations
        let organizations = try await req.services.organizationService.getForUser(userId: user.id!)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Create Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create context for the view with explicit organizations array
        let context = OrganizationFlagFormViewContext(
            base: baseContext,
            organizations: organizations.map { OrganizationDTO(from: $0) }
        )
        
        // Render the organization flag form template
        return try await req.view.render("organization-flag-form", context)
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
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Edit Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Get the organization if this is an organizational flag
        let organization: OrganizationDTO?
        if let orgId = flag.organizationId {
            let organizationService = req.services.organizationService
            let org = try await organizationService.get(id: orgId)
            organization = OrganizationDTO(from: org)
        } else {
            organization = nil
        }
        
        // Create context for the view
        let context = OrganizationFlagFormViewContext(
            base: baseContext,
            organization: organization,
            flag: flag
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Renders the form for creating a feature flag override
    @Sendable
    func createOverrideForm(req: Request) async throws -> View {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the flag details from the service
        let flag = try await req.services.featureFlagService.getFlagDetails(id: id, userId: user.id!)
        
        // Get users for the select dropdown (admins only can set for any user, limit to 50 for dropdown)
        let users: [User]
        if user.isAdmin {
            let paginationParams = PaginationParams(page: 1, perPage: 50) // Limit to first 50 users for dropdown
            let paginatedUsers = try await req.services.userRepository.getAllUsers(
                params: paginationParams,
                baseUrl: req.url.string
            )
            users = paginatedUsers.data
        } else {
            users = []
        }
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Add Feature Flag Override",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Get the organization if this is an organizational flag
        let organization: OrganizationDTO?
        if let orgId = flag.organizationId {
            let organizationService = req.services.organizationService
            let org = try await organizationService.get(id: orgId)
            organization = OrganizationDTO(from: org)
        } else {
            organization = nil
        }
        
        // Create override form context
        let context = FeatureFlagOverrideFormViewContext(
            base: baseContext,
            flag: flag,
            organization: organization,
            allUsers: users.map { UserResponse(user: $0) }
        )
        
        // Render the view
        return try await req.view.render("feature-flag-override-form", context)
    }
    
    // MARK: - Form Submission Handlers (Web Actions)
    
    /// Creates a new feature flag from web form submission
    @Sendable
    func create(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Validate and decode the create request
        try CreateFeatureFlagRequest.validate(content: req)
        let create = try req.content.decode(CreateFeatureFlagRequest.self)
        
        // Use the feature flag service to create the flag
        let flag = try await req.services.featureFlagService.createFlag(create, userId: user.id!)
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/feature-flags/\(flag.id!)")
    }
    
    /// Updates a feature flag from web form submission
    @Sendable
    func update(req: Request) async throws -> Response {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Validate and decode the update request
        try UpdateFeatureFlagRequest.validate(content: req)
        let update = try req.content.decode(UpdateFeatureFlagRequest.self)
        
        // Use the feature flag service to update the flag
        _ = try await req.services.featureFlagService.updateFlag(id: id, update, userId: user.id!)
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/feature-flags/\(id)")
    }
    
    /// Deletes a feature flag and redirects
    @Sendable
    func deleteFlag(req: Request) async throws -> Response {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Verify the user is an admin
        guard user.isAdmin else {
            throw AuthenticationError.insufficientPermissions
        }
        
        // Use the feature flag service to delete the flag
        try await req.services.featureFlagService.deleteFlag(id: id, userId: user.id!)
        
        // Redirect to the flags index
        return req.redirect(to: "/dashboard/feature-flags")
    }
    
    /// Toggles a feature flag on/off and redirects
    @Sendable
    func toggleFlag(req: Request) async throws -> Response {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Toggle the flag using the service
        _ = try await req.services.featureFlagService.toggleFlag(id: id, userId: user.id!)
        
        // Redirect back to the detail page
        return req.redirect(to: "/dashboard/feature-flags/\(id)")
    }
    
    /// Creates a new override for a feature flag and redirects
    @Sendable
    func createOverride(req: Request) async throws -> Response {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
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
            authenticatedUserId: user.id!
        )
        
        // Use the feature flag service to create the override
        try await req.services.featureFlagService.createOverride(
            flagId: id,
            userId: targetUserId,
            value: create.value,
            createdBy: user.id!
        )
        
        // Redirect back to the flag detail page
        return req.redirect(to: "/dashboard/feature-flags/\(id)")
    }
    
    /// Deletes a feature flag override and redirects
    @Sendable
    func deleteOverride(req: Request) async throws -> Response {
        // Get the flag ID and override ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self),
              let overrideId = req.parameters.get("overrideId", as: UUID.self) else {
            throw ValidationError.failed("Invalid ID")
        }
        
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Use the feature flag service to delete the override
        try await req.services.featureFlagService.deleteOverride(id: overrideId, userId: user.id!)
        
        // Redirect back to the flag detail page
        return req.redirect(to: "/dashboard/feature-flags/\(id)")
    }
    
    /// Import a feature flag to an organization and redirect
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