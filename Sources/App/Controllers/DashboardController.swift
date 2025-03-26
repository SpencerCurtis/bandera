import Vapor
import Fluent

// Renamed from AdminController to DashboardController to reflect its more general purpose
struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Protected routes require authentication
        let protected = routes.grouped(JWTAuthMiddleware.standard)
        
        protected.get("dashboard", use: dashboard)
        protected.get("dashboard", "feature-flags", "create", use: createFlag)
        protected.post("dashboard", "feature-flags", "create", use: handleCreateFlag)
        
        let flags = protected.grouped("dashboard", "feature-flags")
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
        
        // Create view context
        let context = ViewContext(
            title: "Dashboard",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            flags: featureFlags,
            organizations: organizations.map { OrganizationDTO(from: $0) }
        )
        
        return try await req.view.render("dashboard", context)
    }
    
    @Sendable
    func createFlag(req: Request) async throws -> View {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Create the context for the form
        let context = ViewContext(
            title: "Create Feature Flag",
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A"
        )
        
        // Create the form context
        let formContext = FeatureFlagFormContext(
            title: context.title,
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            errorMessage: context.errorMessage,
            recoverySuggestion: nil,
            successMessage: context.successMessage,
            flag: nil
        )
        
        // Render the feature flag form template
        return try await req.view.render("organization-flag-form", formContext)
    }
    
    @Sendable
    func editForm(req: Request) async throws -> View {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Get the feature flag
        let flag = try await req.services.featureFlagService.getFlag(id: id, userId: userId)
        if flag.id == nil {
            throw ResourceError.notFound("feature flag")
        }
        
        // Create the context with the feature flag
        let context = ViewContext(
            title: "Edit Feature Flag",
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            editing: true,
            flag: flag
        )
        
        // Create the form context
        let formContext = FeatureFlagFormContext(
            title: context.title,
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            errorMessage: context.errorMessage,
            recoverySuggestion: nil,
            successMessage: context.successMessage,
            flag: flag
        )
        
        // Render the feature flag form template
        return try await req.view.render("organization-flag-form", formContext)
    }
    
    // MARK: - Form Handlers
    
    @Sendable
    func handleCreateFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Validate and decode the form data
        try CreateFeatureFlagRequest.validate(content: req)
        let create = try req.content.decode(CreateFeatureFlagRequest.self)
        
        do {
            // Create the feature flag
            _ = try await req.services.featureFlagService.createFlag(create, userId: userId)
            
            // Redirect to the dashboard with a success message
            req.session.flash(.success, "Feature flag created successfully")
            return req.redirect(to: "/dashboard")
        } catch {
            // If there's an error, render the form again with the error message
            let context = ViewContext(
                title: "Create Feature Flag",
                isAuthenticated: true,
                isAdmin: payload.isAdmin,
                errorMessage: error.localizedDescription,
                environment: "development",
                uptime: "N/A",
                databaseConnected: true,
                redisConnected: true,
                memoryUsage: "N/A",
                lastDeployment: "N/A"
            )
            
            return try await req.view.render("feature-flag-form", context).encodeResponse(for: req)
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