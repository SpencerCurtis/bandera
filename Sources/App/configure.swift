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
    
    // Configure CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors)
    
    // Serve static files from the Public directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Configure session management
    app.sessions.use(.memory)
    app.middleware.use(SessionsMiddleware(session: app.sessions.driver))
    app.middleware.use(app.sessions.middleware)
    
    // Register custom error middleware (should be first in the chain)
    app.registerErrorMiddleware()
    
    // MARK: - Database Configuration
    
    // Only configure the database if it hasn't been configured for testing
    let useTestDatabase = app.storage[TestDatabaseKey.self] ?? false
    if !useTestDatabase {
        // Configure SQLite database for development and testing
        app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }

    // MARK: - Redis Configuration
    
    // Configure Redis for caching and real-time updates
    app.redis.configuration = try RedisConfiguration(
        hostname: Environment.get("REDIS_HOST") ?? "localhost",
        port: Environment.get("REDIS_PORT").flatMap(Int.init(_:)) ?? 6379,
        password: Environment.get("REDIS_PASSWORD")
    )

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
