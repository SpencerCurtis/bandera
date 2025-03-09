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
        let createUser = RegisterRequest(
            email: "websocket-test@example.com",
            password: "password123",
            isAdmin: false
        )
        
        // Create the user directly
        testUser = try User.create(from: createUser)
        try await testUser.save(on: app.db)
        
        // Get auth token using the AuthService
        let authService = AuthService(
            userRepository: UserRepository(database: app.db),
            jwtSigner: app.jwt.signers
        )
        
        let loginRequest = LoginRequest(
            email: "websocket-test@example.com",
            password: "password123"
        )
        
        let authResponse = try await authService.login(loginRequest)
        authToken = authResponse.token
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
    
    func testWebSocketConnection() async throws {
        // Create a WebSocket client with the correct initialization
        let client = WebSocketClient(
            eventLoopGroupProvider: .shared(app.eventLoopGroup)
        )
        
        // Connect to the WebSocket endpoint
        let promise = app.eventLoopGroup.next().makePromise(of: Void.self)
        var receivedMessages: [String] = []
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(authToken!)"
        ]
        
        try await client.connect(
            scheme: "ws",
            host: "localhost",
            port: 8080,
            path: "/flags/socket",
            headers: headers
        ) { ws in
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
                        type: .boolean,
                        defaultValue: "true",
                        description: "A flag for testing WebSockets"
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
                        id: flag.id,
                        key: "test-websocket-flag",
                        type: .string,
                        defaultValue: "false",
                        description: "An updated flag for testing WebSockets"
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
extension XCTApplicationTester {
    @discardableResult
    func sendRequest(
        _ method: HTTPMethod,
        _ path: String,
        headers: [String: String] = [:],
        body: Encodable? = nil
    ) async throws -> XCTHTTPResponse {
        // Create empty headers and body
        let emptyHeaders = HTTPHeaders()
        var emptyBody = ByteBufferAllocator().buffer(capacity: 0)
        
        // Initialize with required parameters
        var request = XCTHTTPRequest(
            method: method,
            url: .init(path: path),
            headers: emptyHeaders,
            body: emptyBody
        )
        
        // Add headers
        for (key, value) in headers {
            request.headers.add(name: key, value: value)
        }
        
        if let body = body {
            // Convert the Encodable to a ByteBuffer
            let data = try JSONEncoder().encode(body)
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            request.body = buffer
            request.headers.contentType = .json
        }
        
        return try await performTest(request: request)
    }
}
