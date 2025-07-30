import XCTVapor
import Fluent
@testable import App

final class SecurityMiddlewareTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
    }
    
    // MARK: - CSRF Protection Tests
    
    func testCSRFTokenGeneration() async throws {
        try await app.test(.GET, "/auth/login") { res in
            XCTAssertEqual(res.status, .ok)
            
            // Check that a session was created with CSRF token
            let cookies = res.headers.setCookie
            XCTAssertTrue(cookies?.contains { $0.string.contains("bandera-session") } ?? false, 
                         "Session cookie should be set")
        }
    }
    
    func testCSRFProtectionBlocksRequestsWithoutToken() async throws {
        try await app.test(.POST, "/auth/login", beforeRequest: { req in
            try req.content.encode([
                "email": "test@example.com",
                "password": "password123"
            ])
        }) { res in
            XCTAssertEqual(res.status, .forbidden, "POST without CSRF token should be blocked")
            
            let errorResponse = try res.content.decode([String: String].self)
            XCTAssertTrue(errorResponse["error"]?.contains("CSRF") ?? false, 
                         "Error should mention CSRF")
        }
    }
    
    func testCSRFProtectionAllowsRequestsWithValidToken() async throws {
        // First, get a page to establish a session with CSRF token
        var csrfToken: String?
        
        try await app.test(.GET, "/auth/login") { res in
            XCTAssertEqual(res.status, .ok)
            
            // Extract CSRF token from the rendered HTML (simplified for test)
            let body = res.body.string
            // In a real test, you'd parse the HTML to extract the token
            // For now, we'll simulate having the token
        }
        
        // Create a test user first
        let user = try await TestHelpers.createTestUser(app: app)
        
        // Now test with a valid session and CSRF token
        try await app.test(.POST, "/auth/login", beforeRequest: { req in
            // Simulate a session with CSRF token
            req.session.data["csrf_token"] = TestHelpers.generateTestCSRFToken()
            
            try req.content.encode([
                "email": user.email,
                "password": "password123",
                "csrf_token": TestHelpers.extractTestCSRFToken()
            ])
        }) { res in
            // Should redirect on successful login instead of being blocked
            XCTAssertTrue([.seeOther, .found, .temporaryRedirect].contains(res.status), 
                         "Valid CSRF token should allow request to proceed")
        }
    }
    
    func testCSRFLeafTags() async throws {
        // Test that Leaf tags are registered
        XCTAssertNotNil(app.leaf.tags["csrfToken"], "CSRF token tag should be registered")
        XCTAssertNotNil(app.leaf.tags["csrfValue"], "CSRF value tag should be registered")
    }
    
    // MARK: - Security Headers Tests
    
    func testSecurityHeaders() async throws {
        try await app.test(.GET, "/auth/login") { res in
            XCTAssertEqual(res.status, .ok)
            
            // Check security headers
            XCTAssertEqual(res.headers.first(name: "X-Content-Type-Options"), "nosniff",
                          "Should set X-Content-Type-Options")
            XCTAssertEqual(res.headers.first(name: "X-Frame-Options"), "DENY",
                          "Should set X-Frame-Options")
            XCTAssertEqual(res.headers.first(name: "X-XSS-Protection"), "1; mode=block",
                          "Should set X-XSS-Protection")
            XCTAssertEqual(res.headers.first(name: "Referrer-Policy"), "strict-origin-when-cross-origin",
                          "Should set Referrer-Policy")
            
            // Check CSP header exists
            let csp = res.headers.first(name: "Content-Security-Policy")
            XCTAssertNotNil(csp, "Should set Content-Security-Policy")
            XCTAssertTrue(csp?.contains("default-src 'self'") ?? false, 
                         "CSP should include default-src 'self'")
        }
    }
    
    func testSecurityHeadersNotAppliedToAPIRoutes() async throws {
        // Create test user and get JWT token
        let user = try await TestHelpers.createTestUser(app: app)
        let token = try TestHelpers.generateTestJWT(for: user, app: app)
        
        try await app.test(.GET, "/api/auth/me", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            
            // Security headers should not be applied to API routes
            XCTAssertNil(res.headers.first(name: "X-Frame-Options"),
                        "Security headers should not be applied to API routes")
            XCTAssertNil(res.headers.first(name: "Content-Security-Policy"),
                        "CSP should not be applied to API routes")
        }
    }
    
    // MARK: - Request Size Limit Tests
    
    func testRequestSizeLimits() async throws {
        // Create a large payload (over 10MB)
        let largePayload = String(repeating: "x", count: 11 * 1024 * 1024) // 11MB
        
        try await app.test(.POST, "/auth/signup", beforeRequest: { req in
            try req.content.encode([
                "email": "test@example.com",
                "password": "password123",
                "name": "Test User",
                "largeField": largePayload
            ])
        }) { res in
            XCTAssertEqual(res.status, .payloadTooLarge, 
                          "Large requests should be rejected")
        }
    }
    
    func testNormalSizeRequestsAccepted() async throws {
        try await app.test(.POST, "/auth/signup", beforeRequest: { req in
            req.session.data["csrf_token"] = TestHelpers.generateTestCSRFToken()
            
            try req.content.encode([
                "email": "normal@example.com",
                "password": "password123",
                "name": "Normal User",
                "csrf_token": TestHelpers.extractTestCSRFToken()
            ])
        }) { res in
            // Should not be rejected for size (may fail for other reasons like validation)
            XCTAssertNotEqual(res.status, .payloadTooLarge, 
                             "Normal size requests should not be rejected for size")
        }
    }
    
    // MARK: - Session Security Tests
    
    func testSessionCookieConfiguration() async throws {
        try await app.test(.GET, "/auth/login") { res in
            XCTAssertEqual(res.status, .ok)
            
            // Check session cookie security settings
            if let setCookieHeaders = res.headers.setCookie {
                let sessionCookie = setCookieHeaders.first { cookie in
                    cookie.string.contains("bandera-session")
                }
                
                XCTAssertNotNil(sessionCookie, "Session cookie should be set")
                
                if let cookie = sessionCookie {
                    XCTAssertTrue(cookie.string.contains("HttpOnly"), 
                                 "Session cookie should be HttpOnly")
                    XCTAssertTrue(cookie.string.contains("SameSite=Lax"), 
                                 "Session cookie should have SameSite=Lax")
                    
                    // In test environment, secure flag should not be set
                    if app.environment == .testing {
                        XCTAssertFalse(cookie.string.contains("Secure"), 
                                      "Secure flag should not be set in test environment")
                    }
                }
            }
        }
    }
    
    // MARK: - CSRF Error Handling Tests
    
    func testCSRFErrorMessages() async throws {
        // Test with expired token
        try await app.test(.POST, "/auth/login", beforeRequest: { req in
            // Set an expired CSRF token
            let expiredTokenData = CSRFTokenData(token: "expired", createdAt: Date().addingTimeInterval(-7200)) // 2 hours ago
            req.session.data["csrf_token"] = try expiredTokenData.encoded()
            
            try req.content.encode([
                "email": "test@example.com",
                "password": "password123",
                "csrf_token": "expired"
            ])
        }) { res in
            XCTAssertEqual(res.status, .forbidden)
            
            let errorResponse = try res.content.decode([String: String].self)
            XCTAssertTrue(errorResponse["error"]?.contains("CSRF") ?? false)
        }
    }
}

// MARK: - Test Helpers Extension

extension TestHelpers {
    static func generateTestCSRFToken() -> String {
        let token = [UInt8].random(count: 32).base64
        let tokenData = CSRFTokenData(token: token, createdAt: Date())
        return try! tokenData.encoded()
    }
    
    static func extractTestCSRFToken() -> String {
        return [UInt8].random(count: 32).base64
    }
    
    static func generateTestJWT(for user: User, app: Application) throws -> String {
        let payload = UserJWTPayload(
            subject: .init(value: user.id!.uuidString),
            expiration: .init(value: Date().addingTimeInterval(3600)),
            userId: user.id!,
            email: user.email,
            isAdmin: user.isAdmin
        )
        return try app.jwt.signers.sign(payload)
    }
}

// MARK: - Helper Struct for CSRF Testing

private struct CSRFTokenData: Codable {
    let token: String
    let createdAt: Date
    
    func encoded() throws -> String {
        let data = try JSONEncoder().encode(self)
        return data.base64EncodedString()
    }
} 