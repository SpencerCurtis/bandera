import XCTVapor
import Fluent
@testable import App

final class CacheServiceTests: XCTestCase {
    var app: Application!
    var cacheService: CacheService!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
        
        // Create in-memory cache for testing
        let storage = InMemoryCacheStorage(logger: app.logger)
        self.cacheService = CacheService(storage: storage)
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
    }
    
    // MARK: - Feature Flag Caching Tests
    
    func testCacheAndRetrieveFeatureFlag() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        let flag = FeatureFlag(
            key: "test-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Test flag",
            userId: user.id!
        )
        try await flag.save(on: app.db)
        
        // When - Cache the flag
        try await cacheService.setFlag(flag, expiration: 300)
        
        // Then - Retrieve from cache
        let cachedFlag = try await cacheService.getFlag(id: flag.id!)
        XCTAssertNotNil(cachedFlag)
        XCTAssertEqual(cachedFlag?.key, "test-flag")
        XCTAssertEqual(cachedFlag?.type, .boolean)
        XCTAssertEqual(cachedFlag?.defaultValue, "false")
    }
    
    func testCacheUserFlags() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        let flags = [
            FeatureFlag(key: "flag1", type: .boolean, defaultValue: "true", description: "Flag 1", userId: user.id!),
            FeatureFlag(key: "flag2", type: .string, defaultValue: "test", description: "Flag 2", userId: user.id!)
        ]
        
        for flag in flags {
            try await flag.save(on: app.db)
        }
        
        // When - Cache user flags
        try await cacheService.setUserFlags(userId: user.id!, flags: flags, expiration: 300)
        
        // Then - Retrieve from cache
        let cachedFlags = try await cacheService.getUserFlags(userId: user.id!)
        XCTAssertNotNil(cachedFlags)
        XCTAssertEqual(cachedFlags?.count, 2)
        XCTAssertEqual(cachedFlags?.first?.key, "flag1")
    }
    
    func testCacheFlagsWithOverrides() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        let container = FeatureFlagsContainer(flags: [
            "test-flag": FeatureFlagResponse(
                flag: FeatureFlag(key: "test-flag", type: .boolean, defaultValue: "false", description: "Test", userId: user.id!),
                value: "true",
                isOverridden: true
            )
        ])
        
        // When - Cache flags with overrides
        try await cacheService.setFlagsWithOverrides(userId: user.id!.uuidString, container: container, expiration: 120)
        
        // Then - Retrieve from cache
        let cachedContainer = try await cacheService.getFlagsWithOverrides(userId: user.id!.uuidString)
        XCTAssertNotNil(cachedContainer)
        XCTAssertEqual(cachedContainer?.flags.count, 1)
        XCTAssertEqual(cachedContainer?.flags["test-flag"]?.value, "true")
        XCTAssertEqual(cachedContainer?.flags["test-flag"]?.isOverridden, true)
    }
    
    func testCacheFlagEnabledStatus() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        let flag = FeatureFlag(key: "test-flag", type: .boolean, defaultValue: "false", description: "Test", userId: user.id!)
        try await flag.save(on: app.db)
        
        // When - Cache enabled status
        try await cacheService.setFlagEnabled(id: flag.id!, enabled: true, expiration: 300)
        
        // Then - Retrieve from cache
        let isEnabled = try await cacheService.getFlagEnabled(id: flag.id!)
        XCTAssertNotNil(isEnabled)
        XCTAssertTrue(isEnabled!)
    }
    
    // MARK: - Cache Invalidation Tests
    
    func testInvalidateFlag() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        let flag = FeatureFlag(key: "test-flag", type: .boolean, defaultValue: "false", description: "Test", userId: user.id!)
        try await flag.save(on: app.db)
        
        // Cache flag and status
        try await cacheService.setFlag(flag, expiration: 300)
        try await cacheService.setFlagEnabled(id: flag.id!, enabled: true, expiration: 300)
        
        // When - Invalidate flag
        try await cacheService.invalidateFlag(id: flag.id!)
        
        // Then - Flag should be removed from cache
        let cachedFlag = try await cacheService.getFlag(id: flag.id!)
        let cachedStatus = try await cacheService.getFlagEnabled(id: flag.id!)
        XCTAssertNil(cachedFlag)
        XCTAssertNil(cachedStatus)
    }
    
    func testInvalidateUser() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        let flags = [
            FeatureFlag(key: "flag1", type: .boolean, defaultValue: "true", description: "Flag 1", userId: user.id!)
        ]
        
        for flag in flags {
            try await flag.save(on: app.db)
        }
        
        let container = FeatureFlagsContainer(flags: [
            "flag1": FeatureFlagResponse(flag: flags[0])
        ])
        
        // Cache user data
        try await cacheService.setUserFlags(userId: user.id!, flags: flags, expiration: 300)
        try await cacheService.setFlagsWithOverrides(userId: user.id!.uuidString, container: container, expiration: 120)
        
        // When - Invalidate user
        try await cacheService.invalidateUser(userId: user.id!)
        
        // Then - User cache should be cleared
        let cachedFlags = try await cacheService.getUserFlags(userId: user.id!)
        let cachedContainer = try await cacheService.getFlagsWithOverrides(userId: user.id!.uuidString)
        XCTAssertNil(cachedFlags)
        XCTAssertNil(cachedContainer)
    }
    
    // MARK: - Cache Miss Tests
    
    func testCacheMissReturnsNil() async throws {
        // When - Try to get non-existent cached flag
        let result = try await cacheService.getFlag(id: UUID())
        
        // Then - Should return nil
        XCTAssertNil(result)
    }
    
    func testCacheExpiration() async throws {
        // Given
        let user = try await TestHelpers.createTestUser(app: app)
        let flag = FeatureFlag(key: "test-flag", type: .boolean, defaultValue: "false", description: "Test", userId: user.id!)
        try await flag.save(on: app.db)
        
        // When - Cache with very short expiration
        try await cacheService.setFlag(flag, expiration: 1)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds
        
        // Then - Flag should be expired and return nil
        let cachedFlag = try await cacheService.getFlag(id: flag.id!)
        XCTAssertNil(cachedFlag)
    }
    
    // MARK: - Cache Storage Tests
    
    func testCacheAvailability() async {
        let isAvailable = await cacheService.isAvailable
        XCTAssertTrue(isAvailable) // In-memory cache should always be available
    }
} 