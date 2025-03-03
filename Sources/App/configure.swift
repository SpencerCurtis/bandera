import NIOSSL
import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor
import Redis
import JWT

/// Configures the Vapor application.
///
/// This function sets up all the components of the application including:
/// - Middleware configuration
/// - Database connection
/// - Redis connection
/// - JWT authentication
/// - Migrations
/// - Services
/// - View engine
/// - Routes
///
/// - Parameter app: The Vapor application to configure
/// - Throws: An error if configuration fails
public func configure(_ app: Application) async throws {
    // MARK: - Middleware Configuration
    
    // Serve static files from the Public directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Configure session management
    app.sessions.use(.memory)
    app.middleware.use(SessionsMiddleware(session: app.sessions.driver))
    app.middleware.use(app.sessions.middleware)
    
    // Register custom error middleware (should be first in the chain)
    // This middleware handles errors and converts them to appropriate HTTP responses
    app.registerErrorMiddleware()
    
    // Add unified authentication middleware
    // This middleware handles JWT and cookie-based authentication
    app.middleware.use(AuthMiddleware.standard)

    // MARK: - Database Configuration
    
    // Configure SQLite database for development and testing
    // In production, this would typically be replaced with PostgreSQL
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    // MARK: - Redis Configuration
    
    // Configure Redis for caching and real-time updates
    // Redis connection parameters can be customized via environment variables
    app.redis.configuration = try RedisConfiguration(
        hostname: Environment.get("REDIS_HOST") ?? "localhost",
        port: Environment.get("REDIS_PORT").flatMap(Int.init(_:)) ?? 6379,
        password: Environment.get("REDIS_PASSWORD")
    )

    // MARK: - JWT Configuration
    
    // Configure JWT for secure authentication
    // The secret key should be set via environment variables in production
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
    }

    // Run migrations automatically
    try await app.autoMigrate()
    
    // MARK: - Service Configuration
    
    // Initialize service container with the application
    // This sets up all services and repositories
    let serviceContainer = ServiceContainer(app: app)
    app.services = serviceContainer
    
    // MARK: - View Configuration
    
    // Configure Leaf as the templating engine for views
    app.views.use(.leaf)

    // MARK: - Routes Configuration
    
    // Register all application routes
    try routes(app)
}
