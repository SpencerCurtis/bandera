@testable import App
import XCTVapor

extension Application {
    /// Creates a testable application with a custom configuration
    /// - Returns: A configured application for testing
    static func testable() async throws -> Application {
        let app = Application(.testing)
        try await configure(app)
        
        // Override services with test versions if needed
        // app.services = ServiceContainer(webSocketService: MockWebSocketService())
        
        try app.boot()
        return app
    }
} 