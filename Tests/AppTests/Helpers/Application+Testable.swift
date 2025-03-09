@testable import App
import XCTVapor

extension Application {
    /// Creates a testable application with a custom configuration
    /// - Returns: A configured application for testing
    static func testable() async throws -> Application {
        // Create a testing application
        let app = Application(.testing)
        
        // Configure the application
        try await configure(app)
        
        return app
    }
} 