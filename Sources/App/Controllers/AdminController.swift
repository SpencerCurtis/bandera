import Vapor
import Fluent

struct AdminController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Create admin routes protected by admin middleware
        let adminRoutes = routes.grouped(JWTAuthMiddleware.admin)
        
        // Users management routes
        adminRoutes.get("admin", "users", use: listUsers)
        adminRoutes.post("admin", "users", ":userId", "toggle-admin", use: toggleAdmin)
    }
    
    // MARK: - View Handlers
    
    /// List all users with their admin status
    @Sendable
    func listUsers(req: Request) async throws -> View {
        // Get all users
        let users = try await User.query(on: req.db)
            .sort(\.$email)
            .all()
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Create the context
        let context = ViewContext(
            title: "Admin Dashboard",
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            user: try await User.find(UUID(payload.subject.value), on: req.db),
            environment: "development",
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A",
            users: users.map { UserResponse(user: $0) }
        )
        
        // Render the admin dashboard template
        return try await req.view.render("admin-dashboard", context)
    }
    
    // MARK: - Form Handlers
    
    /// Toggle admin status for a user
    @Sendable
    func toggleAdmin(req: Request) async throws -> Response {
        // Get the target user ID
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        // Get the target user
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Toggle admin status
        user.isAdmin.toggle()
        try await user.save(on: req.db)
        
        // Add success message
        req.session.flash(.success, "\(user.email) admin status updated successfully")
        
        // Redirect back to admin dashboard
        return req.redirect(to: "/admin/users")
    }
} 