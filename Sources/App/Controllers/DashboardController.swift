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
    
    // MARK: - Context Structs
    
    // Dashboard context with feature flags
    struct DashboardContext: Content {
        var title: String
        var isAuthenticated: Bool
        var error: String?
        var recoverySuggestion: String?
        var success: String?
        var flags: [FeatureFlag]
    }
    
    // Feature flag form context
    struct FeatureFlagFormContext: Content {
        var title: String
        var isAuthenticated: Bool
        var error: String?
        var recoverySuggestion: String?
        var success: String?
        var flag: FeatureFlag?
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
            throw AuthenticationError.authenticationRequired
        }
        
        // Get user-specific flags using the feature flag service
        let featureFlags = try await req.services.featureFlagService.getAllFlags(userId: userId)
        
        // Create the context with the feature flags
        let context = ViewContext(title: "Dashboard")
        
        // Create the dashboard context
        let dashboardContext = DashboardContext(
            title: context.title,
            isAuthenticated: true,
            error: context.error,
            recoverySuggestion: context.recoverySuggestion,
            success: context.success,
            flags: featureFlags
        )
        
        // Render the dashboard template
        return try await req.view.render("dashboard", dashboardContext)
    }
    
    @Sendable
    func createForm(req: Request) async throws -> View {
        // Create the context for the form
        let context = ViewContext(title: "Create Feature Flag")
        
        // Create the form context
        let formContext = FeatureFlagFormContext(
            title: context.title,
            isAuthenticated: true,
            error: context.error,
            recoverySuggestion: context.recoverySuggestion,
            success: context.success,
            flag: nil
        )
        
        // Render the feature flag form template
        return try await req.view.render("feature-flag-form", formContext)
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
        let context = ViewContext(title: "Edit Feature Flag")
        
        // Create the form context
        let formContext = FeatureFlagFormContext(
            title: context.title,
            isAuthenticated: true,
            error: context.error,
            recoverySuggestion: context.recoverySuggestion,
            success: context.success,
            flag: flag
        )
        
        // Render the feature flag form template
        return try await req.view.render("feature-flag-form", formContext)
    }
    
    // MARK: - Form Handlers
    
    @Sendable
    func create(req: Request) async throws -> Response {
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
            var context = ViewContext(title: "Dashboard")
            context.isAuthenticated = true
            context.success = "Feature flag created successfully"
            
            return req.redirect(to: "/dashboard")
        } catch {
            // If there's an error, render the form again with the error message
            let context = ViewContext(title: "Create Feature Flag")
            
            // Create a feature flag from the form data
            let flag = FeatureFlag(
                key: create.key,
                type: create.type,
                defaultValue: create.defaultValue,
                description: create.description
            )
            
            // Create the form context
            let formContext = FeatureFlagFormContext(
                title: context.title,
                isAuthenticated: true,
                error: error.localizedDescription,
                recoverySuggestion: context.recoverySuggestion,
                success: context.success,
                flag: flag
            )
            
            // Render the form with the error and flag data
            return try await req.view.render("feature-flag-form", formContext).encodeResponse(for: req)
        }
    }
    
    @Sendable
    func update(req: Request) async throws -> Response {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Validate and decode the form data
        try UpdateFeatureFlagRequest.validate(content: req)
        let update = try req.content.decode(UpdateFeatureFlagRequest.self)
        
        do {
            // Update the feature flag
            _ = try await req.services.featureFlagService.updateFlag(id: id, update, userId: userId)
            
            // Redirect to the dashboard with a success message
            var context = ViewContext(title: "Dashboard")
            context.isAuthenticated = true
            context.success = "Feature flag updated successfully"
            
            return req.redirect(to: "/dashboard")
        } catch {
            // If there's an error, render the form again with the error message
            let context = ViewContext(title: "Edit Feature Flag")
            
            // Create a feature flag from the form data
            let flag = FeatureFlag(
                id: id,
                key: update.key,
                type: update.type,
                defaultValue: update.defaultValue,
                description: update.description
            )
            
            // Create the form context
            let formContext = FeatureFlagFormContext(
                title: context.title,
                isAuthenticated: true,
                error: error.localizedDescription,
                recoverySuggestion: context.recoverySuggestion,
                success: context.success,
                flag: flag
            )
            
            // Render the form with the error and flag data
            return try await req.view.render("feature-flag-form", formContext).encodeResponse(for: req)
        }
    }
    
    @Sendable
    func delete(req: Request) async throws -> Response {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Delete the feature flag
        try await req.services.featureFlagService.deleteFlag(id: id, userId: userId)
        
        // Redirect to the dashboard with a success message
        var context = ViewContext(title: "Dashboard")
        context.isAuthenticated = true
        context.success = "Feature flag deleted successfully"
        
        return req.redirect(to: "/dashboard")
    }
} 