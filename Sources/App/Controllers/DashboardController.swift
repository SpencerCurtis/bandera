import Vapor
import Fluent

// Renamed from AdminController to DashboardController to reflect its more general purpose
struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Use the new AuthMiddleware instead of UserJWTPayload.authenticator()
        let protected = routes.grouped(AuthMiddleware.standard)
        
        // Rename from admin to dashboard
        let dashboard = protected.grouped("dashboard")
        dashboard.get(use: self.dashboard)
        
        let flags = dashboard.grouped("feature-flags")
        flags.get("create", use: createForm)
        flags.post("create", use: create)
        flags.get(":id", "edit", use: editForm)
        flags.post(":id", "edit", use: update)
        flags.post(":id", "delete", use: delete)
    }
    
    // MARK: - View Handlers
    
    @Sendable
    func dashboard(req: Request) async throws -> View {
        // Add debug logging
        req.logger.debug("Dashboard route accessed")
        
        // Check if user is authenticated
        if let payload = req.auth.get(UserJWTPayload.self) {
            req.logger.debug("User authenticated: \(payload.subject.value), isAdmin: \(payload.isAdmin)")
        } else {
            req.logger.debug("No authenticated user found in request")
            
            // Check for auth cookie
            if let authCookie = req.cookies["vapor-auth-token"] {
                req.logger.debug("Auth cookie found: \(authCookie.string)")
            } else {
                req.logger.debug("No auth cookie found")
            }
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            req.logger.debug("Authentication failed, redirecting to login")
            throw BanderaError.authenticationRequired
        }
        
        // Get user-specific flags using the feature flag service
        let userFlags = try await req.services.featureFlagService.getFlagsWithOverrides(userId: userId.uuidString)
        
        // Convert FeatureFlag.Response objects to FeatureFlag objects
        let featureFlags = Array(userFlags.flags.values).map { response in
            FeatureFlag(
                id: response.id,
                key: response.key,
                type: response.type,
                defaultValue: response.value,
                description: response.description,
                userId: userId
            )
        }
        
        let context = ViewContextDTOs.DashboardContext(flags: featureFlags, isAuthenticated: true)
        return try await req.view.render("dashboard", context)
    }
    
    @Sendable
    func createForm(req: Request) async throws -> View {
        let context = ViewContextDTOs.FeatureFlagFormContext(isAuthenticated: true)
        return try await req.view.render("feature-flag-form", context)
    }
    
    @Sendable
    func editForm(req: Request) async throws -> View {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value),
              let flagId = req.parameters.get("id", as: UUID.self) else {
            throw BanderaError.resourceNotFound("Feature flag")
        }
        
        // Get the flag using the feature flag service
        let flag = try await req.services.featureFlagService.getFlag(id: flagId, userId: userId)
        
        let context = ViewContextDTOs.FeatureFlagFormContext(flag: flag, isAuthenticated: true)
        return try await req.view.render("feature-flag-form", context)
    }
    
    // MARK: - Action Handlers
    
    @Sendable
    func create(req: Request) async throws -> Response {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        try FeatureFlagDTOs.CreateRequest.validate(content: req)
        let create = try req.content.decode(FeatureFlagDTOs.CreateRequest.self)
        
        do {
            // Use the feature flag service to create the flag
            _ = try await req.services.featureFlagService.createFlag(create, userId: userId)
            return req.redirect(to: "/dashboard")
        } catch BanderaError.resourceAlreadyExists {
            // Handle the case where the flag already exists
            let context = ViewContextDTOs.FeatureFlagFormContext(
                create: create,
                isAuthenticated: true,
                error: "A feature flag with this key already exists"
            )
            return try await req.view.render("feature-flag-form", context).encodeResponse(for: req)
        }
    }
    
    @Sendable
    func update(req: Request) async throws -> Response {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value),
              let flagId = req.parameters.get("id", as: UUID.self) else {
            throw BanderaError.resourceNotFound("Feature flag")
        }
        
        try FeatureFlagDTOs.UpdateRequest.validate(content: req)
        var update = try req.content.decode(FeatureFlagDTOs.UpdateRequest.self)
        update.id = flagId  // Set the ID from the URL parameter
        
        do {
            // Use the feature flag service to update the flag
            _ = try await req.services.featureFlagService.updateFlag(id: flagId, update, userId: userId)
            return req.redirect(to: "/dashboard")
        } catch BanderaError.resourceAlreadyExists {
            // Handle the case where the flag with the new key already exists
            let context = ViewContextDTOs.FeatureFlagFormContext(
                update: update,
                isAuthenticated: true,
                error: "A feature flag with this key already exists"
            )
            return try await req.view.render("feature-flag-form", context).encodeResponse(for: req)
        }
    }
    
    @Sendable
    func delete(req: Request) async throws -> Response {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value),
              let flagId = req.parameters.get("id", as: UUID.self) else {
            throw BanderaError.resourceNotFound("Feature flag")
        }
        
        // Use the feature flag service to delete the flag
        try await req.services.featureFlagService.deleteFlag(id: flagId, userId: userId)
        
        return req.redirect(to: "/dashboard")
    }
} 