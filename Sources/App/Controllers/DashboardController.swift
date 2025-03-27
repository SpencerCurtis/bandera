import Vapor
import Fluent

// Renamed from AdminController to DashboardController to reflect its more general purpose
struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Routes are already protected by JWTAuthMiddleware.standard from configure.swift
        
        // Base dashboard route
        routes.get(use: dashboard)
        
        // Feature flag routes
        routes.get("feature-flags", "create", use: createFlag)
        routes.post("feature-flags", "create", use: handleCreateFlag)
        
        let flags = routes.grouped("feature-flags")
        flags.get(":id", "edit", use: editForm)
        flags.post(":id", "edit", use: updatePersonalFlag)
        flags.post(":id", "delete", use: deletePersonalFlag)
    }
    
    // MARK: - Context Structs
    
    // Dashboard context with feature flags
    struct DashboardContext: Content {
        var title: String
        var isAuthenticated: Bool
        var isAdmin: Bool
        var error: String?
        var recoverySuggestion: String?
        var success: String?
        var flags: [FeatureFlag]
    }
    
    // Feature flag form context
    struct FeatureFlagFormContext: Content {
        var title: String
        var isAuthenticated: Bool
        var isAdmin: Bool
        var errorMessage: String?
        var recoverySuggestion: String?
        var successMessage: String?
        var flag: FeatureFlag?
    }
    
    // MARK: - View Handlers
    
    /// Show the dashboard
    @Sendable
    func dashboard(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the user's organizations
        let organizations = try await req.services.organizationService.getForUser(userId: user.id!)
        
        // Get the user's feature flags
        let featureFlags = try await req.services.featureFlagService.getAllFlags(userId: user.id!)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Dashboard",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create dashboard context with feature flag responses and organizations
        let context = DashboardViewContext(
            base: baseContext,
            featureFlags: featureFlags.map { FeatureFlagResponse(flag: $0) },
            organizations: organizations.map { OrganizationDTO(from: $0) }
        )
        
        return try await req.view.render("dashboard", context)
    }
    
    @Sendable
    func createFlag(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Create Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Get user's organizations for the dropdown
        let organizationService = try req.organizationService()
        let organizations = try await organizationService.getForUser(userId: user.id!)
        let organizationDTOs = organizations.map { OrganizationDTO(from: $0) }
        
        // Create context
        let context = OrganizationFlagFormViewContext(
            base: baseContext,
            organizations: organizationDTOs
        )
        
        // Render the feature flag form template
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Show form to edit a feature flag
    @Sendable
    private func editForm(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the flag ID
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Get the feature flag details
        let featureFlagService = req.services.featureFlagService
        let flag = try await featureFlagService.getFlagDetails(id: flagId, userId: user.id!)
        
        // Get the organization if this is an organizational flag
        let organization: OrganizationDTO?
        if let organizationId = flag.organizationId {
            let organizationService = try req.organizationService()
            let org = try await organizationService.get(id: organizationId)
            organization = organizationService.createOrganizationDTO(from: org)
        } else {
            organization = nil
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
            organization: organization,
            flag: flag
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    // MARK: - Form Handlers
    
    @Sendable
    func handleCreateFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Validate and decode the form data
        try CreateFeatureFlagRequest.validate(content: req)
        let create = try req.content.decode(CreateFeatureFlagRequest.self)
        
        do {
            // Create the feature flag
            _ = try await req.services.featureFlagService.createFlag(create, userId: user.id!)
            
            // Redirect to the dashboard with a success message
            req.session.flash(.success, "Feature flag created successfully")
            return req.redirect(to: "/dashboard")
        } catch {
            // If there's an error, render the form again with the error message
            let baseContext = BaseViewContext(
                title: "Create Feature Flag",
                isAuthenticated: true,
                isAdmin: user.isAdmin,
                user: user,
                errorMessage: error.localizedDescription
            )
            
            // Get user's organizations for the dropdown
            let organizationService = try req.organizationService()
            let organizations = try await organizationService.getForUser(userId: user.id!)
            let organizationDTOs = organizations.map { OrganizationDTO(from: $0) }
            
            // Create context
            let context = OrganizationFlagFormViewContext(
                base: baseContext,
                organizations: organizationDTOs
            )
            
            return try await req.view.render("organization-flag-form", context).encodeResponse(for: req)
        }
    }
    
    /// Update a personal feature flag
    @Sendable
    func updatePersonalFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the flag ID from the request parameters
        guard let flagId = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Parse form data
        let formData = try req.content.decode(UpdateFeatureFlagRequest.self)
        
        // Update the flag
        let featureFlagService = req.services.featureFlagService
        _ = try await featureFlagService.updateFlag(id: flagId, formData, userId: user.id!)
        
        // Redirect to the dashboard
        return req.redirect(to: "/dashboard")
    }
    
    /// Delete a personal feature flag
    @Sendable
    func deletePersonalFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the flag ID from the request parameters
        guard let flagId = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Delete the flag
        let featureFlagService = req.services.featureFlagService
        try await featureFlagService.deleteFlag(id: flagId, userId: user.id!)
        
        // Redirect to the dashboard
        return req.redirect(to: "/dashboard")
    }
} 