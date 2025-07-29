import XCTVapor
import Fluent
import JWT
import NIOCore
@testable import App

final class MiddlewareTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
    }
    
    // MARK: - AdminMiddleware Tests
    
    func testAdminMiddlewareAllowsAdminUser() async throws {
        // Given
        let middleware = AdminMiddleware()
        let request = try createMockRequest()
        let adminPayload = UserJWTPayload(
            subject: SubjectClaim(value: "admin-user-id"),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            isAdmin: true
        )
        request.auth.login(adminPayload)
        
        let mockResponder = MockAsyncResponder { req in
            return Response(status: .ok)
        }
        
        // When
        let response = try await middleware.respond(to: request, chainingTo: mockResponder)
        
        // Then
        XCTAssertEqual(response.status, .ok)
    }
    
    func testAdminMiddlewareRejectsRegularUser() async throws {
        // Given
        let middleware = AdminMiddleware()
        let request = try createMockRequest()
        let regularPayload = UserJWTPayload(
            subject: SubjectClaim(value: "regular-user-id"),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            isAdmin: false
        )
        request.auth.login(regularPayload)
        
        let mockResponder = MockAsyncResponder { req in
            XCTFail("Should not be called for non-admin user")
            return Response(status: .ok)
        }
        
        // When/Then
        do {
            _ = try await middleware.respond(to: request, chainingTo: mockResponder)
            XCTFail("Expected AuthenticationError.insufficientPermissions")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .insufficientPermissions)
        } catch {
            XCTFail("Expected AuthenticationError but got \(error)")
        }
    }
    
    func testAdminMiddlewareRequiresAuthentication() async throws {
        // Given
        let middleware = AdminMiddleware()
        let request = try createMockRequest()
        // No authentication payload
        
        let mockResponder = MockAsyncResponder { req in
            XCTFail("Should not be called without authentication")
            return Response(status: .ok)
        }
        
        // When/Then
        do {
            _ = try await middleware.respond(to: request, chainingTo: mockResponder)
            XCTFail("Expected AuthenticationError.authenticationRequired")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .authenticationRequired)
        } catch {
            XCTFail("Expected AuthenticationError but got \(error)")
        }
    }
    
    // MARK: - RateLimitMiddleware Tests
    
    func testRateLimitAllowsRequestUnderLimit() async throws {
        // Given
        let mockStorage = MockRateLimitStorage()
        mockStorage.setResponse(count: 5, timeRemaining: 60)
        
        let middleware = RateLimitMiddleware(maxRequests: 10, per: 60, storage: mockStorage)
        let request = try createMockRequest()
        
        let mockResponder = MockAsyncResponder { req in
            return Response(status: .ok, body: "Success")
        }
        
        // When
        let response = try await middleware.respond(to: request, chainingTo: mockResponder)
        
        // Then
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.body.string, "Success")
        
        // Check rate limit headers
        XCTAssertEqual(response.headers.first(name: "X-RateLimit-Limit"), "10")
        XCTAssertEqual(response.headers.first(name: "X-RateLimit-Remaining"), "5")
        XCTAssertEqual(response.headers.first(name: "X-RateLimit-Reset"), "60")
    }
    
    func testRateLimitBlocksRequestOverLimit() async throws {
        // Given
        let mockStorage = MockRateLimitStorage()
        mockStorage.setResponse(count: 15, timeRemaining: 30) // Over limit of 10
        
        let middleware = RateLimitMiddleware(maxRequests: 10, per: 60, storage: mockStorage)
        let request = try createMockRequest()
        
        let mockResponder = MockAsyncResponder { req in
            XCTFail("Should not be called when rate limit exceeded")
            return Response(status: .ok)
        }
        
        // When
        let response = try await middleware.respond(to: request, chainingTo: mockResponder)
        
        // Then
        XCTAssertEqual(response.status, .tooManyRequests)
        XCTAssertTrue(response.body.string?.contains("Rate limit exceeded") == true)
        XCTAssertTrue(response.body.string?.contains("30 seconds") == true)
        
        // Check rate limit headers
        XCTAssertEqual(response.headers.first(name: "X-RateLimit-Limit"), "10")
        XCTAssertEqual(response.headers.first(name: "X-RateLimit-Remaining"), "-5")
        XCTAssertEqual(response.headers.first(name: "X-RateLimit-Reset"), "30")
    }
    
    // MARK: - ErrorMiddleware Tests
    
    func testErrorMiddlewareHandlesAuthenticationError() async throws {
        // Given
        let middleware = BanderaErrorMiddleware(environment: .testing)
        let request = try createMockRequest()
        request.headers.add(name: .accept, value: "application/json")
        
        let mockResponder = MockAsyncResponder { req in
            throw AuthenticationError.authenticationRequired
        }
        
        // When
        let response = try await middleware.respond(to: request, chainingTo: mockResponder)
        
        // Then
        XCTAssertEqual(response.status, .unauthorized)
        XCTAssertEqual(response.headers.contentType, .json)
        
        // Parse the actual error response format
        struct ErrorResponse: Codable {
            let error: Bool
            let reason: String
            let statusCode: UInt
        }
        
        let errorResponse = try response.content.decode(ErrorResponse.self)
        XCTAssertEqual(errorResponse.error, true)
        XCTAssertEqual(errorResponse.reason, "Authentication required")
        XCTAssertEqual(errorResponse.statusCode, 401)
    }
    
    func testErrorMiddlewarePassesThroughSuccessfulRequests() async throws {
        // Given
        let middleware = BanderaErrorMiddleware(environment: .testing)
        let request = try createMockRequest()
        
        let mockResponder = MockAsyncResponder { req in
            return Response(status: .ok, body: "Success")
        }
        
        // When
        let response = try await middleware.respond(to: request, chainingTo: mockResponder)
        
        // Then
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.body.string, "Success")
    }
    
    // MARK: - Helper Methods
    
    private func createMockRequest(path: String = "/test") throws -> Request {
        let request = Request(
            application: app,
            method: .GET,
            url: URI(string: path),
            on: app.eventLoopGroup.next()
        )
        return request
    }
}

// MARK: - Mock Responder

struct MockAsyncResponder: AsyncResponder {
    let handler: @Sendable (Request) async throws -> Response
    
    init(handler: @escaping @Sendable (Request) async throws -> Response) {
        self.handler = handler
    }
    
    func respond(to request: Request) async throws -> Response {
        return try await handler(request)
    }
}

// MARK: - Mock Rate Limit Storage

class MockRateLimitStorage: RateLimitStorage, @unchecked Sendable {
    private var shouldThrowError = false
    private var responseCount = 1
    private var responseTimeRemaining: Int64 = 60
    private(set) var incrementCallCount = 0
    
    enum MockError: Error {
        case storageError
    }
    
    func setResponse(count: Int, timeRemaining: Int64) {
        self.responseCount = count
        self.responseTimeRemaining = timeRemaining
    }
    
    func setShouldThrowError(_ shouldThrow: Bool) {
        self.shouldThrowError = shouldThrow
    }
    
    func increment(key: String, window: Int64) async throws -> (count: Int, timeRemaining: Int64) {
        incrementCallCount += 1
        
        if shouldThrowError {
            throw MockError.storageError
        }
        
        return (count: responseCount, timeRemaining: responseTimeRemaining)
    }
} 