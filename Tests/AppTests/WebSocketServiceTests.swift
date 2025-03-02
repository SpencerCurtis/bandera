@testable import App
import XCTVapor
import XCTest

final class WebSocketServiceTests: XCTestCase {
    var app: Application!
    var mockWebSocketService: MockWebSocketService!
    
    override func setUp() async throws {
        app = try await Application.testable()
        mockWebSocketService = MockWebSocketService()
        app.services = ServiceContainer(webSocketService: mockWebSocketService)
    }
    
    override func tearDown() async throws {
        app.shutdown()
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
        
        // Assert
        XCTAssertEqual(await mockWebSocketService.broadcastedMessages.count, 1)
        XCTAssertEqual(await mockWebSocketService.broadcastedMessages.first, message)
    }
    
    func testBroadcastEvent() async throws {
        // Arrange
        let event = "test.event"
        let data = ["key": "value"]
        
        // Act
        try await app.services.webSocketService.broadcast(event: event, data: data)
        
        // Assert
        XCTAssertEqual(await mockWebSocketService.broadcastedEvents.count, 1)
        XCTAssertEqual(await mockWebSocketService.broadcastedEvents.first?.event, event)
    }
} 