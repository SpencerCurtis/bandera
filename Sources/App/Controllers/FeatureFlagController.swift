import Vapor
import Fluent

struct FeatureFlagController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserJWTPayload.authenticator())
        let featureFlags = protected.grouped("feature-flags")
        
        // Admin-only routes
        let adminProtected = featureFlags.grouped(AdminMiddleware())
        adminProtected.post(use: create)
        adminProtected.put(":id", use: update)
        adminProtected.delete(":id", use: delete)
        
        // User routes
        featureFlags.get("user", ":userId", use: getForUser)
        featureFlags.get(use: list)
    }
    
    // MARK: - Admin Routes
    
    @Sendable
    func create(req: Request) async throws -> FeatureFlag {
        try FeatureFlag.Create.validate(content: req)
        let create = try req.content.decode(FeatureFlag.Create.self)
        
        // Check if flag with same key exists
        if try await FeatureFlag.query(on: req.db)
            .filter(\FeatureFlag.$key, .equal, create.key)
            .first() != nil {
            throw Abort(.conflict, reason: "A feature flag with this key already exists")
        }
        
        let flag = FeatureFlag(
            key: create.key,
            type: create.type,
            defaultValue: create.defaultValue,
            description: create.description
        )
        
        try await flag.save(on: req.db)
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
        
        let update = try req.content.decode(FeatureFlag.Update.self)
        
        // If key is being changed, check for conflicts
        if update.key != flag.key {
            if try await FeatureFlag.query(on: req.db)
                .filter(\FeatureFlag.$key, .equal, update.key)
                .first() != nil {
                throw Abort(.conflict, reason: "A feature flag with this key already exists")
            }
        }
        
        flag.key = update.key
        flag.type = update.type
        flag.defaultValue = update.defaultValue
        flag.description = update.description
        
        try await flag.save(on: req.db)
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
        
        try await flag.delete(on: req.db)
        return .noContent
    }
    
    // MARK: - User Routes
    
    @Sendable
    func getForUser(req: Request) async throws -> [String: FeatureFlag.Response] {
        guard let userId = req.parameters.get("userId") else {
            throw Abort(.badRequest)
        }
        
        // Get all feature flags
        let flags = try await FeatureFlag.query(on: req.db).all()
        
        // Get user overrides
        let overrides = try await UserFeatureFlag.query(on: req.db)
            .filter(\UserFeatureFlag.$userId, .equal, userId)
            .with(\.$featureFlag)
            .all()
        
        // Create response dictionary
        var response: [String: FeatureFlag.Response] = [:]
        
        for flag in flags {
            let override = overrides.first { $0.$featureFlag.id == flag.id }
            response[flag.key] = .init(
                id: flag.id!,
                key: flag.key,
                type: flag.type,
                value: override?.value ?? flag.defaultValue,
                isOverridden: override != nil,
                description: flag.description
            )
        }
        
        return response
    }
    
    @Sendable
    func list(req: Request) async throws -> [FeatureFlag] {
        try await FeatureFlag.query(on: req.db).all()
    }
}

// MARK: - Response DTO
extension FeatureFlag {
    struct Response: Content {
        let id: UUID
        let key: String
        let type: FeatureFlagType
        let value: String
        let isOverridden: Bool
        let description: String?
    }
}