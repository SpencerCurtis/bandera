import Vapor

/// Container for all services and repositories in the application.
final class ServiceContainer: @unchecked Sendable {
    let webSocketService: WebSocketServiceProtocol
    let featureFlagRepository: FeatureFlagRepositoryProtocol
    let userRepository: UserRepositoryProtocol
    let featureFlagService: FeatureFlagServiceProtocol
    let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    /// Initialize a new service container with all dependencies.
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
    var services: ServiceContainer {
        application.services
    }
}