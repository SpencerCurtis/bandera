import Vapor
import WebSocketKit
import NIOCore
import NIOConcurrencyHelpers

/// Service for managing WebSocket connections
actor WebSocketService: WebSocketServiceProtocol {
    private var connections: [UUID: WebSocket]
    private let logger: Logger
    
    /// Initialize a new WebSocket service
    init() {
        self.connections = [:]
        self.logger = Logger(label: "codes.vapor.websocket")
    }
    
    /// Add a WebSocket connection
    /// - Parameters:
    ///   - ws: The WebSocket to add
    ///   - id: The unique identifier for the connection
    func add(_ ws: WebSocket, id: UUID) async {
        connections[id] = ws
        logger.info("Added WebSocket connection: \(id). Total connections: \(connections.count)")
    }
    
    /// Remove a WebSocket connection
    /// - Parameter id: The unique identifier of the connection to remove
    func remove(id: UUID) async {
        connections[id] = nil
        logger.info("Removed WebSocket connection: \(id). Total connections: \(connections.count)")
    }
    
    /// Broadcast a message to all connected WebSockets
    /// - Parameter message: The message to broadcast
    func broadcast(message: String) async throws {
        logger.info("Broadcasting message to \(connections.count) connections")
        
        for ws in connections.values {
            try await ws.send(message)
        }
    }
    
    /// Broadcast an event with data to all connected WebSockets
    /// - Parameters:
    ///   - event: The event name
    ///   - data: The data to broadcast
    func broadcast<T: Codable & Sendable>(event: String, data: T) async throws {
        let payload = WebSocketMessage(event: event, data: data)
        let jsonData = try JSONEncoder().encode(payload)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ServerError.internal("Failed to encode WebSocket message")
        }
        
        try await broadcast(message: jsonString)
    }
    
    /// Broadcast a message to a specific WebSocket
    /// - Parameters:
    ///   - message: The message to broadcast
    ///   - id: The unique identifier of the connection to send to
    func send(message: String, to id: UUID) async throws {
        guard let ws = connections[id] else {
            throw ResourceError.notFound("WebSocket connection with ID \(id)")
        }
        
        try await ws.send(message)
    }
    
    /// Broadcast a message to a specific WebSocket
    /// - Parameters:
    ///   - event: The event name
    ///   - data: The data to broadcast
    ///   - id: The unique identifier of the connection to send to
    func send<T: Codable & Sendable>(event: String, data: T, to id: UUID) async throws {
        let payload = WebSocketMessage(event: event, data: data)
        let jsonData = try JSONEncoder().encode(payload)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ServerError.internal("Failed to encode WebSocket message")
        }
        
        try await send(message: jsonString, to: id)
    }
    
    /// Get the current number of connections
    /// - Returns: The number of active connections
    func connectionCount() async -> Int {
        return connections.count
    }
}