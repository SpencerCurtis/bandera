// @testable import App
// import XCTVapor
// import NIO
// import WebSocketKit

// final class WebSocketTests: XCTestCase {
//     var app: Application!
//     var adminToken: String!
//     var userToken: String!
    
//     override func setUp() async throws {
//         app = try await Application.make(.testing)
//         try await configure(app)
        
//         // Clean up any existing data
//         try await User.query(on: app.db).delete()
//         try await FeatureFlag.query(on: app.db).delete()
//         try await UserFeatureFlag.query(on: app.db).delete()
        
//         // Create admin user and get token
//         let adminUser = try User.create(from: .init(
//             email: "admin@example.com",
//             password: "adminpass123",
//             isAdmin: true
//         ))
//         try await adminUser.save(on: app.db)
//         let adminPayload = try UserJWTPayload(user: adminUser)
//         adminToken = try app.jwt.signers.sign(adminPayload)
        
//         // Create regular user and get token
//         let regularUser = try User.create(from: .init(
//             email: "user@example.com",
//             password: "userpass123",
//             isAdmin: false
//         ))
//         try await regularUser.save(on: app.db)
//         let userPayload = try UserJWTPayload(user: regularUser)
//         userToken = try app.jwt.signers.sign(userPayload)
//     }
    
//     override func tearDown() async throws {
//         // Clean up the database
//         try await User.query(on: app.db).delete()
//         try await FeatureFlag.query(on: app.db).delete()
//         try await UserFeatureFlag.query(on: app.db).delete()
//         try await app.asyncShutdown()
//     }
    
//     func testWebSocketConnection() async throws {
//         // Given
//         let expectation = XCTestExpectation(description: "WebSocket connection established")
//         let storage = ActorWebSocketStorage()
        
//         // When
//         try await app.testable().test(.GET, "/ws/feature-flags", beforeRequest: { req in
//             req.headers.bearerAuthorization = .init(token: userToken ?? "")
//             req.headers.add(name: .upgrade, value: "websocket")
//             req.headers.add(name: .connection, value: "upgrade")
//             req.headers.add(name: .secWebSocketVersion, value: "13")
//             req.headers.add(name: .secWebSocketKey, value: "dGhlIHNhbXBsZSBub25jZQ==")
//             req.headers.add(name: .host, value: "127.0.0.1")
//         }, afterResponse: { res in
//             XCTAssertEqual(res.status, .switchingProtocols)
//             XCTAssertEqual(res.headers[.connection].first?.lowercased(), "upgrade")
//             XCTAssertEqual(res.headers[.upgrade].first?.lowercased(), "websocket")
//             XCTAssertNotNil(res.headers[.secWebSocketAccept].first)
//             expectation.fulfill()
//         })
        
//         await fulfillment(of: [expectation], timeout: 5.0)
//     }
    
//     func testWebSocketConnectionUnauthorized() async throws {
//         // When/Then
//         try await app.testable().test(.GET, "/ws/feature-flags", beforeRequest: { req in
//             req.headers.add(name: .upgrade, value: "websocket")
//             req.headers.add(name: .connection, value: "upgrade")
//             req.headers.add(name: .secWebSocketVersion, value: "13")
//             req.headers.add(name: .secWebSocketKey, value: "dGhlIHNhbXBsZSBub25jZQ==")
//             req.headers.add(name: .host, value: "127.0.0.1")
//         }, afterResponse: { res in
//             XCTAssertEqual(res.status, .unauthorized)
//         })
//     }
// }

// // Thread-safe actor to store WebSocket reference
// private actor ActorWebSocketStorage {
//     private var webSocket: WebSocket?
    
//     func setWebSocket(_ ws: WebSocket) {
//         self.webSocket = ws
//     }
    
//     func getWebSocket() -> WebSocket? {
//         self.webSocket
//     }
// }
