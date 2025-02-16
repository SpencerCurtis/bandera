@testable import App
import XCTVapor
import Crypto
import NIOHTTP1

struct ErrorResponse: Content {
    let reason: String
}

final class AuthControllerTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        
        // Clean up any existing data
        try await User.query(on: app.db).delete()
        try await FeatureFlag.query(on: app.db).delete()
        try await UserFeatureFlag.query(on: app.db).delete()
    }
    
    override func tearDown() async throws {
        // Clean up the database
        try await User.query(on: app.db).delete()
        try await FeatureFlag.query(on: app.db).delete()
        try await UserFeatureFlag.query(on: app.db).delete()
        try await app.asyncShutdown()
    }
    
    func testUserRegistration() throws {
        // Given
        let email = "test@example.com"
        let password = "securePassword123"
        
        let registerData = try JSONEncoder().encode(User.Create(
            email: email,
            password: password,
            isAdmin: false
        ))
        
        // When
        try app.test(.POST, "auth/register", beforeRequest: { req in
            req.headers.contentType = .json
            req.body = ByteBuffer(data: registerData)
        }, afterResponse: { response in
            // Then
            
            print(response)
            XCTAssertEqual(response.status, HTTPStatus.ok)
            
            let authResponse = try response.content.decode(AuthenticationDTOs.AuthResponse.self)
            XCTAssertNotNil(authResponse.token)
            XCTAssertEqual(authResponse.user.email, email)
            
            // Verify user was saved in database
            let savedUser = try User.query(on: self.app.db)
                .filter(\User.$email, .equal, email)
                .first()
                .wait()
            
            XCTAssertNotNil(savedUser)
            XCTAssertEqual(savedUser?.email, email)
        })
    }
    
    func testUserRegistrationWithExistingEmail() throws {
        // Given
        let email = "existing@example.com"
        let password = "securePassword123"
        
        // Create initial user
        let user = try User.create(from: .init(
            email: email,
            password: password,
            isAdmin: false
        ))
        try user.save(on: app.db).wait()
        
        // Try to register with same email
        let registerData = try JSONEncoder().encode(User.Create(
            email: email,
            password: password,
            isAdmin: false
        ))
        
        // When/Then
        try app.test(.POST, "auth/register", beforeRequest: { req in
            req.headers.contentType = HTTPMediaType.json
            req.body = ByteBuffer(data: registerData)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, HTTPStatus.conflict)
        })
    }
    
    func testUserLogin() throws {
        // Given
        let email = "login@example.com"
        let password = "securePassword123"
        
        // Create user
        let user = try User.create(from: .init(
            email: email,
            password: password,
            isAdmin: false
        ))
        try user.save(on: app.db).wait()
        
        let loginData = try JSONEncoder().encode(AuthenticationDTOs.LoginRequest(
            email: email,
            password: password
        ))
        
        // When
        try app.test(.POST, "auth/login", beforeRequest: { req in
            req.headers.contentType = HTTPMediaType.json
            req.headers.add(name: .accept, value: "application/json")
            req.body = ByteBuffer(data: loginData)
        }, afterResponse: { response in
            // Then
            XCTAssertEqual(response.status, HTTPStatus.ok)
            
            let authResponse = try response.content.decode(AuthenticationDTOs.AuthResponse.self)
            XCTAssertNotNil(authResponse.token)
            XCTAssertEqual(authResponse.user.email, email)
        })
    }
    
    func testUserLoginWithInvalidCredentials() throws {
        // Given
        let email = "invalid@example.com"
        let password = "wrongPassword"
        
        let loginData = try JSONEncoder().encode(AuthenticationDTOs.LoginRequest(
            email: email,
            password: password
        ))
        
        // When/Then
        try app.test(.POST, "auth/login", beforeRequest: { req in
            req.headers.contentType = HTTPMediaType.json
            req.headers.add(name: .accept, value: "application/json")
            req.body = ByteBuffer(data: loginData)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, HTTPStatus.unauthorized)
        })
    }
    
    func testUserLoginWithExistingEmailWrongPassword() throws {
        // Given
        let email = "existing@example.com"
        let correctPassword = "correctPassword123"
        let wrongPassword = "wrongPassword123"
        
        // Create user with correct password
        let user = try User.create(from: .init(
            email: email,
            password: correctPassword,
            isAdmin: false
        ))
        try user.save(on: app.db).wait()
        
        // Attempt login with wrong password
        let loginData = try JSONEncoder().encode(AuthenticationDTOs.LoginRequest(
            email: email,
            password: wrongPassword
        ))
        
        // When/Then
        try app.test(.POST, "auth/login", beforeRequest: { req in
            req.headers.contentType = HTTPMediaType.json
            req.headers.add(name: .accept, value: "application/json")
            req.body = ByteBuffer(data: loginData)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, HTTPStatus.unauthorized)
            
            // Verify error message
            let errorResponse = try response.content.decode(ErrorResponse.self)
            XCTAssertEqual(errorResponse.reason, "Invalid credentials")
        })
    }
}
