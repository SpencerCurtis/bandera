import Vapor

/// Container for all services and repositories in the application.
///
/// The ServiceContainer acts as a dependency injection container that provides
/// access to all services and repositories. It ensures that services are properly
/// initialized with their dependencies and makes them available throughout the application.
///
/// This container follows the Service Locator pattern and provides a centralized
/// way to access application services.
final class ServiceContainer: @unchecked Sendable {
    /// The WebSocket service for real-time communication
    /// Handles WebSocket connections and broadcasts feature flag updates
    let webSocketService: WebSocketServiceProtocol
    
    /// The feature flag repository for data access
    /// Provides CRUD operations for feature flags in the database
    let featureFlagRepository: FeatureFlagRepositoryProtocol
    
    /// The user repository for data access
    /// Provides CRUD operations for users in the database
    let userRepository: UserRepositoryProtocol
    
    /// The feature flag service for business logic
    /// Implements business logic for feature flag management
    let featureFlagService: FeatureFlagServiceProtocol
    
    /// The authentication service for business logic
    /// Implements business logic for user authentication and authorization
    let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    /// Initialize a new service container with all dependencies.
    ///
    /// This initializer allows for dependency injection of all services and repositories,
    /// which is particularly useful for testing where mock implementations can be provided.
    ///
    /// - Parameters:
    ///   - webSocketService: The WebSocket service for real-time communication
    ///   - featureFlagRepository: The feature flag repository for data access
    ///   - userRepository: The user repository for data access
    ///   - featureFlagService: The feature flag service for business logic
    ///   - authService: The authentication service for business logic
    init(
        webSocketService: WebSocketServiceProtocol,
        featureFlagRepository: FeatureFlagRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        featureFlagService: FeatureFlagServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.webSocketService = webSocketService
        self.featureFlagRepository = featureFlagRepository
        self.userRepository = userRepository
        self.featureFlagService = featureFlagService
        self.authService = authService
    }
    
    /// Convenience initializer that creates all services and repositories.
    ///
    /// This initializer creates all services and repositories with their default implementations
    /// and wires them together with their dependencies.
    ///
    /// - Parameter app: The application instance providing access to the database and other resources
    convenience init(app: Application) {
        // Create repositories
        let featureFlagRepository = FeatureFlagRepository(database: app.db)
        let userRepository = UserRepository(database: app.db)
        
        // Create WebSocket service
        let webSocketService = WebSocketService()
        
        // Create feature flag service
        let featureFlagService = FeatureFlagService(
            repository: featureFlagRepository,
            webSocketService: webSocketService
        )
        
        // Create auth service
        let authService = AuthService(
            userRepository: userRepository,
            jwtSigner: app.jwt.signers
        )
        
        // Initialize with all services and repositories
        self.init(
            webSocketService: webSocketService,
            featureFlagRepository: featureFlagRepository,
            userRepository: userRepository,
            featureFlagService: featureFlagService,
            authService: authService
        )
    }
}

// MARK: - Application Extension

extension Application {
    /// Storage key for the service container in the application storage
    private struct ServiceContainerKey: StorageKey {
        typealias Value = ServiceContainer
    }
    
    /// The application's service container.
    ///
    /// This property provides access to the application's service container,
    /// creating it if it doesn't already exist. It ensures that only one
    /// service container is created per application instance.
    ///
    /// Usage:
    /// ```swift
    /// let featureFlagService = app.services.featureFlagService
    /// ```
    var services: ServiceContainer {
        get {
            if let existing = storage[ServiceContainerKey.self] {
                return existing
            }
            let new = ServiceContainer(app: self)
            storage[ServiceContainerKey.self] = new
            return new
        }
        set {
            storage[ServiceContainerKey.self] = newValue
        }
    }
}

// MARK: - Request Extension

extension Request {
    /// The request's service container.
    ///
    /// This property provides access to the application's service container
    /// from within a request handler.
    ///
    /// Usage:
    /// ```swift
    /// func handler(req: Request) async throws -> Response {
    ///     let featureFlagService = req.services.featureFlagService
    ///     // Use the service...
    /// }
    /// ```
    var services: ServiceContainer {
        application.services
    }
} 