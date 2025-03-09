@testable import App
import XCTVapor
import Crypto
import NIOHTTP1

final class FeatureFlagControllerTests: XCTestCase {
    var app: Application!
    var adminToken: String!
    var userToken: String!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
        
        // Clean up any existing data
        try await User.query(on: app.db).delete()
        try await FeatureFlag.query(on: app.db).delete()
        try await UserFeatureFlag.query(on: app.db).delete()
        
        // Create admin user and get token
        let adminUser = try User.create(from: RegisterRequest(
            email: "admin@example.com",
            password: "adminpass123",
            isAdmin: true
        ))
        try await adminUser.save(on: app.db)
        adminToken = try app.jwt.signers.sign(UserJWTPayload(
            subject: .init(value: adminUser.id!.uuidString),
            expiration: .init(value: Date().addingTimeInterval(86400)),
            isAdmin: true
        ))
        
        // Create regular user and get token
        let regularUser = try User.create(from: RegisterRequest(
            email: "user@example.com",
            password: "userpass123",
            isAdmin: false
        ))
        try await regularUser.save(on: app.db)
        userToken = try app.jwt.signers.sign(UserJWTPayload(
            subject: .init(value: regularUser.id!.uuidString),
            expiration: .init(value: Date().addingTimeInterval(86400)),
            isAdmin: false
        ))
    }
    
    override func tearDown() async throws {
        // Clean up the database
        try await User.query(on: app.db).delete()
        try await FeatureFlag.query(on: app.db).delete()
        try await UserFeatureFlag.query(on: app.db).delete()
        try await app.asyncShutdown()
    }
    
    // MARK: - Admin Tests
    
    func testCreateFeatureFlag() throws {
        // Given
        let create = CreateFeatureFlagRequest(
            key: "new_feature",
            type: .boolean,
            defaultValue: "false",
            description: "A new feature flag"
        )
        let data = try JSONEncoder().encode(create)
        
        // When/Then
        try app.test(.POST, "feature-flags", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: adminToken)
            req.headers.contentType = .json
            req.body = ByteBuffer(data: data)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            
            let flag = try response.content.decode(FeatureFlag.self)
            XCTAssertEqual(flag.key, create.key)
            XCTAssertEqual(flag.type, create.type)
            XCTAssertEqual(flag.defaultValue, create.defaultValue)
            XCTAssertEqual(flag.description, create.description)
            
            // Verify flag was saved
            let savedFlag = try FeatureFlag.query(on: self.app.db)
                .filter(\FeatureFlag.$key, .equal, create.key)
                .first()
                .wait()
            
            XCTAssertNotNil(savedFlag)
            XCTAssertEqual(savedFlag?.key, create.key)
        })
    }
    
    func testCreateFeatureFlagUnauthorized() throws {
        // Given
        let create = CreateFeatureFlagRequest(
            key: "new_feature",
            type: .boolean,
            defaultValue: "false",
            description: "A new feature flag"
        )
        let data = try JSONEncoder().encode(create)
        
        // When/Then
        try app.test(.POST, "feature-flags", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: userToken)
            req.headers.contentType = .json
            req.body = ByteBuffer(data: data)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .forbidden)
        })
    }
    
    func testUpdateFeatureFlag() throws {
        // Given
        let flag = FeatureFlag(
            key: "test_feature",
            type: .boolean,
            defaultValue: "false",
            description: "Test feature"
        )
        try flag.save(on: app.db).wait()
        
        let update = UpdateFeatureFlagRequest(
            id: flag.id,
            key: "updated_feature",
            type: .string,
            defaultValue: "test",
            description: "Updated description"
        )
        let data = try JSONEncoder().encode(update)
        
        // When/Then
        try app.test(.PUT, "feature-flags/\(flag.id!)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: adminToken)
            req.headers.contentType = .json
            req.body = ByteBuffer(data: data)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            
            let updatedFlag = try response.content.decode(FeatureFlag.self)
            XCTAssertEqual(updatedFlag.key, update.key)
            XCTAssertEqual(updatedFlag.type, update.type)
            XCTAssertEqual(updatedFlag.defaultValue, update.defaultValue)
            XCTAssertEqual(updatedFlag.description, update.description)
        })
    }
    
    func testDeleteFeatureFlag() throws {
        // Given
        let flag = FeatureFlag(
            key: "test_feature",
            type: .boolean,
            defaultValue: "false",
            description: "Test feature"
        )
        try flag.save(on: app.db).wait()
        
        // When/Then
        try app.test(.DELETE, "feature-flags/\(flag.id!)", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: adminToken)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .noContent)
            
            // Verify flag was deleted
            let deletedFlag = try FeatureFlag.find(flag.id, on: self.app.db).wait()
            XCTAssertNil(deletedFlag)
        })
    }
    
    // MARK: - User Tests
    
    func testGetFeatureFlagsForUser() throws {
        // Given
        let flag1 = FeatureFlag(
            key: "feature1",
            type: .boolean,
            defaultValue: "false",
            description: "Feature 1"
        )
        let flag2 = FeatureFlag(
            key: "feature2",
            type: .string,
            defaultValue: "default",
            description: "Feature 2"
        )
        try flag1.save(on: app.db).wait()
        try flag2.save(on: app.db).wait()
        
        let userId = "test_user"
        let override = UserFeatureFlag(
            userId: userId,
            featureFlagId: flag1.id!,
            value: "true"
        )
        try override.save(on: app.db).wait()
        
        // When/Then
        try app.test(HTTPMethod.GET, "feature-flags/user/\(userId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: userToken)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, HTTPStatus.ok)
            
            let flags = try response.content.decode([String: FeatureFlagResponse].self)
            XCTAssertEqual(flags.count, 2)
            
            // Check overridden flag
            XCTAssertEqual(flags["feature1"]?.value, "true")
            XCTAssertEqual(flags["feature1"]?.isOverridden, true)
            
            // Check default flag
            XCTAssertEqual(flags["feature2"]?.value, "default")
            XCTAssertEqual(flags["feature2"]?.isOverridden, false)
        })
    }
    
    func testListFeatureFlags() throws {
        // Given
        let flag1 = FeatureFlag(
            key: "feature1",
            type: .boolean,
            defaultValue: "false",
            description: "Feature 1"
        )
        let flag2 = FeatureFlag(
            key: "feature2",
            type: .string,
            defaultValue: "default",
            description: "Feature 2"
        )
        try flag1.save(on: app.db).wait()
        try flag2.save(on: app.db).wait()
        
        // When/Then
        try app.test(.GET, "feature-flags", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: userToken)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            
            let flags = try response.content.decode([FeatureFlag].self)
            XCTAssertEqual(flags.count, 2)
            XCTAssertEqual(flags.map { $0.key }.sorted(), ["feature1", "feature2"])
        })
    }
} 