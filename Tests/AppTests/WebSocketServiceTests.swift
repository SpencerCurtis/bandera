@testable import App
import XCTVapor
import XCTest

final class WebSocketServiceTests: XCTestCase {
    var app: Application!
    var mockWebSocketService: MockWebSocketService!
    
    override func setUp() async throws {
        app = try await Application.testable()
        mockWebSocketService = MockWebSocketService()
        
        // Create a custom service container with our mock
        let featureFlagRepository = FeatureFlagRepository(database: app.db)
        let userRepository = UserRepository(database: app.db)
        let featureFlagService = FeatureFlagService(
            repository: featureFlagRepository,
            webSocketService: mockWebSocketService
        )
        let authService = AuthService(
            userRepository: userRepository,
            jwtSigner: app.jwt.signers
        )
        
        // Initialize with all services and repositories
        app.services = ServiceContainer(
            webSocketService: mockWebSocketService,
            featureFlagRepository: featureFlagRepository,
            userRepository: userRepository,
            featureFlagService: featureFlagService,
            authService: authService
        )
    }
    
    override func tearDown() async throws {
        // Use a detached task to call shutdown to avoid async context warning
        let app = self.app
        self.app = nil
        
        // Shutdown in a detached task to avoid blocking
        Task.detached {
            app?.shutdown()
        }
    }
    
    func testServiceContainer() async throws {
        // Test that the service container is properly initialized
        XCTAssertNotNil(app.services.webSocketService)
        
        // Test that the service container returns the mock service
        XCTAssert(app.services.webSocketService is MockWebSocketService)
    }
    
    func testBroadcastMessage() async throws {
        // Arrange
        let message = "Test message"
        
        // Act
        try await app.services.webSocketService.broadcast(message: message)
        
        // Assert - get values without await since they're not async properties
        let messagesCount = mockWebSocketService.broadcastedMessages.count
        let firstMessage = mockWebSocketService.broadcastedMessages.first
        
        XCTAssertEqual(messagesCount, 1)
        XCTAssertEqual(firstMessage, message)
    }
    
    func testBroadcastEvent() async throws {
        // Arrange
        let event = "test.event"
        let data = ["key": "value"]
        
        // Act
        try await app.services.webSocketService.broadcast(event: event, data: data)
        
        // Assert - get values without await since they're not async properties
        let eventsCount = mockWebSocketService.broadcastedEvents.count
        let firstEventName = mockWebSocketService.broadcastedEvents.first?.event
        
        XCTAssertEqual(eventsCount, 1)
        XCTAssertEqual(firstEventName, event)
    }
} 