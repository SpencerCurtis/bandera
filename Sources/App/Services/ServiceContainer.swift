import Vapor

/// Container for all services and repositories
final class ServiceContainer: @unchecked Sendable {
    /// The WebSocket service for real-time communication
    let webSocketService: WebSocketServiceProtocol
    
    /// The feature flag repository for data access
    let featureFlagRepository: FeatureFlagRepositoryProtocol
    
    /// The user repository for data access
    let userRepository: UserRepositoryProtocol
    
    /// The feature flag service for business logic
    let featureFlagService: FeatureFlagServiceProtocol
    
    /// The authentication service for business logic
    let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    /// Initialize a new service container with all dependencies
    /// - Parameters:
    ///   - webSocketService: The WebSocket service
    ///   - featureFlagRepository: The feature flag repository
    ///   - userRepository: The user repository
    ///   - featureFlagService: The feature flag service
    ///   - authService: The authentication service
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
    
    /// Convenience initializer that creates all services and repositories
    /// - Parameter app: The application instance
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
    private struct ServiceContainerKey: StorageKey {
        typealias Value = ServiceContainer
    }
    
    /// The application's service container
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
    /// The request's service container
    var services: ServiceContainer {
        application.services
    }
} 