import NIOSSL
import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor
import Redis
import JWT

// Define a storage key for test database flag
private struct TestDatabaseKey: StorageKey {
    typealias Value = Bool
}

/// Configures the Vapor application.
public func configure(_ app: Application) async throws {
    // MARK: - Middleware Configuration
    
    // Configure JWT
    let jwtKey = Environment.get("JWT_SECRET") ?? "bandera-development-key"
    app.jwt.signers.use(.hs256(key: jwtKey))
    app.logger.debug("Configured JWT with key: \(jwtKey.prefix(10))...")
    
    // Configure middleware
    app.middleware = .init()
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(BanderaErrorMiddleware(environment: app.environment))
    app.middleware.use(SessionsMiddleware(session: app.sessions.driver))
    
    // Configure CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))
    
    // Configure sessions
    app.sessions.use(.memory)
    app.logger.debug("Configured memory sessions")
    
    // Configure Redis for rate limiting (if not testing)
    if app.environment != .testing {
        if let redisHost = Environment.get("REDIS_HOST") {
            try app.redis.configuration = .init(
                hostname: redisHost,
                port: Int(Environment.get("REDIS_PORT") ?? "6379") ?? 6379,
                password: Environment.get("REDIS_PASSWORD"),
                pool: .init(
                    maximumConnectionCount: .maximumPreservedConnections(1),
                    minimumConnectionCount: 1,
                    connectionBackoffFactor: 1,
                    initialConnectionBackoffDelay: .milliseconds(100),
                    connectionRetryTimeout: .seconds(1)
                )
            )
            app.logger.notice("Using Redis for rate limiting")
        }
    }
    
    // MARK: - Database Configuration
    
    // Only configure the database if it hasn't been configured for testing
    let useTestDatabase = app.storage[TestDatabaseKey.self] ?? false
    if !useTestDatabase {
        // Configure SQLite database for development and testing
        app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }

    // MARK: - Migrations
    
    // Add database migrations to set up the schema
    app.migrations.add(CreateUser())
    app.migrations.add(CreateFeatureFlag())
    app.migrations.add(CreateUserFeatureFlag())
    app.migrations.add(AddUserIdToFeatureFlag())
    app.migrations.add(FlagStatus.Migration())
    app.migrations.add(AuditLog.Migration())

    // Add admin user in non-testing environments
    if app.environment != .testing {
        app.migrations.add(CreateAdminUser())
        // Add test users in development environment
        app.migrations.add(CreateTestUsers(environment: app.environment))
    }

    // Run migrations automatically unless we're in a test environment
    // In tests, migrations are handled by the test helper
    if app.environment != .testing {
        try await app.autoMigrate()
    }
    
    // MARK: - View Configuration
    
    // Configure Leaf for server-side rendering
    app.views.use(.leaf)
    
    // MARK: - Service Configuration
    
    // Initialize service container with the application
    let serviceContainer = ServiceContainer(app: app)
    app.services = serviceContainer
    
    // Initialize WebSocket service first since other services depend on it
    let webSocketService = WebSocketService()
    serviceContainer.webSocketService = webSocketService
    
    // Initialize repositories
    let userRepository = UserRepository(database: app.db)
    serviceContainer.userRepository = userRepository
    
    let featureFlagRepository = FeatureFlagRepository(database: app.db)
    serviceContainer.featureFlagRepository = featureFlagRepository
    
    // Initialize services that depend on repositories
    let authService = AuthService(userRepository: userRepository, jwtSigner: app.jwt.signers)
    serviceContainer.authService = authService
    
    let featureFlagService = FeatureFlagService(repository: featureFlagRepository, webSocketService: webSocketService)
    serviceContainer.featureFlagService = featureFlagService
    
    // MARK: - Route Registration
    
    // Register routes
    try routes(app)
}
