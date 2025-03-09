@testable import App
import XCTVapor

extension Application {
    /// Creates a testable application with a custom configuration
    /// - Returns: A configured application for testing
    static func testable() async throws -> Application {
        // Create a testing application
        let app = try await Application.make(.testing)
        
        // Configure the application
        try await configure(app)
        
        return app
    }
    
    /// Shuts down the application asynchronously
    func asyncShutdown() async throws {
        // Use a continuation to wrap the synchronous shutdown
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                self.shutdown()
                continuation.resume()
            }
        }
    }
} 