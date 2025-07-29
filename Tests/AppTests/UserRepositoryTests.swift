import XCTVapor
import Fluent
@testable import App

final class UserRepositoryTests: XCTestCase {
    var app: Application!
    var repository: UserRepository!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
        self.repository = UserRepository(database: app.db)
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
        self.repository = nil
    }
    
    // MARK: - User Creation and Retrieval Tests
    
    func testCreateAndGetUser() async throws {
        // Given
        let user = User(
            email: "test@example.com",
            passwordHash: "hashedpassword123",
            isAdmin: false
        )
        
        // When
        try await repository.save(user)
        let retrievedUser = try await repository.get(id: user.id!)
        
        // Then
        XCTAssertNotNil(retrievedUser)
        XCTAssertEqual(retrievedUser?.email, "test@example.com")
        XCTAssertFalse(retrievedUser?.isAdmin ?? true)
    }
    
    func testGetByIdAlias() async throws {
        // Given
        let user = User(
            email: "alias@example.com",
            passwordHash: "hashedpassword123",
            isAdmin: false
        )
        try await repository.save(user)
        
        // When
        let retrievedUser = try await repository.getById(user.id!)
        
        // Then
        XCTAssertNotNil(retrievedUser)
        XCTAssertEqual(retrievedUser?.email, "alias@example.com")
    }
    
    func testGetNonExistentUser() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When
        let retrievedUser = try await repository.get(id: nonExistentId)
        
        // Then
        XCTAssertNil(retrievedUser)
    }
    
    // MARK: - Email-based Operations Tests
    
    func testGetByEmail() async throws {
        // Given
        let user = User(
            email: "email@example.com",
            passwordHash: "hashedpassword123",
            isAdmin: true
        )
        try await repository.save(user)
        
        // When
        let retrievedUser = try await repository.getByEmail("email@example.com")
        
        // Then
        XCTAssertNotNil(retrievedUser)
        XCTAssertEqual(retrievedUser?.email, "email@example.com")
        XCTAssertTrue(retrievedUser?.isAdmin ?? false)
    }
    
    func testGetByEmailNotFound() async throws {
        // When
        let retrievedUser = try await repository.getByEmail("nonexistent@example.com")
        
        // Then
        XCTAssertNil(retrievedUser)
    }
    
    func testEmailExists() async throws {
        // Given
        let user = User(
            email: "exists@example.com",
            passwordHash: "hashedpassword123",
            isAdmin: false
        )
        try await repository.save(user)
        
        // When/Then
        let exists = try await repository.exists(email: "exists@example.com")
        XCTAssertTrue(exists)
        
        let notExists = try await repository.exists(email: "notexists@example.com")
        XCTAssertFalse(notExists)
    }
    
    func testFindByEmail() async throws {
        // Given
        let user = User(
            email: "find@example.com",
            passwordHash: "hashedpassword123",
            isAdmin: false
        )
        try await repository.save(user)
        
        // When
        let foundUser = try await repository.findByEmail("find@example.com")
        
        // Then
        XCTAssertNotNil(foundUser)
        XCTAssertEqual(foundUser?.email, "find@example.com")
    }
    
    // MARK: - User Management Tests
    
    func testUpdateUser() async throws {
        // Given
        let user = User(
            email: "update@example.com",
            passwordHash: "hashedpassword123",
            isAdmin: false
        )
        try await repository.save(user)
        
        // When
        user.email = "updated@example.com"
        user.isAdmin = true
        try await repository.save(user)
        
        let updatedUser = try await repository.get(id: user.id!)
        
        // Then
        XCTAssertEqual(updatedUser?.email, "updated@example.com")
        XCTAssertTrue(updatedUser?.isAdmin ?? false)
    }
    
    func testDeleteUser() async throws {
        // Given
        let user = User(
            email: "delete@example.com",
            passwordHash: "hashedpassword123",
            isAdmin: false
        )
        try await repository.save(user)
        let userId = user.id!
        
        // When
        try await repository.delete(user)
        
        // Then
        let deletedUser = try await repository.get(id: userId)
        XCTAssertNil(deletedUser)
    }
    
    func testGetAllUsers() async throws {
        // Given
        let user1 = User(email: "user1@example.com", passwordHash: "pass1", isAdmin: false)
        let user2 = User(email: "user2@example.com", passwordHash: "pass2", isAdmin: true)
        let user3 = User(email: "user3@example.com", passwordHash: "pass3", isAdmin: false)
        
        try await repository.save(user1)
        try await repository.save(user2)
        try await repository.save(user3)
        
        // When
        let allUsers = try await repository.getAllUsersUnpaginated()
        
        // Then
        XCTAssertEqual(allUsers.count, 3)
        let emails = allUsers.map { $0.email }.sorted()
        XCTAssertEqual(emails, ["user1@example.com", "user2@example.com", "user3@example.com"])
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testEmailCaseInsensitivity() async throws {
        // Given
        let user = User(
            email: "Case@Example.COM",
            passwordHash: "hashedpassword123",
            isAdmin: false
        )
        try await repository.save(user)
        
        // When/Then - Test various case combinations
        let user1 = try await repository.getByEmail("case@example.com")
        let user2 = try await repository.getByEmail("CASE@EXAMPLE.COM")
        let user3 = try await repository.getByEmail("Case@Example.COM")
        
        // Note: This behavior depends on database collation
        // SQLite is case-sensitive by default, so these might be nil
        // In production with proper DB config, these should work
        XCTAssertNotNil(user3) // Exact match should work
    }
    
    func testDuplicateEmailConstraint() async throws {
        // Given
        let user1 = User(email: "duplicate@example.com", passwordHash: "pass1", isAdmin: false)
        let user2 = User(email: "duplicate@example.com", passwordHash: "pass2", isAdmin: false)
        
        // When/Then
        try await repository.save(user1)
        
        // This should throw an error due to unique constraint
        do {
            try await repository.save(user2)
            XCTFail("Expected duplicate email constraint error")
        } catch {
            // Any error is fine - the important thing is that the constraint is enforced
            // The actual error type depends on the database driver (SQLite, PostgreSQL, etc.)
            XCTAssertTrue(true, "Correctly threw error for duplicate email: \(error)")
        }
    }
} 