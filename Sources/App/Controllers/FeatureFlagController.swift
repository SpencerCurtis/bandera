import Vapor
import Fluent

/// Controller for feature flag-related routes.
///
/// This controller handles all API endpoints related to feature flags,
/// including creating, updating, deleting, and retrieving feature flags.
/// It enforces authentication and authorization rules to ensure that
/// users can only access and modify their own feature flags unless they
/// have admin privileges.
struct FeatureFlagController: RouteCollection {
    /// Registers all feature flag routes with the application.
    ///
    /// - Parameter routes: The routes builder to register routes with
    /// - Throws: An error if route registration fails
    func boot(routes: RoutesBuilder) throws {
        // Create a route group that requires authentication
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
    
    /// Creates a new feature flag.
    ///
    /// This endpoint allows authenticated users to create a new feature flag.
    /// The feature flag will be associated with the authenticated user.
    ///
    /// - Parameter req: The HTTP request
    /// - Returns: The created feature flag
    /// - Throws: An error if validation fails or the feature flag cannot be created
    @Sendable
    func create(req: Request) async throws -> FeatureFlag {
        // Validate the request content against the DTO's validation rules
        try DTOs.CreateRequest.validate(content: req)
        let create = try req.content.decode(DTOs.CreateRequest.self)
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        // Use the feature flag service to create the flag
        return try await req.services.featureFlagService.createFlag(create, userId: userId)
    }
    
    /// Updates an existing feature flag.
    ///
    /// This endpoint allows authenticated users to update a feature flag they own.
    /// Users can only update their own feature flags unless they have admin privileges.
    ///
    /// - Parameter req: The HTTP request
    /// - Returns: The updated feature flag
    /// - Throws: An error if validation fails or the feature flag cannot be updated
    @Sendable
    func update(req: Request) async throws -> FeatureFlag {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw BanderaError.validationFailed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        // Validate and decode the update request
        try DTOs.UpdateRequest.validate(content: req)
        let update = try req.content.decode(DTOs.UpdateRequest.self)
        
        // Use the feature flag service to update the flag
        return try await req.services.featureFlagService.updateFlag(id: id, update, userId: userId)
    }
    
    /// Deletes a feature flag.
    ///
    /// This endpoint allows authenticated users to delete a feature flag they own.
    /// Users can only delete their own feature flags unless they have admin privileges.
    ///
    /// - Parameter req: The HTTP request
    /// - Returns: HTTP status 200 OK if successful
    /// - Throws: An error if the feature flag cannot be deleted
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        // Get the flag ID from the request parameters
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw BanderaError.validationFailed("Invalid feature flag ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        // Use the feature flag service to delete the flag
        try await req.services.featureFlagService.deleteFlag(id: id, userId: userId)
        
        return .ok
    }
    
    /// Gets all feature flags for a specific user.
    ///
    /// This endpoint allows authenticated users to retrieve all feature flags for a specific user.
    /// Users can only retrieve their own feature flags unless they have admin privileges.
    ///
    /// - Parameter req: The HTTP request
    /// - Returns: A container with all feature flags and their overrides for the user
    /// - Throws: An error if the feature flags cannot be retrieved
    @Sendable
    func getForUser(req: Request) async throws -> DTOs.FlagsContainer {
        // Get the user ID from the request parameters
        guard let userId = req.parameters.get("userId") else {
            throw BanderaError.validationFailed("Invalid user ID")
        }
        
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self) else {
            throw BanderaError.authenticationRequired
        }
        
        // Only allow access to own flags or if admin
        if !payload.isAdmin && payload.subject.value != userId {
            throw BanderaError.accessDenied
        }
        
        // Use the feature flag service to get flags with overrides
        return try await req.services.featureFlagService.getFlagsWithOverrides(userId: userId)
    }
    
    /// Lists all feature flags for the authenticated user.
    ///
    /// This endpoint allows authenticated users to retrieve all their feature flags.
    ///
    /// - Parameter req: The HTTP request
    /// - Returns: An array of feature flags
    /// - Throws: An error if the feature flags cannot be retrieved
    @Sendable
    func list(req: Request) async throws -> [FeatureFlag] {
        // Get the authenticated user
        guard let payload = req.auth.get(UserJWTPayload.self),
              let userId = UUID(payload.subject.value) else {
            throw BanderaError.authenticationRequired
        }
        
        // Use the feature flag service to get all flags for the user
        return try await req.services.featureFlagService.getAllFlags(userId: userId)
    }
} 