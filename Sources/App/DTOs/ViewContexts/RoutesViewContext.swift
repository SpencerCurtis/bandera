import Vapor

/// Context for the routes view
struct RoutesViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// Information about a route
    struct RouteInfo: Content {
        /// The route path
        let path: String
        /// The HTTP method
        let method: String
        /// Description of what the route does
        let description: String
        /// The group this route belongs to
        let group: String
    }
    
    /// Grouped routes for the template
    struct GroupedRoutes: Content {
        /// The group name
        let key: String
        /// The routes in this group
        let value: [RouteInfo]
    }
    
    /// All routes in the application
    let routes: [RouteInfo]
    
    /// Routes grouped by their first path component
    let groupedRoutes: [GroupedRoutes]
    
    /// Initialize with base context and routes
    /// - Parameters:
    ///   - base: The base context
    ///   - routes: All routes in the application
    ///   - groupedRoutes: Routes grouped by their first path component
    init(
        base: BaseViewContext,
        routes: [RouteInfo],
        groupedRoutes: [GroupedRoutes]
    ) {
        self.base = base
        self.routes = routes
        self.groupedRoutes = groupedRoutes
    }
} 