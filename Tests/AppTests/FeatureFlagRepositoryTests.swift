import XCTVapor
import Fluent
@testable import App

final class FeatureFlagRepositoryTests: XCTestCase {
    var app: Application!
    var repository: FeatureFlagRepository!
    var userRepository: UserRepository!
    var organizationRepository: OrganizationRepository!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
        self.repository = FeatureFlagRepository(database: app.db)
        self.userRepository = UserRepository(database: app.db)
        self.organizationRepository = OrganizationRepository(db: app.db)
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
        self.repository = nil
        self.userRepository = nil
        self.organizationRepository = nil
    }
    
    // MARK: - Feature Flag CRUD Tests
    
    func testCreateAndGetFeatureFlag() async throws {
        // Given
        let user = User(email: "creator@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Flag Org")
        let createdOrg = try await organizationRepository.create(organization)
        
        let flag = FeatureFlag(
            key: "test-feature",
            type: .boolean,
            defaultValue: "true",
            description: "A test feature flag",
            userId: user.id!,
            organizationId: createdOrg.id!
        )
        
        // When
        try await repository.save(flag)
        let retrievedFlag = try await repository.get(id: flag.id!)
        
        // Then
        XCTAssertNotNil(retrievedFlag)
        XCTAssertEqual(retrievedFlag?.key, "test-feature")
        XCTAssertEqual(retrievedFlag?.type, .boolean)
        XCTAssertEqual(retrievedFlag?.defaultValue, "true")
        XCTAssertEqual(retrievedFlag?.description, "A test feature flag")
        XCTAssertEqual(retrievedFlag?.userId, user.id!)
        XCTAssertEqual(retrievedFlag?.organizationId, createdOrg.id!)
    }
    
    func testGetNonExistentFlag() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When
        let retrievedFlag = try await repository.get(id: nonExistentId)
        
        // Then
        XCTAssertNil(retrievedFlag)
    }
    
    func testGetAllFeatureFlags() async throws {
        // Given
        let user = User(email: "multiflags@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Multi Flag Org")
        let createdOrg = try await organizationRepository.create(organization)
        
        let flag1 = FeatureFlag(key: "feature-1", type: .boolean, defaultValue: "true", description: "First feature", userId: user.id!, organizationId: createdOrg.id!)
        let flag2 = FeatureFlag(key: "feature-2", type: .string, defaultValue: "test", description: "Second feature", userId: user.id!, organizationId: createdOrg.id!)
        let flag3 = FeatureFlag(key: "feature-3", type: .number, defaultValue: "123", description: "Third feature", userId: user.id!, organizationId: createdOrg.id!)
        
        try await repository.save(flag1)
        try await repository.save(flag2)
        try await repository.save(flag3)
        
        // When
        let allFlags = try await repository.allUnpaginated()
        
        // Then
        XCTAssertEqual(allFlags.count, 3)
        let flagKeys = allFlags.map { $0.key }.sorted()
        XCTAssertEqual(flagKeys, ["feature-1", "feature-2", "feature-3"])
    }
    
    func testUpdateFeatureFlag() async throws {
        // Given
        let user = User(email: "update@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Update Org")
        let createdOrg = try await organizationRepository.create(organization)
        
        let flag = FeatureFlag(
            key: "update-feature",
            type: .boolean,
            defaultValue: "false",
            description: "Original description",
            userId: user.id!,
            organizationId: createdOrg.id!
        )
        try await repository.save(flag)
        
        // When
        flag.defaultValue = "true"
        flag.description = "Updated description"
        try await repository.save(flag)
        
        let updatedFlag = try await repository.get(id: flag.id!)
        
        // Then
        XCTAssertEqual(updatedFlag?.defaultValue, "true")
        XCTAssertEqual(updatedFlag?.description, "Updated description")
    }
    
    func testDeleteFeatureFlag() async throws {
        // Given
        let user = User(email: "delete@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Delete Org")
        let createdOrg = try await organizationRepository.create(organization)
        
        let flag = FeatureFlag(
            key: "delete-feature",
            type: .boolean,
            defaultValue: "true",
            description: "To be deleted",
            userId: user.id!,
            organizationId: createdOrg.id!
        )
        try await repository.save(flag)
        let flagId = flag.id!
        
        // When
        try await repository.delete(flag)
        
        // Then
        let deletedFlag = try await repository.get(id: flagId)
        XCTAssertNil(deletedFlag)
    }
    
    // MARK: - User-specific Flag Tests
    
    func testGetAllFlagsForUser() async throws {
        // Given
        let user1 = User(email: "user1@example.com", passwordHash: "password", isAdmin: false)
        let user2 = User(email: "user2@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user1)
        try await userRepository.save(user2)
        
        let organization = Organization(name: "User Flags Org")
        let createdOrg = try await organizationRepository.create(organization)
        
        // Create flags for both users
        let flag1 = FeatureFlag(key: "user1-flag1", type: .boolean, defaultValue: "true", description: "First flag for user 1", userId: user1.id!, organizationId: createdOrg.id!)
        let flag2 = FeatureFlag(key: "user1-flag2", type: .string, defaultValue: "test", description: "Second flag for user 1", userId: user1.id!, organizationId: createdOrg.id!)
        let flag3 = FeatureFlag(key: "user2-flag1", type: .boolean, defaultValue: "false", description: "First flag for user 2", userId: user2.id!, organizationId: createdOrg.id!)
        
        try await repository.save(flag1)
        try await repository.save(flag2)
        try await repository.save(flag3)
        
        // When
        let user1Flags = try await repository.getAllForUser(userId: user1.id!)
        let user2Flags = try await repository.getAllForUser(userId: user2.id!)
        
        // Then
        XCTAssertEqual(user1Flags.count, 2)
        XCTAssertEqual(user2Flags.count, 1)
        
        let user1FlagKeys = user1Flags.map { $0.key }.sorted()
        XCTAssertEqual(user1FlagKeys, ["user1-flag1", "user1-flag2"])
        
        let user2FlagKeys = user2Flags.map { $0.key }
        XCTAssertEqual(user2FlagKeys, ["user2-flag1"])
    }
    
    func testFlagExistsForUser() async throws {
        // Given
        let user = User(email: "exists@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Exists Org")
        let createdOrg = try await organizationRepository.create(organization)
        
        let flag = FeatureFlag(
            key: "exists-feature",
            type: .boolean,
            defaultValue: "true",
            description: "Feature to test existence",
            userId: user.id!,
            organizationId: createdOrg.id!
        )
        try await repository.save(flag)
        
        // When/Then
        let exists = try await repository.exists(key: "exists-feature", userId: user.id!)
        XCTAssertTrue(exists)
        
        let notExists = try await repository.exists(key: "nonexistent-feature", userId: user.id!)
        XCTAssertFalse(notExists)
        
        // Test with different user
        let otherUser = User(email: "other@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(otherUser)
        
        let existsForOtherUser = try await repository.exists(key: "exists-feature", userId: otherUser.id!)
        XCTAssertFalse(existsForOtherUser)
    }
    
    // MARK: - Flag States and Variations
    
    func testFeatureFlagStates() async throws {
        // Given
        let user = User(email: "state@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "State Org")
        let createdOrg = try await organizationRepository.create(organization)
        
        let enabledFlag = FeatureFlag(key: "enabled-flag", type: .boolean, defaultValue: "true", description: "Enabled feature", userId: user.id!, organizationId: createdOrg.id!)
        let disabledFlag = FeatureFlag(key: "disabled-flag", type: .boolean, defaultValue: "false", description: "Disabled feature", userId: user.id!, organizationId: createdOrg.id!)
        
        try await repository.save(enabledFlag)
        try await repository.save(disabledFlag)
        
        // When
        let retrievedEnabledFlag = try await repository.get(id: enabledFlag.id!)
        let retrievedDisabledFlag = try await repository.get(id: disabledFlag.id!)
        
        // Then
        XCTAssertEqual(retrievedEnabledFlag?.defaultValue, "true")
        XCTAssertEqual(retrievedDisabledFlag?.defaultValue, "false")
    }
    
    func testFeatureFlagKeyUniqueness() async throws {
        // Given
        let user = User(email: "unique@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Unique Org")
        let createdOrg = try await organizationRepository.create(organization)
        
        let flag1 = FeatureFlag(key: "unique-key", type: .boolean, defaultValue: "true", description: "First flag with key", userId: user.id!, organizationId: createdOrg.id!)
        let flag2 = FeatureFlag(key: "unique-key", type: .string, defaultValue: "test", description: "Second flag with same key", userId: user.id!, organizationId: createdOrg.id!)
        
        // When/Then
        try await repository.save(flag1)
        
        // This should throw an error due to unique constraint on (key, userId, organizationId)
        do {
            try await repository.save(flag2)
            XCTFail("Expected unique key constraint error")
        } catch {
            // Any error is fine - the important thing is that the constraint is enforced
            // The actual error type depends on the database driver (SQLite, PostgreSQL, etc.)
            XCTAssertTrue(true, "Correctly threw error for duplicate key: \(error)")
        }
    }
} 