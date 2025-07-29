import XCTVapor
import Fluent
@testable import App

final class ErrorHandlingTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
    }
    
    // MARK: - Base View Context Tests
    
    func testCreateBaseViewContextWithoutUser() async throws {
        // Given
        let req = Request(application: app, method: .GET, url: URI("/test"), on: app.eventLoopGroup.next())
        
        // When
        let context = await ErrorHandling.createBaseViewContext(
            for: req,
            title: "Test Title",
            errorMessage: "Test Error",
            warningMessage: "Test Warning"
        )
        
        // Then
        XCTAssertEqual(context.title, "Test Title")
        XCTAssertFalse(context.isAuthenticated)
        XCTAssertFalse(context.isAdmin)
        XCTAssertNil(context.user)
        XCTAssertEqual(context.errorMessage, "Test Error")
        XCTAssertEqual(context.warningMessage, "Test Warning")
    }
    
    func testCreateBaseViewContextWithUser() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        let req = Request(application: app, method: .GET, url: URI("/test"), on: app.eventLoopGroup.next())
        
        // Set up authentication
        let payload = try UserJWTPayload(user: user)
        req.auth.login(payload)
        
        // When
        let context = await ErrorHandling.createBaseViewContext(
            for: req,
            title: "Authenticated Test"
        )
        
        // Then
        XCTAssertEqual(context.title, "Authenticated Test")
        XCTAssertTrue(context.isAuthenticated)
        XCTAssertEqual(context.isAdmin, user.isAdmin)
        XCTAssertEqual(context.user?.id, user.id)
    }
    
    // MARK: - Error View Context Tests
    
    func testCreateErrorViewContextWithBanderaError() async throws {
        // Given
        let req = Request(application: app, method: .GET, url: URI("/test"), on: app.eventLoopGroup.next())
        let error = AuthenticationError.invalidCredentials
        
        // When
        let context = await ErrorHandling.createErrorViewContext(
            for: req,
            error: error
        )
        
        // Then
        XCTAssertEqual(context.statusCode, 401)
        XCTAssertEqual(context.reason, "Invalid email or password")
        XCTAssertEqual(context.recoverySuggestion, "Please check your email and password and try again")
        XCTAssertTrue(context.returnTo)
    }
    
    func testCreateErrorViewContextWithGenericError() async throws {
        // Given
        let req = Request(application: app, method: .GET, url: URI("/test"), on: app.eventLoopGroup.next())
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Generic error"])
        
        // When
        let context = await ErrorHandling.createErrorViewContext(
            for: req,
            error: error,
            statusCode: 500
        )
        
        // Then
        XCTAssertEqual(context.statusCode, 500)
        XCTAssertEqual(context.reason, "An error occurred")
        XCTAssertNil(context.recoverySuggestion)
    }
    
    // MARK: - Request Extension Tests
    
    func testRequestCreateBaseViewContext() async throws {
        // Given
        let req = Request(application: app, method: .GET, url: URI("/test"), on: app.eventLoopGroup.next())
        
        // When
        let context = await req.createBaseViewContext(
            title: "Request Test",
            errorMessage: "Request Error"
        )
        
        // Then
        XCTAssertEqual(context.title, "Request Test")
        XCTAssertEqual(context.errorMessage, "Request Error")
        XCTAssertFalse(context.isAuthenticated)
    }
    
    // MARK: - API Error Response Tests
    
    func testCreateAPIErrorResponseWithBanderaError() throws {
        // Given
        let error = ValidationError.failed("Invalid input")
        
        // When
        let response = ErrorHandling.createAPIErrorResponse(for: error)
        
        // Then
        XCTAssertTrue(response.error)
        XCTAssertEqual(response.reason, "Validation failed: Invalid input")
        XCTAssertEqual(response.statusCode, 400)
        XCTAssertEqual(response.recoverySuggestion, "Please correct the errors and try again.")
    }
    
    func testCreateAPIErrorResponseWithGenericError() throws {
        // Given
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Generic error"])
        
        // When
        let response = ErrorHandling.createAPIErrorResponse(for: error)
        
        // Then
        XCTAssertTrue(response.error)
        XCTAssertEqual(response.reason, "An error occurred")
        XCTAssertEqual(response.statusCode, 500)
        XCTAssertNil(response.recoverySuggestion)
    }
    
    func testCreateAPIErrorResponseWithCustomStatus() throws {
        // Given
        let error = AuthenticationError.invalidCredentials
        
        // When
        let response = ErrorHandling.createAPIErrorResponse(for: error, status: .forbidden)
        
        // Then
        XCTAssertTrue(response.error)
        XCTAssertEqual(response.reason, "Invalid email or password")
        XCTAssertEqual(response.statusCode, 403) // Custom status overrides error status
        XCTAssertEqual(response.recoverySuggestion, "Please check your email and password and try again")
    }
    
    // MARK: - Error Handling Pattern Tests
    
    func testErrorHandlingWithBanderaErrors() async throws {
        // Test that our standardized error handling properly extracts information from BanderaError types
        let testCases: [(any BanderaErrorProtocol, UInt, String)] = [
            (AuthenticationError.invalidCredentials, 401, "Invalid email or password"),
            (ValidationError.failed("test"), 400, "Validation failed: test"),
            (ResourceError.notFound("user"), 404, "The requested user could not be found"),
            (DatabaseError.operationFailed("test"), 500, "Database operation failed: test")
        ]
        
        for (error, expectedStatus, expectedReason) in testCases {
            let req = Request(application: app, method: .GET, url: URI("/test"), on: app.eventLoopGroup.next())
            
            let context = await ErrorHandling.createErrorViewContext(for: req, error: error)
            
            XCTAssertEqual(context.statusCode, expectedStatus, "Status code mismatch for \(type(of: error))")
            XCTAssertEqual(context.reason, expectedReason, "Reason mismatch for \(type(of: error))")
        }
    }
} 