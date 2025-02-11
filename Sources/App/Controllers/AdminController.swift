import Vapor
import Fluent

struct AdminController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserJWTPayload.authenticator())
            .grouped(AdminMiddleware())
        
        let admin = protected.grouped("admin")
        admin.get("dashboard", use: dashboard)
        
        let flags = admin.grouped("feature-flags")
        flags.get("create", use: createForm)
        flags.post("create", use: create)
        flags.get(":id", "edit", use: editForm)
        flags.post(":id", "edit", use: update)
        flags.post(":id", "delete", use: delete)
    }
    
    // MARK: - View Handlers
    
    @Sendable
    func dashboard(req: Request) async throws -> View {
        let flags = try await FeatureFlag.query(on: req.db).all()
        let context = DashboardContext(flags: flags, isAuthenticated: true)
        return try await req.view.render("dashboard", context)
    }
    
    @Sendable
    func createForm(req: Request) async throws -> View {
        let context = FeatureFlagFormContext(isAuthenticated: true)
        return try await req.view.render("feature-flag-form", context)
    }
    
    @Sendable
    func editForm(req: Request) async throws -> View {
        guard let id = req.parameters.get("id", as: UUID.self),
              let flag = try await FeatureFlag.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        
        let context = FeatureFlagFormContext(flag: flag, isAuthenticated: true)
        return try await req.view.render("feature-flag-form", context)
    }
    
    // MARK: - Action Handlers
    
    @Sendable
    func create(req: Request) async throws -> Response {
        try FeatureFlag.Create.validate(content: req)
        let create = try req.content.decode(FeatureFlag.Create.self)
        
        // Check if flag with same key exists
        if try await FeatureFlag.query(on: req.db)
            .filter(\FeatureFlag.$key, .equal, create.key)
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
            description: create.description
        )
        
        try await flag.save(on: req.db)
        
        return req.redirect(to: "/admin/dashboard")
    }
    
    @Sendable
    func update(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: UUID.self),
              let flag = try await FeatureFlag.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        
        var update = try req.content.decode(FeatureFlag.Update.self)
        update.id = id  // Set the ID from the URL parameter
        
        // If key is being changed, check for conflicts
        if update.key != flag.key {
            if try await FeatureFlag.query(on: req.db)
                .filter(\FeatureFlag.$key, .equal, update.key)
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
        
        return req.redirect(to: "/admin/dashboard")
    }
    
    @Sendable
    func delete(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: UUID.self),
              let flag = try await FeatureFlag.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        
        try await flag.delete(on: req.db)
        return req.redirect(to: "/admin/dashboard")
    }
} 