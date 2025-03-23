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
    
    // Start with a fresh middleware configuration
    app.middleware = .init()
    
    // Register custom error middleware (should be first in the chain)
    app.middleware.use(BanderaErrorMiddleware(environment: app.environment))
    
    // Configure CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))
    
    // Serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Configure session management
    app.sessions.use(.memory)
    app.middleware.use(SessionsMiddleware(session: app.sessions.driver))
    
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

    // MARK: - JWT Configuration
    
    // Configure JWT for secure authentication
    app.jwt.signers.use(.hs256(key: Environment.get("JWT_SECRET") ?? "your-default-secret"))

    // MARK: - Migrations
    
    // Add database migrations to set up the schema
    app.migrations.add(CreateUser())
    app.migrations.add(CreateFeatureFlag())
    app.migrations.add(CreateUserFeatureFlag())
    app.migrations.add(AddUserIdToFeatureFlag())

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
    
    // MARK: - Service Configuration
    
    // Initialize service container with the application
    let serviceContainer = ServiceContainer(app: app)
    app.services = serviceContainer
    
    // MARK: - View Configuration
    
    // Configure Leaf as the templating engine for views
    app.views.use(.leaf)

    // MARK: - Routes Configuration
    
    // Register all application routes
    try routes(app)
}
