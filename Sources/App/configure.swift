import NIOSSL
import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor
import Redis
import JWT

// MARK: - Configuration Constants

/// Application configuration constants
struct AppConstants {
    static let authCookieName = "bandera-auth-token"
    static let jwtExpirationDays = 7
    static let minJWTSecretLength = 32
    static let minSessionSecretLength = 32
}

// Define a storage key for test database flag
public struct TestDatabaseKey: StorageKey {
    public typealias Value = Bool
}

/// Configures the Vapor application.
public func configure(_ app: Application) async throws {
    // Set log level to debug to see our detailed logs
    app.logger.logLevel = .debug
    
    // MARK: - Middleware Configuration
    
    // Configure JWT with environment variable
    guard let jwtKey = Environment.get("JWT_SECRET") else {
        app.logger.critical("JWT_SECRET environment variable is required but not set")
        fatalError("JWT_SECRET environment variable is required. Please check your .env file.")
    }
    
    // Validate JWT key length for security
    guard jwtKey.count >= AppConstants.minJWTSecretLength else {
        app.logger.critical("JWT_SECRET must be at least \(AppConstants.minJWTSecretLength) characters long for security")
        fatalError("JWT_SECRET must be at least \(AppConstants.minJWTSecretLength) characters long for security")
    }
    
    app.jwt.signers.use(.hs256(key: jwtKey))
    app.logger.notice("Configured JWT with environment secret (length: \(jwtKey.count) chars)")
    
    // Configure middleware
    app.middleware = .init()
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(BanderaErrorMiddleware(environment: app.environment))
    
    // Configure sessions
    app.sessions.use(.memory)
    app.logger.debug("Using memory sessions")
    
    // Configure session middleware
    app.middleware.use(SessionsMiddleware(session: app.sessions.driver))
    
    // Configure CORS
    let allowedOrigins: CORSMiddleware.AllowOriginSetting
    if let corsOrigins = Environment.get("CORS_ALLOWED_ORIGINS") {
        let origins = corsOrigins.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        allowedOrigins = .any(origins)
        app.logger.notice("CORS configured for origins: \(origins)")
    } else if app.environment == .development {
        allowedOrigins = .any(["http://localhost:8080", "http://127.0.0.1:8080"])
        app.logger.notice("CORS configured for development (localhost)")
    } else {
        allowedOrigins = .none
        app.logger.notice("CORS disabled for production (configure CORS_ALLOWED_ORIGINS)")
    }
    
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: allowedOrigins,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))
    
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
    
    // MARK: - Development Tools
    
    // Register development commands and routes
    if app.environment == .development || app.environment == .testing {
        // Register development commands
        app.commands.use(ResetAdminPasswordCommand(), as: "reset-admin")
        app.commands.use(ResetPasswordCommand(), as: "reset-password")
        
        // Register development routes
        DevRoutes.register(to: app)
    }
    
    // MARK: - Database Configuration
    
    // Only configure the database if it hasn't been configured for testing
    let useTestDatabase = app.storage[TestDatabaseKey.self] ?? false
    if !useTestDatabase {
        // Configure SQLite database for development and testing
        let databasePath = Environment.get("DATABASE_URL") ?? "db.sqlite"
        app.databases.use(.sqlite(.file(databasePath)), as: .sqlite)
        app.logger.notice("Database configured at: \(databasePath)")
    }

    // MARK: - Migrations
    
    // Add database migrations to set up the schema
    app.migrations.add(CreateUser())
    app.migrations.add(CreateFeatureFlag())
    app.migrations.add(CreateUserFeatureFlag())
    app.migrations.add(AddUserIdToFeatureFlag())
    app.migrations.add(FlagStatus.Migration())
    app.migrations.add(AuditLog.Migration())
    
    // Add organization migrations
    app.migrations.add(CreateOrganization())
    app.migrations.add(OrganizationUser.Migration())
    app.migrations.add(AddOrganizationIdToFeatureFlag())
    
    // Add performance indexes
    app.migrations.add(AddPerformanceIndexes())

    // Add admin user in non-testing environments
    if app.environment != .testing {
        app.migrations.add(CreateAdminUser())
        // Add test users in development environment
        app.migrations.add(CreateTestUsers(environment: app.environment))
        // Add test organizations and flags in development environment
        app.migrations.add(CreateTestData(environment: app.environment))
    }

    // Run migrations automatically unless we're in a test environment
    // In tests, migrations are handled by the test helper
    if app.environment != .testing {
        try await app.autoMigrate()
    }
    
    // MARK: - View Configuration
    
    // Configure Leaf for server-side rendering
    app.views.use(.leaf)
    
    // MARK: - Rate Limiting Configuration
    
    // Create rate limit storage (Redis if available, otherwise in-memory)
    let rateLimitStorage = RateLimitStorageFactory.create(app: app)
    
    // Configure different rate limit middleware for different endpoint types
    let authRateLimit = RateLimitMiddleware(
        maxRequests: 5,    // 5 attempts per minute for auth endpoints
        per: 60,           // 60 seconds
        storage: rateLimitStorage
    )
    
    let apiRateLimit = RateLimitMiddleware(
        maxRequests: 100,  // 100 requests per minute for general API
        per: 60,           // 60 seconds
        storage: rateLimitStorage
    )
    
    app.logger.notice("Rate limiting configured - Auth: 5/min, API: 100/min")
    
    // MARK: - Cache Configuration
    
    // Create cache service (Redis if available, otherwise in-memory)
    let cacheStorage = CacheStorageFactory.create(app: app)
    let cacheService = CacheService(storage: cacheStorage)
    app.logger.notice("Feature flag caching configured - Storage: \(app.redis.configuration != nil ? "Redis" : "In-Memory")")
    
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
    
    let organizationRepository = OrganizationRepository(db: app.db)
    serviceContainer.organizationRepository = organizationRepository
    
    // Initialize services that depend on repositories
    let authService = AuthService(userRepository: userRepository, jwtSigner: app.jwt.signers)
    serviceContainer.authService = authService
    
    let featureFlagService = FeatureFlagService(repository: featureFlagRepository, webSocketService: webSocketService, cacheService: cacheService)
    serviceContainer.featureFlagService = featureFlagService
    serviceContainer.cacheService = cacheService
    
    let organizationService = OrganizationService(
        organizationRepository: organizationRepository,
        userRepository: userRepository
    )
    serviceContainer.organizationService = organizationService
    
    // MARK: - Route Registration
    
    // Public routes
    app.get { req async throws -> Response in
        // If user is authenticated, redirect to dashboard, otherwise to login
        if req.auth.has(User.self) {
            return req.redirect(to: "/dashboard")
        }
        return req.redirect(to: "/auth/login")
    }
    
    // Convenience redirect from /login to /auth/login
    app.get("login") { req -> Response in
        return req.redirect(to: "/auth/login")
    }
    
    // Register the auth controllers with rate limiting
    // Web auth routes (forms) - apply rate limiting to POST endpoints only
    let webAuth = app.grouped("auth")
    webAuth.get("login", use: AuthWebController.loginPage)
    webAuth.get("signup", use: AuthWebController.signupPage)
    webAuth.get("logout", use: AuthWebController.logout)
    
    // Rate-limited web auth POST endpoints
    let rateLimitedWebAuth = webAuth.grouped(authRateLimit)
    rateLimitedWebAuth.post("login", use: AuthWebController.login)
    rateLimitedWebAuth.post("signup", use: AuthWebController.signup)
    
    // API auth routes - apply rate limiting to authentication endpoints
    let apiAuth = app.grouped("api", "auth")
    let apiAuthController = AuthApiController()
    
    // Rate-limited API auth endpoints
    let rateLimitedApiAuth = apiAuth.grouped(authRateLimit)
    rateLimitedApiAuth.post("register", use: apiAuthController.register)
    rateLimitedApiAuth.post("login", use: apiAuthController.login)
    rateLimitedApiAuth.post("refresh", use: apiAuthController.refreshToken)
    
    // Protected API auth endpoints (no rate limiting needed as they require auth)
    let protectedApiAuth = apiAuth.grouped(JWTAuthMiddleware.api)
    protectedApiAuth.post("logout", use: apiAuthController.logout)
    protectedApiAuth.get("me", use: apiAuthController.getCurrentUser)
    
    // Health check routes (no auth required)
    try app.register(collection: HealthController())
    
    // Error controller (no auth required)
    try app.register(collection: ErrorController())
    
    // API routes with JWT API middleware and rate limiting (throws instead of redirects)
    let api = app.grouped(apiRateLimit)
        .grouped(JWTAuthMiddleware.api)
    
    // API organization routes (OrganizationController already includes "api" prefix)
    try api.register(collection: OrganizationController())
    
    // API feature flag routes
    try app.register(collection: FeatureFlagApiController())
    
    // WebSocket routes
    try api.register(collection: WebSocketController())
    
    // Web routes with standard JWT middleware (redirects to login)
    let web = app.grouped(JWTAuthMiddleware.standard)
    
    // Dashboard routes
    let dashboard = web.grouped("dashboard")
    try dashboard.register(collection: DashboardController())
    
    // Feature flag routes (web interface)
    try dashboard.grouped("feature-flags")
        .register(collection: FeatureFlagWebController())
    
    // Organization web routes
    let organizations = dashboard.grouped("organizations")
    try organizations.register(collection: OrganizationWebController())
    try organizations.register(collection: OrganizationMemberWebController())
    try organizations.register(collection: OrganizationFlagWebController())
    try organizations.register(collection: OrganizationFlagOverrideWebController())
    
    // Admin-only routes
    let admin = web.grouped(JWTAuthMiddleware.admin)
    try admin.register(collection: AdminController())
    try admin.register(collection: RoutesController())
    
    // Error test routes (only in development)
    if app.environment == .development {
        app.get("error") { req -> Response in
            throw Abort(.internalServerError, reason: "Test error")
        }
        
        // Register development routes
        DevRoutes.register(to: app)
    }
    
    // Register the catchall route last, after all other routes are registered
    app.get(.catchall) { req -> Response in
        throw Abort(.notFound)
    }
}
