import Vapor
import Fluent

struct FeatureFlagController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserJWTPayload.authenticator())
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
        try FeatureFlag.Create.validate(content: req)
        let create = try req.content.decode(FeatureFlag.Create.self)
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw Abort(.unauthorized)
        }
        
        // Check if flag with same key exists for this user
        if try await FeatureFlag.query(on: req.db)
            .filter(\FeatureFlag.$key, .equal, create.key)
            .filter(\FeatureFlag.$userId, .equal, userId)
            .first() != nil {
            throw Abort(.conflict, reason: "A feature flag with this key already exists for your account")
        }
        
        let flag = FeatureFlag(
            key: create.key,
            type: create.type,
            defaultValue: create.defaultValue,
            description: create.description,
            userId: userId
        )
        
        try await flag.save(on: req.db)
        
        // Broadcast creation event
        try await req.application.webSocketService.broadcast(
            event: WebSocketService.FeatureFlagEvent.created.rawValue,
            data: flag
        )
        
        return flag
    }
    
    @Sendable
    func update(req: Request) async throws -> FeatureFlag {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let flag = try await FeatureFlag.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw Abort(.unauthorized)
        }
        
        // Ensure the flag belongs to the current user
        guard flag.userId == userId else {
            throw Abort(.forbidden, reason: "You can only update your own feature flags")
        }
        
        let update = try req.content.decode(FeatureFlag.Update.self)
        
        // If key is being changed, check for conflicts with user's own flags
        if update.key != flag.key {
            if try await FeatureFlag.query(on: req.db)
                .filter(\FeatureFlag.$key, .equal, update.key)
                .filter(\FeatureFlag.$userId, .equal, userId)
                .first() != nil {
                throw Abort(.conflict, reason: "A feature flag with this key already exists for your account")
            }
        }
        
        flag.key = update.key
        flag.type = update.type
        flag.defaultValue = update.defaultValue
        flag.description = update.description
        
        try await flag.save(on: req.db)
        
        // Broadcast update event
        try await req.application.webSocketService.broadcast(
            event: WebSocketService.FeatureFlagEvent.updated.rawValue,
            data: flag
        )
        
        return flag
    }
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let flag = try await FeatureFlag.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw Abort(.unauthorized)
        }
        
        // Ensure the flag belongs to the current user
        guard flag.userId == userId else {
            throw Abort(.forbidden, reason: "You can only delete your own feature flags")
        }
        
        try await flag.delete(on: req.db)
        
        // Broadcast deletion event
        try await req.application.webSocketService.broadcast(
            event: WebSocketService.FeatureFlagEvent.deleted.rawValue,
            data: ["id": flag.id!.uuidString]
        )
        
        return .noContent
    }
    
    @Sendable
    func getForUser(req: Request) async throws -> FeatureFlag.FlagsContainer {
        guard let userId = req.parameters.get("userId") else {
            throw Abort(.badRequest)
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self) else {
            throw Abort(.unauthorized)
        }
        
        // Only allow users to get their own flags unless they're an admin
        if !payload.isAdmin && payload.subject.value != userId {
            throw Abort(.forbidden, reason: "You can only access your own feature flags")
        }
        
        return try await FeatureFlag.FlagsContainer.getUserFlags(userId: userId, on: req.db)
    }
    
    @Sendable
    func list(req: Request) async throws -> [FeatureFlag] {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw Abort(.unauthorized)
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