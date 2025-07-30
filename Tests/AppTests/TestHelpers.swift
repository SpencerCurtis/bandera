import XCTVapor
import Fluent
import FluentSQLiteDriver
@testable import App

/// Test utilities and helpers for the Bandera application tests
enum TestHelpers {
    
    /// Creates a configured Application instance for testing
    /// - Returns: A configured test Application
    static func createTestApp() async throws -> Application {
        let app = try await Application.make(.testing)
        
        // Set up test environment variables
        Environment.process.JWT_SECRET = "test-jwt-secret-key-with-32-chars-minimum-length-required"
        
        // Configure test database - use in-memory SQLite
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // Mark that we're using a test database
        app.storage[TestDatabaseKey.self] = true
        
        // Configure the application
        try await configure(app)
        
        // Run migrations for test database
        try await app.autoMigrate()
        
        return app
    }
    
    /// Creates a test user in the database
    /// - Parameters:
    ///   - app: The test application
    ///   - email: User email (defaults to test email)
    ///   - password: Plain text password (defaults to "password")
    ///   - isAdmin: Whether user is admin (defaults to false)
    /// - Returns: The created user
    static func createTestUser(
        app: Application,
        email: String = "test@example.com",
        password: String = "password",
        isAdmin: Bool = false
    ) async throws -> User {
        let hashedPassword = try Bcrypt.hash(password)
        let user = User(
            email: email,
            passwordHash: hashedPassword,
            isAdmin: isAdmin
        )
        try await user.save(on: app.db)
        return user
    }
    
    /// Creates a test admin user
    /// - Parameter app: The test application
    /// - Returns: The created admin user
    static func createTestAdmin(app: Application) async throws -> User {
        return try await createTestUser(
            app: app,
            email: "admin@example.com",
            password: "admin123",
            isAdmin: true
        )
    }
    
    /// Creates a test organization
    /// - Parameters:
    ///   - app: The test application
    ///   - name: Organization name (defaults to "Test Organization")
    /// - Returns: The created organization
    static func createTestOrganization(
        app: Application,
        name: String = "Test Organization"
    ) async throws -> Organization {
        let organization = Organization(name: name)
        try await organization.save(on: app.db)
        return organization
    }
    
    /// Creates a test feature flag
    /// - Parameters:
    ///   - app: The test application
    ///   - key: Flag key
    ///   - type: Flag type (defaults to boolean)
    ///   - defaultValue: Default value (defaults to "false")
    ///   - userId: User ID (optional)
    ///   - organizationId: Organization ID (optional)
    /// - Returns: The created feature flag
    static func createTestFeatureFlag(
        app: Application,
        key: String,
        type: FeatureFlagType = .boolean,
        defaultValue: String = "false",
        userId: UUID? = nil,
        organizationId: UUID? = nil
    ) async throws -> FeatureFlag {
        let flag = FeatureFlag(
            key: key,
            type: type,
            defaultValue: defaultValue,
            userId: userId,
            organizationId: organizationId
        )
        try await flag.save(on: app.db)
        return flag
    }
    
    /// Generates a valid JWT token for a user
    /// - Parameters:
    ///   - user: The user to generate token for
    ///   - app: The test application
    /// - Returns: JWT token string
    static func generateTestJWT(for user: User, app: Application) throws -> String {
        let payload = try UserJWTPayload(user: user)
        return try app.jwt.signers.sign(payload)
    }
    
    /// Creates authenticated request headers with JWT token
    /// - Parameters:
    ///   - user: The user to authenticate as
    ///   - app: The test application
    /// - Returns: HTTP headers with authorization
    static func createAuthHeaders(for user: User, app: Application) throws -> HTTPHeaders {
        let token = try generateTestJWT(for: user, app: app)
        return HTTPHeaders([
            ("Authorization", "Bearer \(token)"),
            ("Content-Type", "application/json")
        ])
    }
    
    /// Sets up authentication cookie for web requests
    /// - Parameters:
    ///   - user: The user to authenticate as
    ///   - app: The test application
    /// - Returns: Cookie value for bandera-auth-token
    static func createAuthCookie(for user: User, app: Application) throws -> HTTPCookies.Value {
        let token = try generateTestJWT(for: user, app: app)
        return HTTPCookies.Value(string: token)
    }
    
    /// Cleans up the test database by removing all records
    /// - Parameter app: The test application
    static func cleanupDatabase(app: Application) async throws {
        // Delete in dependency order to avoid foreign key constraints
        // Delete child tables first (tables that reference other tables)
        try await AuditLog.query(on: app.db).delete()
        try await FlagStatus.query(on: app.db).delete()
        try await UserFeatureFlag.query(on: app.db).delete()
        try await OrganizationUser.query(on: app.db).delete()
        
        // Then delete parent tables (tables that are referenced by others)
        try await FeatureFlag.query(on: app.db).delete()
        try await Organization.query(on: app.db).delete()
        try await User.query(on: app.db).delete()
    }
}

// MARK: - Test Database Key Extension

// TestDatabaseKey is now defined in configure.swift and imported via @testable import App

// MARK: - XCTestCase Extensions

extension XCTestCase {
    /// Sets up a test application and returns it
    func setupTestApp() async throws -> Application {
        return try await TestHelpers.createTestApp()
    }
    
    /// Tears down the test application
    func teardownTestApp(_ app: Application) async throws {
        try await TestHelpers.cleanupDatabase(app: app)
        try await app.asyncShutdown()
    }
}

// MARK: - Common Test Assertions

extension XCTestCase {
    /// Asserts that a response contains expected JSON structure
    func assertJSONResponse<T: Content>(
        _ response: XCTHTTPResponse,
        type: T.Type,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        XCTAssertEqual(response.status, .ok, file: file, line: line)
        XCTAssertEqual(response.headers.contentType, .json, file: file, line: line)
        return try response.content.decode(T.self)
    }
    
    /// Asserts that a response is an error with expected status
    func assertErrorResponse(
        _ response: XCTHTTPResponse,
        status: HTTPStatus,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(response.status, status, file: file, line: line)
    }
    
    /// Asserts that a response redirects to expected path
    func assertRedirect(
        _ response: XCTHTTPResponse,
        to path: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue([.seeOther, .found, .movedPermanently].contains(response.status), file: file, line: line)
        XCTAssertEqual(response.headers.first(name: .location), path, file: file, line: line)
    }
} 