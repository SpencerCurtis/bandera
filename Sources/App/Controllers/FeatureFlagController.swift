import Vapor
import Fluent

/// Controller for feature flag-related routes.
struct FeatureFlagController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Protected routes require authentication
        let protected = routes.grouped(JWTAuthMiddleware.standard)
        let admin = routes.grouped(JWTAuthMiddleware.admin)
        
        // Feature flag routes
        protected.get("create", use: createForm)
        protected.post("create", use: create)
        protected.get(":id", use: detail)
        protected.post(":id", "toggle", use: toggle)
        admin.post(":id", "delete", use: delete)
    }
    
    /// Renders the create feature flag form
    @Sendable
    func createForm(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Create view context
        let context = ViewContext(
            title: "Create Feature Flag",
            isAuthenticated: true,
            isAdmin: user.isAdmin
        )
        
        return try await req.view.render("feature-flag-form", context)
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
    func delete(req: Request) async throws -> HTTPStatus {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
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
        
        // Get the flag details from the service
        let flag = try await req.services.featureFlagService.getFlagDetails(id: id, userId: user.id!)
        
        // Create view context
        let context = ViewContext(
            title: "Feature Flag Details",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            flag: flag
        )
        
        // Render the view
        return try await req.view.render("feature-flag-detail", context)
    }
    
    /// Toggles a feature flag on/off.
    @Sendable
    func toggle(req: Request) async throws -> Response {
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
}