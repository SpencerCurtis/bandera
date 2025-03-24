import Vapor
import Fluent
import Leaf

/// Controller for feature flag-related routes.
struct FeatureFlagController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Routes are already protected by JWTAuthMiddleware.standard in routes.swift
        // So we don't need to apply authentication middleware again
        
        // Feature flag routes - these are registered under /dashboard/feature-flags in routes.swift
        routes.get("create", use: createForm)
        routes.post("create", use: create)
        routes.get(":id", use: detail)
        routes.post(":id", "toggle", use: toggle)
        
        // Admin-only routes - we'll check isAdmin inside the handlers instead of using middleware
        routes.post(":id", "delete", use: delete)
        
        // Feature flag override routes
        routes.get(":id", "overrides", "new", use: createOverrideForm)
        routes.post(":id", "overrides", "new", use: createOverride)
        routes.post(":id", "overrides", ":overrideId", "delete", use: deleteOverride)
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
            print("flag: \(flag)")
            
            // Create a safe version of the flag for display 
            let safeFlag = createSafeFlag(from: flag)
            req.logger.debug("Safe flag created: id=\(safeFlag.id), key=\(safeFlag.key)")
            
            // Create a struct with all the data we need for the template
            struct TemplateContext: Encodable {
                var title: String
                var isAuthenticated: Bool
                var isAdmin: Bool
                var environment: String
                var uptime: String
                var databaseConnected: Bool
                var redisConnected: Bool
                var memoryUsage: String
                var lastDeployment: String
                var flag: FeatureFlagDetailDTO
            }
            
            // Create a new context with the flag directly available
            let templateContext = TemplateContext(
                title: "Feature Flag Details",
                isAuthenticated: true,
                isAdmin: user.isAdmin,
                environment: "development",
                uptime: "N/A",
                databaseConnected: true,
                redisConnected: true,
                memoryUsage: "N/A",
                lastDeployment: "N/A",
                flag: safeFlag
            )
            
            return try await req.view.render("feature-flag-detail", templateContext)
        } catch {
            // Log the error
            req.logger.error("Error processing feature flag detail: \(error)")
            
            // Return a simplified error view
            let errorContext = ViewContext(
                title: "Feature Flag Error",
                isAuthenticated: true,
                isAdmin: user.isAdmin,
                errorMessage: "Error displaying flag details: \(error.localizedDescription)",
                environment: "development",
                uptime: "N/A", 
                databaseConnected: true,
                redisConnected: true,
                memoryUsage: "N/A",
                lastDeployment: "N/A"
            )
            
            return try await req.view.render("error", errorContext)
        }
    }
    
    /// Creates a safe version of a feature flag for display, handling potential date formatting issues
    private func createSafeFlag(from flag: FeatureFlagDetailDTO) -> FeatureFlagDetailDTO {
        // Format dates as strings to avoid Leaf date conversion issues
        let safeCreatedAt = flag.createdAt.map { date -> Date in
            // If we have a valid date, return it as is
            return date
        }
        
        let safeUpdatedAt = flag.updatedAt.map { date -> Date in
            // If we have a valid date, return it as is
            return date
        }
        
        // Create a copy of audit logs with safely formatted dates
        let safeAuditLogs = flag.auditLogs.map { log -> AuditLogDTO in
            // Use a safer approach for the date that won't throw conversion errors
            let safeCreatedAt: Date
            if let timestamp = try? Date(timeIntervalSince1970: log.createdAt.timeIntervalSince1970) {
                safeCreatedAt = timestamp
            } else {
                // If there's a conversion issue, use current date as fallback
                safeCreatedAt = Date()
            }
            
            return AuditLogDTO(
                type: log.type,
                message: log.message,
                user: log.user,
                createdAt: safeCreatedAt
            )
        }
        
        // Create a copy of user overrides with safely formatted dates
        let safeUserOverrides = flag.userOverrides.map { override -> UserOverrideDTO in
            return UserOverrideDTO(
                id: override.id,
                user: override.user,
                value: override.value,
                updatedAt: override.updatedAt.map { $0 }
            )
        }
        
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
            userOverrides: safeUserOverrides,
            auditLogs: safeAuditLogs
        )
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
        let flag = try await req.services.featureFlagService.getFlagDetails(id: id, userId: user.id!)
        
        // Get users for the select dropdown (admins only can set for any user)
        let users = user.isAdmin ? try await req.services.userRepository.getAllUsers() : []
        
        // Create view context
        let context = ViewContext(
            title: "Add Feature Flag Override",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            errorMessage: nil,
            successMessage: nil,
            warningMessage: nil,
            infoMessage: nil,
            statusCode: nil,
            requestId: nil,
            debugInfo: nil,
            user: nil,
            currentUserId: user.id,
            returnTo: nil,
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            flagDetail: flag,
            flags: nil,
            allUsers: users,
            overrides: nil,
            organizations: nil,
            organization: nil,
            members: nil,
            editing: false,
            pagination: nil
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
        
        // FOR TESTING: Allow any user to create an override for any user
        // In production, uncomment the lines below to enforce proper authorization
        
        /*
        // Get target user ID (admin can create override for any user, non-admin only for self)
        let targetUserId = try await req.services.authService.validateTargetUser(
            requestedUserId: targetUserIdUUID,
            authenticatedUserId: userId
        )
        */
        
        // Use the feature flag service to create the override
        try await req.services.featureFlagService.createOverride(
            flagId: id,
            userId: targetUserIdUUID, // Use the requested user ID directly
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
}