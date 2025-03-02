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
            throw Abort(.unauthorized)
        }
        
        // Get user-specific flags instead of all flags
        let userFlags = try await FeatureFlag.FlagsContainer.getUserFlags(userId: userId.uuidString, on: req.db)
        
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
        
        let context = DashboardContext(flags: featureFlags, isAuthenticated: true)
        return try await req.view.render("dashboard", context)
    }
    
    @Sendable
    func createForm(req: Request) async throws -> View {
        let context = FeatureFlagFormContext(isAuthenticated: true)
        return try await req.view.render("feature-flag-form", context)
    }
    
    @Sendable
    func editForm(req: Request) async throws -> View {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value),
              let flagId = req.parameters.get("id", as: UUID.self),
              let flag = try await FeatureFlag.find(flagId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Ensure the flag belongs to the current user
        guard flag.$userId.value == userId else {
            throw Abort(.forbidden)
        }
        
        let context = FeatureFlagFormContext(flag: flag, isAuthenticated: true)
        return try await req.view.render("feature-flag-form", context)
    }
    
    // MARK: - Action Handlers
    
    @Sendable
    func create(req: Request) async throws -> Response {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw Abort(.unauthorized)
        }
        
        try FeatureFlag.Create.validate(content: req)
        let create = try req.content.decode(FeatureFlag.Create.self)
        
        // Check if flag with same key exists for this user
        if try await FeatureFlag.query(on: req.db)
            .filter(\FeatureFlag.$key, .equal, create.key)
            .filter(\FeatureFlag.$userId, .equal, userId)
            .first() != nil {
            let context = FeatureFlagFormContext(
                create: create,
                isAuthenticated: true,
                error: "A feature flag with this key already exists"
            )
            return try await req.view.render("feature-flag-form", context).encodeResponse(for: req)
        }
        
        let flag = FeatureFlag(
            key: create.key,
            type: create.type,
            defaultValue: create.defaultValue,
            description: create.description,
            userId: userId
        )
        
        try await flag.save(on: req.db)
        
        return req.redirect(to: "/dashboard")
    }
    
    @Sendable
    func update(req: Request) async throws -> Response {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value),
              let flagId = req.parameters.get("id", as: UUID.self),
              let flag = try await FeatureFlag.find(flagId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Ensure the flag belongs to the current user
        guard flag.$userId.value == userId else {
            throw Abort(.forbidden)
        }
        
        var update = try req.content.decode(FeatureFlag.Update.self)
        update.id = flagId  // Set the ID from the URL parameter
        
        // If key is being changed, check for conflicts with user's own flags
        if update.key != flag.key {
            if try await FeatureFlag.query(on: req.db)
                .filter(\FeatureFlag.$key, .equal, update.key)
                .filter(\FeatureFlag.$userId, .equal, userId)
                .first() != nil {
                let context = FeatureFlagFormContext(
                    update: update,
                    isAuthenticated: true,
                    error: "A feature flag with this key already exists"
                )
                return try await req.view.render("feature-flag-form", context).encodeResponse(for: req)
            }
        }
        
        flag.key = update.key
        flag.type = update.type
        flag.defaultValue = update.defaultValue
        flag.description = update.description
        
        try await flag.save(on: req.db)
        
        return req.redirect(to: "/dashboard")
    }
    
    @Sendable
    func delete(req: Request) async throws -> Response {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value),
              let flagId = req.parameters.get("id", as: UUID.self),
              let flag = try await FeatureFlag.find(flagId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Ensure the flag belongs to the current user
        guard flag.$userId.value == userId else {
            throw Abort(.forbidden)
        }
        
        try await flag.delete(on: req.db)
        return req.redirect(to: "/dashboard")
    }
} 