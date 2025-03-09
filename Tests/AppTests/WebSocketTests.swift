@testable import App
import XCTVapor
import WebSocketKit
import XCTest

final class WebSocketTests: XCTestCase {
    var app: Application!
    var testUser: User!
    var authToken: String!
    
    override func setUp() async throws {
        app = try await Application.testable()
        
        // Create a test user
        let createUser = CreateUserRequest(
            email: "websocket-test@example.com",
            password: "password123",
            name: "WebSocket Test User"
        )
        
        testUser = try await UserController().create(
            user: createUser,
            on: app.db
        )
        
        // Get auth token
        let loginRequest = LoginRequest(
            email: "websocket-test@example.com",
            password: "password123"
        )
        
        let loginResponse = try await app.sendRequest(.POST, "auth/login", body: loginRequest)
        let loginResult = try loginResponse.content.decode(AuthResponse.self)
        authToken = loginResult.token
    }
    
    override func tearDown() async throws {
        app.shutdown()
    }
    
    func testWebSocketConnection() async throws {
        // Create a WebSocket client
        let client = WebSocketClient(eventLoop: app.eventLoopGroup.next())
        
        // Connect to the WebSocket endpoint
        let promise = app.eventLoopGroup.next().makePromise(of: Void.self)
        var receivedMessages: [String] = []
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(authToken!)"
        ]
        
        try await client.connect(to: "ws://localhost:8080/flags/socket", headers: headers) { ws in
            ws.onText { _, text in
                receivedMessages.append(text)
                if receivedMessages.count >= 3 {
                    promise.succeed(())
                }
            }
            
            // Create a feature flag
            Task {
                do {
                    let createFlag = CreateFeatureFlagRequest(
                        key: "test-websocket-flag",
                        name: "Test WebSocket Flag",
                        description: "A flag for testing WebSockets",
                        defaultValue: "true",
                        enabled: true
                    )
                    
                    // Create the flag
                    let createResponse = try await self.app.sendRequest(
                        .POST,
                        "feature-flags",
                        headers: ["Authorization": "Bearer \(self.authToken!)"],
                        body: createFlag
                    )
                    
                    let flag = try createResponse.content.decode(FeatureFlag.self)
                    
                    // Update the flag
                    let updateFlag = UpdateFeatureFlagRequest(
                        key: "test-websocket-flag",
                        name: "Updated Test WebSocket Flag",
                        description: "An updated flag for testing WebSockets",
                        defaultValue: "false",
                        enabled: false
                    )
                    
                    _ = try await self.app.sendRequest(
                        .PUT,
                        "feature-flags/\(flag.id!)",
                        headers: ["Authorization": "Bearer \(self.authToken!)"],
                        body: updateFlag
                    )
                    
                    // Delete the flag
                    _ = try await self.app.sendRequest(
                        .DELETE,
                        "feature-flags/\(flag.id!)",
                        headers: ["Authorization": "Bearer \(self.authToken!)"]
                    )
                } catch {
                    promise.fail(error)
                }
            }
        }
        
        // Wait for the promise to be fulfilled
        try await promise.futureResult.get()
        
        // Verify we received the expected messages
        XCTAssertEqual(receivedMessages.count, 3)
        
        // Verify the message contents
        XCTAssertTrue(receivedMessages[0].contains("feature_flag.created"))
        XCTAssertTrue(receivedMessages[1].contains("feature_flag.updated"))
        XCTAssertTrue(receivedMessages[2].contains("feature_flag.deleted"))
    }
}

// Helper extension for testing
extension Application {
    static func testable() async throws -> Application {
        let app = Application(.testing)
        try await configure(app)
        
        try app.autoMigrate().wait()
        
        return app
    }
}

extension XCTApplicationTester {
    @discardableResult
    func sendRequest(
        _ method: HTTPMethod,
        _ path: String,
        headers: [String: String] = [:],
        body: Encodable? = nil
    ) async throws -> XCTHTTPResponse {
        var request = XCTHTTPRequest(
            method: method,
            url: .init(path: path)
        )
        
        // Add headers
        for (key, value) in headers {
            request.headers.add(name: key, value: value)
        }
        
        // Add body if provided
        if let body = body {
            request.body = try JSONEncoder().encode(body)
            request.headers.contentType = .json
        }
        
        return try await performTest(request)
    }
}
