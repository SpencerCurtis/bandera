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
            .map { UserResponse(user: $0) }
        
        // Get all organizations
        let organizations = try await Organization.query(on: req.db)
            .sort(\.$name)
            .all()
            .map { OrganizationDTO(from: $0) }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Admin Dashboard",
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            user: try await User.find(UUID(uuidString: payload.subject.value), on: req.db)
        )
        
        // Create health info
        let healthInfo = AdminDashboardViewContext.HealthInfo(
            uptime: "N/A",
            databaseConnected: true,
            redisConnected: true,
            memoryUsage: "N/A",
            lastDeployment: "N/A"
        )
        
        // Create admin dashboard context
        let context = AdminDashboardViewContext(
            base: baseContext,
            users: users,
            organizations: organizations,
            healthInfo: healthInfo
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