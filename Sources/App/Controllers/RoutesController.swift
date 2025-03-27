import Vapor

/// Controller for displaying all available routes in the application
struct RoutesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Create a route for viewing all routes (admin only)
        let adminRoutes = routes.grouped(JWTAuthMiddleware.admin)
        adminRoutes.get("routes", use: listRoutes)
    }
    
    /// Handler for displaying all available routes
    @Sendable
    func listRoutes(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get all routes from the application
        let routes = req.application.routes.all
        
        // Create route info objects
        var routeInfos: [RoutesViewContext.RouteInfo] = []
        
        // Create a set to track unique routes by method and path
        var uniqueRoutes = Set<String>()
        
        for route in routes {
            let path = route.path.map { "\($0)" }.joined(separator: "/")
            let method = route.method.rawValue
            let description = route.userInfo["description"] as? String ?? ""
            
            // Create a unique identifier for this route
            let routeIdentifier = "\(method):\(path)"
            
            // Skip if we've already processed this route
            if uniqueRoutes.contains(routeIdentifier) {
                continue
            }
            
            // Add to our unique routes tracker
            uniqueRoutes.insert(routeIdentifier)
            
            // Determine the group based on the first path component
            let group: String
            if path.isEmpty {
                group = "Root"
            } else {
                let components = path.split(separator: "/")
                group = components.first.map { String($0) } ?? "Other"
            }
            
            routeInfos.append(.init(
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
            return RoutesViewContext.GroupedRoutes(key: key, value: value)
        }.sorted { $0.key < $1.key }
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Application Routes",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create routes context
        let context = RoutesViewContext(
            base: baseContext,
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