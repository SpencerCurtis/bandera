import Vapor
import Fluent

/// API-focused controller for feature flag management with JSON responses
struct FeatureFlagApiController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let flags = routes.grouped("api", "flags")
            .grouped(JWTAuthMiddleware.api)
        
        // CRUD endpoints
        flags.get(use: getAllFlags)
        flags.post(use: createFlag)
        flags.get(":id", use: getFlagById)
        flags.put(":id", use: updateFlag)
        flags.delete(":id", use: deleteFlag)
        
        // Flag actions
        flags.post(":id", "toggle", use: toggleFlag)
        
        // User-specific endpoints
        flags.get("user", ":userId", use: getFlagsForUser)
        
        // Override management
        flags.get(":id", "overrides", use: getOverrides)
        flags.post(":id", "overrides", use: createOverride)
        flags.delete(":id", "overrides", ":overrideId", use: deleteOverride)
        
        // Import/Export
        flags.post(":id", "import", ":organizationId", use: importFlagToOrganization)
    }
    
    // MARK: - CRUD Endpoints
    
    /// Get all feature flags for the authenticated user
    @Sendable
    func getAllFlags(req: Request) async throws -> [FeatureFlag] {
        let user = try req.auth.require(User.self)
        return try await req.services.featureFlagService.getAllFlags(userId: user.id!)
    }
    
    /// Create a new feature flag
    @Sendable
    func createFlag(req: Request) async throws -> FeatureFlag {
        let user = try req.auth.require(User.self)
        
        try CreateFeatureFlagRequest.validate(content: req)
        let create = try req.content.decode(CreateFeatureFlagRequest.self)
        
        return try await req.services.featureFlagService.createFlag(create, userId: user.id!)
    }
    
    /// Get a specific feature flag by ID
    @Sendable
    func getFlagById(req: Request) async throws -> FeatureFlagDetailDTO {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        let user = try req.auth.require(User.self)
        return try await req.services.featureFlagService.getFlagDetails(id: id, userId: user.id!)
    }
    
    /// Update a feature flag
    @Sendable
    func updateFlag(req: Request) async throws -> FeatureFlag {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        let user = try req.auth.require(User.self)
        
        try UpdateFeatureFlagRequest.validate(content: req)
        let update = try req.content.decode(UpdateFeatureFlagRequest.self)
        
        return try await req.services.featureFlagService.updateFlag(id: id, update, userId: user.id!)
    }
    
    /// Delete a feature flag
    @Sendable
    func deleteFlag(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        let user = try req.auth.require(User.self)
        
        // Verify the user is an admin
        guard user.isAdmin else {
            throw AuthenticationError.insufficientPermissions
        }
        
        try await req.services.featureFlagService.deleteFlag(id: id, userId: user.id!)
        return .ok
    }
    
    // MARK: - Flag Actions
    
    /// Toggle a feature flag on/off
    @Sendable
    func toggleFlag(req: Request) async throws -> FeatureFlag {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        let user = try req.auth.require(User.self)
        return try await req.services.featureFlagService.toggleFlag(id: id, userId: user.id!)
    }
    
    // MARK: - User-specific Endpoints
    
    /// Get feature flags for a specific user
    @Sendable
    func getFlagsForUser(req: Request) async throws -> FeatureFlagsContainer {
        guard let userIdString = req.parameters.get("userId"),
              let userId = UUID(uuidString: userIdString) else {
            throw ValidationError.failed("Invalid user ID")
        }
        
        let user = try req.auth.require(User.self)
        
        // Only allow access to own flags or if admin
        if !user.isAdmin && user.id != userId {
            throw AuthenticationError.insufficientPermissions
        }
        
        return try await req.services.featureFlagService.getFlagsWithOverrides(userId: userIdString)
    }
    
    // MARK: - Override Management
    
    /// Get all overrides for a feature flag
    @Sendable
    func getOverrides(req: Request) async throws -> [UserFeatureFlag] {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        let user = try req.auth.require(User.self)
        
        // Get the flag details to check permissions
        _ = try await req.services.featureFlagService.getFlagDetails(id: id, userId: user.id!)
        
        // Get overrides through repository
        return try await req.services.featureFlagRepository.getOverrides(flagId: id)
    }
    
    /// Create a new override for a feature flag
    @Sendable
    func createOverride(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw ValidationError.failed("Invalid feature flag ID")
        }
        
        let user = try req.auth.require(User.self)
        
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
        
        return .created
    }
    
    /// Delete a feature flag override
    @Sendable
    func deleteOverride(req: Request) async throws -> HTTPStatus {
        guard let _ = req.parameters.get("id", as: UUID.self),
              let overrideId = req.parameters.get("overrideId", as: UUID.self) else {
            throw ValidationError.failed("Invalid ID")
        }
        
        let user = try req.auth.require(User.self)
        
        try await req.services.featureFlagService.deleteOverride(id: overrideId, userId: user.id!)
        return .ok
    }
    
    // MARK: - Import/Export
    
    /// Import a feature flag to an organization
    @Sendable
    func importFlagToOrganization(req: Request) async throws -> FeatureFlag {
        guard let flagId = req.parameters.get("id", as: UUID.self),
              let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid ID")
        }
        
        let user = try req.auth.require(User.self)
        
        return try await req.services.featureFlagService.importFlagToOrganization(
            flagId: flagId,
            organizationId: organizationId,
            userId: user.id!
        )
    }
} 