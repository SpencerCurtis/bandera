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
        flags.post(":id", "edit", use: update)
        flags.post(":id", "delete", use: delete)
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
            if let authCookie = req.cookies["bandera-auth-token"] {
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
        
        // Get the user's organizations
        let organizationService = try req.organizationService()
        let organizations = try await organizationService.getForUser(userId: userId)
        
        // Create the context with the feature flags and organizations
        var context = ViewContext(
            title: "Dashboard",
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            user: try await User.find(userId, on: req.db),
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            flags: featureFlags,
            organizations: organizations
        )
        
        // Check for flash messages
        req.getFlashMessages(&context)
        
        // Render the dashboard template
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
            var context = ViewContext(
                title: "Dashboard",
                isAuthenticated: true,
                isAdmin: payload.isAdmin,
                successMessage: "Feature flag created successfully",
                environment: "development",
                uptime: "N/A",
                databaseConnected: true,
                redisConnected: true,
                memoryUsage: "N/A",
                lastDeployment: "N/A"
            )
            
            return req.redirect(to: "/dashboard")
        } catch {
            // If there's an error, render the form again with the error message
            var context = ViewContext(
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
                isAdmin: payload.isAdmin,
                errorMessage: context.errorMessage,
                recoverySuggestion: nil,
                successMessage: context.successMessage,
                flag: flag
            )
            
            // Render the form with the error and flag data
            return try await req.view.render("organization-flag-form", formContext).encodeResponse(for: req)
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
            var context = ViewContext(
                title: "Dashboard",
                isAuthenticated: true,
                isAdmin: payload.isAdmin,
                successMessage: "Feature flag updated successfully",
                environment: "development",
                uptime: "N/A",
                databaseConnected: true,
                redisConnected: true,
                memoryUsage: "N/A",
                lastDeployment: "N/A"
            )
            
            return req.redirect(to: "/dashboard")
        } catch {
            // If there's an error, render the form again with the error message
            var context = ViewContext(
                title: "Edit Feature Flag",
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
                isAdmin: payload.isAdmin,
                errorMessage: context.errorMessage,
                recoverySuggestion: nil,
                successMessage: context.successMessage,
                flag: flag
            )
            
            // Render the form with the error and flag data
            return try await req.view.render("organization-flag-form", formContext).encodeResponse(for: req)
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
        var context = ViewContext(
            title: "Dashboard",
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            successMessage: "Feature flag deleted successfully",
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A"
        )
        
        return req.redirect(to: "/dashboard")
    }
} 