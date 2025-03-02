import Vapor
import Fluent

struct FeatureFlagController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware.standard)
        let featureFlags = protected.grouped("feature-flags")
        
        // User routes
        featureFlags.get("user", ":userId", use: getForUser)
        featureFlags.get(use: list)
        
        // User-specific routes (no admin required)
        featureFlags.post(use: create)
        featureFlags.put(":id", use: update)
        featureFlags.delete(":id", use: delete)
    }
    
    // MARK: - User Routes
    
    @Sendable
    func create(req: Request) async throws -> FeatureFlag {
        try DTOs.CreateRequest.validate(content: req)
        let create = try req.content.decode(DTOs.CreateRequest.self)
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        // Check if flag with same key exists for this user
        if try await FeatureFlag.query(on: req.db)
            .filter(\FeatureFlag.$key, .equal, create.key)
            .filter(\FeatureFlag.$userId, .equal, userId)
            .first() != nil {
            throw BanderaError.resourceAlreadyExists("A feature flag with this key already exists for your account")
        }
        
        let flag = FeatureFlag.create(from: create, userId: userId)
        try await flag.save(on: req.db)
        
        // Broadcast creation event
        try await req.services.webSocketService.broadcast(
            event: WebSocketDTOs.FeatureFlagEvent.created.rawValue,
            data: WebSocketDTOs.FeatureFlagData(from: flag)
        )
        
        return flag
    }
    
    @Sendable
    func update(req: Request) async throws -> FeatureFlag {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw BanderaError.validationFailed("Invalid feature flag ID")
        }
        
        guard let flag = try await FeatureFlag.find(id, on: req.db) else {
            throw BanderaError.resourceNotFound("Feature flag")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        // Ensure the flag belongs to the current user
        guard flag.userId == userId else {
            throw BanderaError.accessDenied
        }
        
        try DTOs.UpdateRequest.validate(content: req)
        let update = try req.content.decode(DTOs.UpdateRequest.self)
        
        // If key is being changed, check for conflicts with user's own flags
        if update.key != flag.key {
            if try await FeatureFlag.query(on: req.db)
                .filter(\FeatureFlag.$key, .equal, update.key)
                .filter(\FeatureFlag.$userId, .equal, userId)
                .first() != nil {
                throw BanderaError.resourceAlreadyExists("A feature flag with this key already exists for your account")
            }
        }
        
        flag.update(from: update)
        try await flag.save(on: req.db)
        
        // Broadcast update event
        try await req.services.webSocketService.broadcast(
            event: WebSocketDTOs.FeatureFlagEvent.updated.rawValue,
            data: WebSocketDTOs.FeatureFlagData(from: flag)
        )
        
        return flag
    }
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw BanderaError.validationFailed("Invalid feature flag ID")
        }
        
        guard let flag = try await FeatureFlag.find(id, on: req.db) else {
            throw BanderaError.resourceNotFound("Feature flag")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        // Ensure the flag belongs to the current user
        guard flag.userId == userId else {
            throw BanderaError.accessDenied
        }
        
        // Store the ID before deletion for the event
        let flagId = flag.id!
        
        try await flag.delete(on: req.db)
        
        // Broadcast deletion event with just the ID
        try await req.services.webSocketService.broadcast(
            event: WebSocketDTOs.FeatureFlagEvent.deleted.rawValue,
            data: ["id": flagId.uuidString]
        )
        
        return .noContent
    }
    
    @Sendable
    func getForUser(req: Request) async throws -> DTOs.FlagsContainer {
        guard let userId = req.parameters.get("userId") else {
            throw BanderaError.validationFailed("User ID is required")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self) else {
            throw BanderaError.authenticationRequired
        }
        
        // Only allow users to get their own flags unless they're an admin
        if !payload.isAdmin && payload.subject.value != userId {
            throw BanderaError.accessDenied
        }
        
        return try await FeatureFlag.getUserFlags(userId: userId, on: req.db)
    }
    
    @Sendable
    func list(req: Request) async throws -> [FeatureFlag] {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        // Only return flags for the current user unless they're an admin
        if payload.isAdmin {
            return try await FeatureFlag.query(on: req.db).all()
        } else {
            return try await FeatureFlag.query(on: req.db)
                .filter(\FeatureFlag.$userId, .equal, userId)
                .all()
        }
    }
} 