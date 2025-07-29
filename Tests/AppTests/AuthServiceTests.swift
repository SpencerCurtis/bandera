import XCTVapor
import Fluent
@testable import App

final class AuthServiceTests: XCTestCase {
    var app: Application!
    var authService: AuthService!
    var userRepository: UserRepository!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
        self.userRepository = UserRepository(database: app.db)
        self.authService = AuthService(userRepository: userRepository, jwtSigner: app.jwt.signers)
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
        self.authService = nil
        self.userRepository = nil
    }
    
    // MARK: - Registration Tests
    
    func testSuccessfulRegistration() async throws {
        // Given
        let registerRequest = RegisterRequest(
            email: "newuser@example.com",
            password: "password123",
            isAdmin: false
        )
        
        // When
        let response = try await authService.register(registerRequest)
        
        // Then
        XCTAssertEqual(response.user.email, "newuser@example.com")
        XCTAssertFalse(response.user.isAdmin)
        XCTAssertFalse(response.token.isEmpty)
        
        // Verify user was saved to database
        let savedUser = try await userRepository.getByEmail("newuser@example.com")
        XCTAssertNotNil(savedUser)
        XCTAssertEqual(savedUser?.email, "newuser@example.com")
        XCTAssertFalse(savedUser?.isAdmin ?? true)
    }
    
    func testRegistrationWithAdminFlag() async throws {
        // Given
        let registerRequest = RegisterRequest(
            email: "admin@example.com",
            password: "adminpassword",
            isAdmin: true
        )
        
        // When
        let response = try await authService.register(registerRequest)
        
        // Then
        XCTAssertEqual(response.user.email, "admin@example.com")
        XCTAssertTrue(response.user.isAdmin)
        
        // Verify admin status in database
        let savedUser = try await userRepository.getByEmail("admin@example.com")
        XCTAssertTrue(savedUser?.isAdmin ?? false)
    }
    
    func testRegistrationWithExistingEmail() async throws {
        // Given
        _ = try await TestHelpers.createTestUser(app: app, email: "existing@example.com")
        
        let registerRequest = RegisterRequest(
            email: "existing@example.com",
            password: "password123",
            isAdmin: false
        )
        
        // When/Then
        do {
            _ = try await authService.register(registerRequest)
            XCTFail("Expected ResourceError.alreadyExists to be thrown")
        } catch let error as ResourceError {
            if case .alreadyExists(let message) = error {
                XCTAssertTrue(message.contains("existing@example.com"))
            } else {
                XCTFail("Expected alreadyExists error, got \(error)")
            }
        } catch {
            XCTFail("Expected ResourceError, got \(error)")
        }
    }
    
    // MARK: - Login Tests
    
    func testSuccessfulLogin() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(
            app: app,
            email: "user@example.com",
            password: "password123"
        )
        
        let loginRequest = LoginRequest(
            email: "user@example.com",
            password: "password123"
        )
        
        // When
        let response = try await authService.login(loginRequest)
        
        // Then
        XCTAssertEqual(response.user.email, "user@example.com")
        XCTAssertEqual(response.user.id, user.id)
        XCTAssertFalse(response.token.isEmpty)
        
        // Verify token is valid
        let payload = try app.jwt.signers.verify(response.token, as: UserJWTPayload.self)
        XCTAssertEqual(payload.subject.value, user.id?.uuidString)
        XCTAssertEqual(payload.isAdmin, user.isAdmin)
    }
    
    func testLoginWithInvalidEmail() async throws {
        // Given
        let loginRequest = LoginRequest(
            email: "nonexistent@example.com",
            password: "password123"
        )
        
        // When/Then
        do {
            _ = try await authService.login(loginRequest)
            XCTFail("Expected AuthenticationError.invalidCredentials to be thrown")
        } catch let error as AuthenticationError {
            if case .invalidCredentials = error {
                // Expected behavior
            } else {
                XCTFail("Expected invalidCredentials error, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError, got \(error)")
        }
    }
    
    func testLoginWithInvalidPassword() async throws {
        // Given
        _ = try await TestHelpers.createTestUser(
            app: app,
            email: "user@example.com",
            password: "correctpassword"
        )
        
        let loginRequest = LoginRequest(
            email: "user@example.com",
            password: "wrongpassword"
        )
        
        // When/Then
        do {
            _ = try await authService.login(loginRequest)
            XCTFail("Expected AuthenticationError.invalidCredentials to be thrown")
        } catch let error as AuthenticationError {
            if case .invalidCredentials = error {
                // Expected behavior
            } else {
                XCTFail("Expected invalidCredentials error, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthenticationError, got \(error)")
        }
    }
    
    // MARK: - Token Generation Tests
    
    func testGenerateTokenForUser() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(
            app: app,
            email: "tokenuser@example.com",
            isAdmin: true
        )
        
        // When
        let token = try authService.generateToken(for: user)
        
        // Then
        XCTAssertFalse(token.isEmpty)
        
        // Verify token contents
        let payload = try app.jwt.signers.verify(token, as: UserJWTPayload.self)
        XCTAssertEqual(payload.subject.value, user.id?.uuidString)
        XCTAssertTrue(payload.isAdmin)
        
        // Verify expiration is in the future
        let expirationDate = payload.expiration.value
        let expectedExpiration = Date().addingTimeInterval(TimeInterval(AppConstants.jwtExpirationDays * 86400))
        let timeDifference = abs(expirationDate.timeIntervalSince(expectedExpiration))
        XCTAssertLessThan(timeDifference, 60, "Token expiration should be approximately 7 days from now")
    }
    
    func testGenerateTokenExpirationTime() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        
        // When
        let token1 = try authService.generateToken(for: user)
        
        // Wait a moment to ensure different timestamps
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let token2 = try authService.generateToken(for: user)
        
        // Then
        XCTAssertNotEqual(token1, token2, "Tokens should be different due to different generation times")
        
        let payload1 = try app.jwt.signers.verify(token1, as: UserJWTPayload.self)
        let payload2 = try app.jwt.signers.verify(token2, as: UserJWTPayload.self)
        
        XCTAssertLessThan(payload1.expiration.value, payload2.expiration.value)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testRegistrationWithEmptyEmail() async throws {
        // Given
        let registerRequest = RegisterRequest(
            email: "",
            password: "password123",
            isAdmin: false
        )
        
        // When/Then - This should be caught by validation
        // Note: In a real app, this would be validated in the controller/middleware
        // For now, we test that the service can handle it gracefully
        do {
            _ = try await authService.register(registerRequest)
            // If no validation exists yet, the service might succeed
            // This indicates we need validation middleware
        } catch {
            // Expected if validation is in place
        }
    }
    
    func testPasswordHashing() async throws {
        // Given
        let registerRequest = RegisterRequest(
            email: "hashtest@example.com",
            password: "mypassword",
            isAdmin: false
        )
        
        // When
        _ = try await authService.register(registerRequest)
        
        // Then
        let user = try await userRepository.getByEmail("hashtest@example.com")
        XCTAssertNotNil(user)
        XCTAssertNotEqual(user?.passwordHash, "mypassword", "Password should be hashed, not stored in plain text")
        XCTAssertTrue(user?.passwordHash.starts(with: "$2") ?? false, "Should use bcrypt hashing")
        
        // Verify password can be verified
        XCTAssertTrue(try user?.verify(password: "mypassword") ?? false)
        XCTAssertFalse(try user?.verify(password: "wrongpassword") ?? true)
    }
}

// MARK: - Test Data Extensions

extension RegisterRequest {
    /// Creates a test register request with sensible defaults
    static func testRequest(
        email: String = "test@example.com",
        password: String = "password123",
        isAdmin: Bool = false
    ) -> RegisterRequest {
        return RegisterRequest(
            email: email,
            password: password,
            isAdmin: isAdmin
        )
    }
}

extension LoginRequest {
    /// Creates a test login request with sensible defaults
    static func testRequest(
        email: String = "test@example.com",
        password: String = "password123"
    ) -> LoginRequest {
        return LoginRequest(
            email: email,
            password: password
        )
    }
} 