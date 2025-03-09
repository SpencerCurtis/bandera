@testable import App
import XCTVapor
import XCTest

final class FeatureFlagServiceTests: XCTestCase {
    var mockRepository: MockFeatureFlagRepository!
    var mockWebSocketService: MockWebSocketService!
    var service: FeatureFlagService!
    
    override func setUp() async throws {
        mockRepository = MockFeatureFlagRepository()
        mockWebSocketService = MockWebSocketService()
        service = FeatureFlagService(
            repository: mockRepository,
            webSocketService: mockWebSocketService
        )
    }
    
    override func tearDown() async throws {
        mockRepository.reset()
        mockWebSocketService.reset()
    }
    
    func testCreateFlag() async throws {
        // Arrange
        let userId = UUID()
        let request = CreateFeatureFlagRequest(
            key: "test-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Test flag"
        )
        
        // Act
        let flag = try await service.createFlag(request, userId: userId)
        
        // Assert
        XCTAssertEqual(flag.key, request.key)
        XCTAssertEqual(flag.type, request.type)
        XCTAssertEqual(flag.defaultValue, request.defaultValue)
        XCTAssertEqual(flag.description, request.description)
        
        // Verify repository was called
        let savedFlag = try await mockRepository.getByKey(request.key)
        XCTAssertNotNil(savedFlag)
        XCTAssertEqual(savedFlag?.key, request.key)
        
        // Verify WebSocket notification was sent
        XCTAssertEqual(mockWebSocketService.broadcastedEvents.count, 1)
        XCTAssertEqual(mockWebSocketService.broadcastedEvents.first?.event, "feature_flag.created")
    }
    
    func testUpdateFlag() async throws {
        // Arrange
        let userId = UUID()
        let originalFlag = mockRepository.addTestFlag(
            key: "original-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Original description",
            userId: userId
        )
        
        let request = UpdateFeatureFlagRequest(
            id: originalFlag.id,
            key: "updated-flag",
            type: .string,
            defaultValue: "new-value",
            description: "Updated description"
        )
        
        // Act
        let updatedFlag = try await service.updateFlag(id: originalFlag.id!, request, userId: userId)
        
        // Assert
        XCTAssertEqual(updatedFlag.id, originalFlag.id)
        XCTAssertEqual(updatedFlag.key, request.key)
        XCTAssertEqual(updatedFlag.type, request.type)
        XCTAssertEqual(updatedFlag.defaultValue, request.defaultValue)
        XCTAssertEqual(updatedFlag.description, request.description)
        
        // Verify repository was updated
        let savedFlag = try await mockRepository.get(id: originalFlag.id!)
        XCTAssertNotNil(savedFlag)
        XCTAssertEqual(savedFlag?.key, request.key)
        
        // Verify WebSocket notification was sent
        XCTAssertEqual(mockWebSocketService.broadcastedEvents.count, 1)
        XCTAssertEqual(mockWebSocketService.broadcastedEvents.first?.event, "feature_flag.updated")
    }
    
    func testDeleteFlag() async throws {
        // Arrange
        let userId = UUID()
        let flag = mockRepository.addTestFlag(
            key: "test-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Test flag",
            userId: userId
        )
        
        // Act
        try await service.deleteFlag(id: flag.id!, userId: userId)
        
        // Assert
        let deletedFlag = try await mockRepository.get(id: flag.id!)
        XCTAssertNil(deletedFlag)
        
        // Verify WebSocket notification was sent
        XCTAssertEqual(mockWebSocketService.broadcastedEvents.count, 1)
        XCTAssertEqual(mockWebSocketService.broadcastedEvents.first?.event, "feature_flag.deleted")
    }
    
    func testGetFlagsWithOverrides() async throws {
        // Arrange
        let userId = "test-user"
        let flag1 = mockRepository.addTestFlag(
            key: "flag1",
            type: .boolean,
            defaultValue: "false",
            description: "Flag 1"
        )
        
        // Add a second flag to test both overridden and non-overridden flags
        _ = mockRepository.addTestFlag(
            key: "flag2",
            type: .string,
            defaultValue: "default",
            description: "Flag 2"
        )
        
        let override = UserFeatureFlag(
            userId: userId,
            featureFlagId: flag1.id!,
            value: "true"
        )
        try await mockRepository.saveUserOverride(override)
        
        // Act
        let container = try await service.getFlagsWithOverrides(userId: userId)
        
        // Assert
        XCTAssertEqual(container.flags.count, 2)
        
        // Check overridden flag
        XCTAssertEqual(container.flags["flag1"]?.value, "true")
        XCTAssertEqual(container.flags["flag1"]?.isOverridden, true)
        
        // Check default flag
        XCTAssertEqual(container.flags["flag2"]?.value, "default")
        XCTAssertEqual(container.flags["flag2"]?.isOverridden, false)
    }
    
    // Note: The following tests would require additional methods in the FeatureFlagService
    // that aren't shown in the provided code. If these methods exist, uncomment these tests.
    
    /*
    func testSetUserOverride() async throws {
        // Arrange
        let flag = mockRepository.addTestFlag(
            key: "test-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Test flag"
        )
        
        let userId = "test-user"
        
        // Act
        try await service.setUserOverride(userId: userId, flagId: flag.id!, value: "true")
        
        // Assert
        let override = try await mockRepository.getUserOverride(userId: userId, flagId: flag.id!)
        XCTAssertNotNil(override)
        XCTAssertEqual(override?.userId, userId)
        XCTAssertEqual(override?.$featureFlag.id, flag.id)
        XCTAssertEqual(override?.value, "true")
    }
    
    func testRemoveUserOverride() async throws {
        // Arrange
        let flag = mockRepository.addTestFlag(
            key: "test-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Test flag"
        )
        
        let userId = "test-user"
        let override = UserFeatureFlag(
            userId: userId,
            featureFlagId: flag.id!,
            value: "true"
        )
        try await mockRepository.saveUserOverride(override)
        
        // Act
        try await service.removeUserOverride(userId: userId, flagId: flag.id!)
        
        // Assert
        let deletedOverride = try await mockRepository.getUserOverride(userId: userId, flagId: flag.id!)
        XCTAssertNil(deletedOverride)
    }
    */
} 