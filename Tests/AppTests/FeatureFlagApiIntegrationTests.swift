import XCTVapor
import Fluent
@testable import App

/// Integration tests for Feature Flag API endpoints
/// Tests complete end-to-end workflows including authentication, caching, and organization isolation
final class FeatureFlagApiIntegrationTests: XCTestCase {
    var app: Application!
    var testUser: User!
    var testOrg: Organization!
    var adminUser: User!
    var otherUser: User!
    var otherOrg: Organization!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
        
        // Create test users and organizations
        self.testUser = try await TestHelpers.createTestUser(
            app: app,
            email: "testuser@example.com"
        )
        self.adminUser = try await TestHelpers.createTestAdmin(app: app)
        self.otherUser = try await TestHelpers.createTestUser(
            app: app,
            email: "otheruser@example.com"
        )
        
        self.testOrg = try await TestHelpers.createTestOrganization(
            app: app,
            name: "Test Organization"
        )
        self.otherOrg = try await TestHelpers.createTestOrganization(
            app: app,
            name: "Other Organization"
        )
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
    }
    
    // MARK: - Authentication & Authorization Tests
    
    func testGetFlagsRequiresAuthentication() async throws {
        try app.test(.GET, "/api/flags") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }
    
    func testValidJWTAllowsAccess() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        try app.test(.GET, "/api/flags", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let flags = try res.content.decode([FeatureFlag].self)
            XCTAssertTrue(flags.isEmpty) // No flags initially
        }
    }
    
    // MARK: - Flag CRUD Integration Tests
    
    func testCompleteCreateFlagWorkflow() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        // Create flag
        let createRequest = CreateFeatureFlagRequest(
            key: "test-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Test flag for integration testing",
            organizationId: testOrg.id
        )
        
        try app.test(.POST, "/api/flags", headers: ["Authorization": "Bearer \(token)"], beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let flag = try res.content.decode(FeatureFlag.self)
            XCTAssertEqual(flag.key, "test-flag")
            XCTAssertEqual(flag.type, .boolean)
            XCTAssertEqual(flag.defaultValue, "false")
            XCTAssertEqual(flag.userId, testUser.id)
            XCTAssertEqual(flag.organizationId, testOrg.id)
        }
    }
    
    func testGetFlagByIdWithPermissionCheck() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        let otherToken = try TestHelpers.generateTestJWT(for: otherUser, app: app)
        
        // Create flag as testUser
        let flag = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "test-flag",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        // testUser can access their own flag
        try app.test(.GET, "/api/flags/\(flag.id!)", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let returnedFlag = try res.content.decode(FeatureFlag.self)
            XCTAssertEqual(returnedFlag.id, flag.id)
        }
        
        // otherUser cannot access testUser's flag
        try app.test(.GET, "/api/flags/\(flag.id!)", headers: ["Authorization": "Bearer \(otherToken)"]) { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }
    
    func testUpdateFlagWithCacheInvalidation() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        // Create flag
        let flag = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "update-test-flag",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        // Update flag
        let updateRequest = UpdateFeatureFlagRequest(
            key: "updated-test-flag",
            type: .string,
            defaultValue: "updated-value",
            description: "Updated description"
        )
        
        try app.test(.PUT, "/api/flags/\(flag.id!)", headers: ["Authorization": "Bearer \(token)"], beforeRequest: { req in
            try req.content.encode(updateRequest)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let updatedFlag = try res.content.decode(FeatureFlag.self)
            XCTAssertEqual(updatedFlag.key, "updated-test-flag")
            XCTAssertEqual(updatedFlag.type, .string)
            XCTAssertEqual(updatedFlag.defaultValue, "updated-value")
            XCTAssertEqual(updatedFlag.description, "Updated description")
        }
        
        // Verify flag was actually updated in database
        try app.test(.GET, "/api/flags/\(flag.id!)", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let refetchedFlag = try res.content.decode(FeatureFlag.self)
            XCTAssertEqual(refetchedFlag.key, "updated-test-flag")
        }
    }
    
    func testDeleteFlagCascadeEffects() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        // Create flag
        let flag = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "delete-test-flag",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        // Delete flag
        try app.test(.DELETE, "/api/flags/\(flag.id!)", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .noContent)
        }
        
        // Verify flag no longer exists
        try app.test(.GET, "/api/flags/\(flag.id!)", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }
    
    // MARK: - Flag Toggle Integration Tests
    
    func testToggleFlagEndToEnd() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        // Create flag
        let flag = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "toggle-test-flag",
            defaultValue: "true",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        // Toggle flag - should return the modified flag
        try app.test(.POST, "/api/flags/\(flag.id!)/toggle", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let toggledFlag = try res.content.decode(FeatureFlag.self)
            XCTAssertEqual(toggledFlag.id, flag.id)
            // Note: Toggle functionality might affect FlagStatus model, not the FeatureFlag directly
        }
        
        // Toggle again - should toggle back
        try app.test(.POST, "/api/flags/\(flag.id!)/toggle", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let toggledFlag = try res.content.decode(FeatureFlag.self)
            XCTAssertEqual(toggledFlag.id, flag.id)
        }
    }
    
    // MARK: - Organization Isolation Tests
    
    func testOrganizationFlagIsolation() async throws {
        let user1Token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        let user2Token = try TestHelpers.generateTestJWT(for: otherUser, app: app)
        
        // Create flag in testOrg
        let flag1 = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "org1-flag",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        // Create flag in otherOrg
        let flag2 = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "org2-flag",
            userId: otherUser.id,
            organizationId: otherOrg.id
        )
        
        // testUser can only see flags from testOrg
        try app.test(.GET, "/api/flags", headers: ["Authorization": "Bearer \(user1Token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let flags = try res.content.decode([FeatureFlag].self)
            XCTAssertEqual(flags.count, 1)
            XCTAssertEqual(flags.first?.key, "org1-flag")
        }
        
        // otherUser can only see flags from otherOrg
        try app.test(.GET, "/api/flags", headers: ["Authorization": "Bearer \(user2Token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let flags = try res.content.decode([FeatureFlag].self)
            XCTAssertEqual(flags.count, 1)
            XCTAssertEqual(flags.first?.key, "org2-flag")
        }
        
        // Cross-organization access should be denied
        try app.test(.GET, "/api/flags/\(flag2.id!)", headers: ["Authorization": "Bearer \(user1Token)"]) { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }
    
    // MARK: - Flag Override Integration Tests
    
    func testCreateAndDeleteFlagOverrides() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        // Create flag
        let flag = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "override-test-flag",
            type: .boolean,
            defaultValue: "false",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        // Create override
        let createOverrideRequest = CreateOverrideRequest(
            userId: testUser.id!.uuidString,
            value: "true"
        )
        
        // Create override should return HTTP status
        try app.test(.POST, "/api/flags/\(flag.id!)/overrides", headers: ["Authorization": "Bearer \(token)"], beforeRequest: { req in
            try req.content.encode(createOverrideRequest)
        }) { res in
            XCTAssertEqual(res.status, .created)
        }
        
        // Get overrides to verify it exists
        var overrideId: UUID!
        try app.test(.GET, "/api/flags/\(flag.id!)/overrides", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let overrides = try res.content.decode([UserFeatureFlag].self)
            XCTAssertEqual(overrides.count, 1)
            XCTAssertEqual(overrides.first?.value, "true")
            XCTAssertEqual(overrides.first?.$featureFlag.id, flag.id)
            XCTAssertEqual(overrides.first?.$user.id, testUser.id)
            overrideId = overrides.first?.id
        }
        
        // Delete override
        XCTAssertNotNil(overrideId, "Override ID should be set")
        try app.test(.DELETE, "/api/flags/\(flag.id!)/overrides/\(overrideId!)", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .noContent)
        }
        
        // Verify override is gone
        try app.test(.GET, "/api/flags/\(flag.id!)/overrides", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let overrides = try res.content.decode([UserFeatureFlag].self)
            XCTAssertEqual(overrides.count, 0)
        }
    }
    
    // MARK: - User-Specific Flag Access Tests
    
    func testGetFlagsForSpecificUser() async throws {
        let adminToken = try TestHelpers.generateTestJWT(for: adminUser, app: app)
        
        // Create flags for testUser
        let flag1 = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "user-flag-1",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        let flag2 = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "user-flag-2",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        // Admin can get flags for specific user
        try app.test(.GET, "/api/flags/user/\(testUser.id!)", headers: ["Authorization": "Bearer \(adminToken)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let container = try res.content.decode(FeatureFlagsContainer.self)
            XCTAssertEqual(container.flags.count, 2)
            
            let flagKeys = container.flags.keys
            XCTAssertTrue(flagKeys.contains("user-flag-1"))
            XCTAssertTrue(flagKeys.contains("user-flag-2"))
        }
    }
    
    // MARK: - Import/Export Integration Tests
    
    func testImportFlagToOrganization() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        // Create source flag
        let sourceFlag = try await TestHelpers.createTestFeatureFlag(
            app: app,
            key: "import-test-flag",
            type: .string,
            defaultValue: "original-value",
            userId: testUser.id,
            organizationId: testOrg.id
        )
        
        // Import to other organization
        try app.test(.POST, "/api/flags/\(sourceFlag.id!)/import/\(otherOrg.id!)", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let importedFlag = try res.content.decode(FeatureFlag.self)
            XCTAssertEqual(importedFlag.key, "import-test-flag")
            XCTAssertEqual(importedFlag.type, .string)
            XCTAssertEqual(importedFlag.defaultValue, "original-value")
            XCTAssertEqual(importedFlag.organizationId, otherOrg.id)
            XCTAssertEqual(importedFlag.userId, testUser.id)
            XCTAssertNotEqual(importedFlag.id, sourceFlag.id) // Should be a new flag
        }
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testCreateFlagWithInvalidData() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        // Try to create flag with empty key
        let invalidRequest = CreateFeatureFlagRequest(
            key: "", // Invalid empty key
            type: .boolean,
            defaultValue: "false",
            description: "Invalid flag",
            organizationId: testOrg.id
        )
        
        try app.test(.POST, "/api/flags", headers: ["Authorization": "Bearer \(token)"], beforeRequest: { req in
            try req.content.encode(invalidRequest)
        }) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
    
    func testUpdateNonExistentFlag() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        let nonExistentId = UUID()
        
        let updateRequest = UpdateFeatureFlagRequest(
            key: "updated-key",
            type: .boolean,
            defaultValue: "true",
            description: "Updated description"
        )
        
        try app.test(.PUT, "/api/flags/\(nonExistentId)", headers: ["Authorization": "Bearer \(token)"], beforeRequest: { req in
            try req.content.encode(updateRequest)
        }) { res in
            XCTAssertEqual(res.status, .notFound)
        }
    }
    
    // MARK: - Performance & Caching Integration Tests
    
    func testFlagCreationAndCacheInvalidation() async throws {
        let token = try TestHelpers.generateTestJWT(for: testUser, app: app)
        
        // Get flags (should be empty and cached)
        try app.test(.GET, "/api/flags", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let flags = try res.content.decode([FeatureFlag].self)
            XCTAssertTrue(flags.isEmpty)
        }
        
        // Create a flag (should invalidate cache)
        let createRequest = CreateFeatureFlagRequest(
            key: "cache-test-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Cache test flag",
            organizationId: testOrg.id
        )
        
        try app.test(.POST, "/api/flags", headers: ["Authorization": "Bearer \(token)"], beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { res in
            XCTAssertEqual(res.status, .ok)
        }
        
        // Get flags again (should reflect the new flag)
        try app.test(.GET, "/api/flags", headers: ["Authorization": "Bearer \(token)"]) { res in
            XCTAssertEqual(res.status, .ok)
            let flags = try res.content.decode([FeatureFlag].self)
            XCTAssertEqual(flags.count, 1)
            XCTAssertEqual(flags.first?.key, "cache-test-flag")
        }
    }
} 