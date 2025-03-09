import Vapor

/// Controller for displaying all available routes in the application
struct RoutesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Create a route group with authentication and admin role check
        // Use AuthMiddleware.standard instead of RedirectingAuthMiddleware to avoid redirect loops
        let protectedRoutes = routes
            .grouped(AuthMiddleware.standard) // Require authentication without redirect
            .grouped(RoleAuthMiddleware())    // Require admin role
        
        // Create a route for viewing all routes (admin only)
        let routesRoute = protectedRoutes.get("routes", use: listRoutes)
        routesRoute.userInfo["description"] = "Admin-only page that displays all available routes in the application"
    }
    
    /// Handler for displaying all available routes
    @Sendable
    func listRoutes(req: Request) async throws -> View {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self) else {
            throw AuthenticationError.authenticationRequired
        }
        
        // Get all routes from the application
        let routes = req.application.routes.all
        
        // Create route info objects
        var routeInfos: [RouteInfo] = []
        
        for route in routes {
            let path = route.path.map { "\($0)" }.joined(separator: "/")
            let method = route.method.rawValue
            let description = route.userInfo["description"] as? String ?? ""
            
            // Determine the group based on the first path component
            let group: String
            if path.isEmpty {
                group = "Root"
            } else {
                let components = path.split(separator: "/")
                group = components.first.map { String($0) } ?? "Other"
            }
            
            routeInfos.append(RouteInfo(
                path: path.isEmpty ? "/" : "/\(path)",
                method: method,
                description: description,
                group: group
            ))
        }
        
        // Sort routes by group and then by path for better readability
        routeInfos.sort { 
            if $0.group != $1.group {
                return $0.group < $1.group
            }
            return $0.path < $1.path
        }
        
        // Group the routes
        let groupedRoutesDict = Dictionary(grouping: routeInfos) { $0.group }
        
        // Convert the dictionary to an array of GroupedRoutes for the template
        let groupedRoutes = groupedRoutesDict.map { key, value in
            return GroupedRoutes(key: key, value: value)
        }.sorted { $0.key < $1.key }
        
        // Create the context
        let context = RoutesContext(
            title: "Application Routes",
            isAuthenticated: true,
            isAdmin: payload.isAdmin,
            routes: routeInfos,
            groupedRoutes: groupedRoutes
        )
        
        // Render the routes template
        return try await req.view.render("routes", context)
    }
}

/// Information about a route
struct RouteInfo: Content {
    var path: String
    var method: String
    var description: String
    var group: String
}

/// Grouped routes for the template
struct GroupedRoutes: Content {
    var key: String
    var value: [RouteInfo]
}

/// Context for the routes view
struct RoutesContext: Content {
    var title: String
    var isAuthenticated: Bool
    var isAdmin: Bool
    var error: String?
    var recoverySuggestion: String?
    var success: String?
    var routes: [RouteInfo]
    var groupedRoutes: [GroupedRoutes]
} 