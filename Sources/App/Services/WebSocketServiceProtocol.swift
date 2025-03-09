import Vapor
import WebSocketKit

/// Protocol defining the interface for a WebSocket service.
///
/// This protocol defines the methods for managing WebSocket connections
/// and broadcasting messages to connected clients.
protocol WebSocketServiceProtocol {
    /// Add a WebSocket connection
    /// - Parameters:
    ///   - ws: The WebSocket to add
    ///   - id: The unique identifier for the connection
    func add(_ ws: WebSocket, id: UUID) async
    
    /// Remove a WebSocket connection
    /// - Parameter id: The unique identifier of the connection to remove
    func remove(id: UUID) async
    
    /// Broadcast a message to all connected WebSockets
    /// - Parameter message: The message to broadcast
    func broadcast(message: String) async throws
    
    /// Broadcast an event with data to all connected WebSockets
    /// - Parameters:
    ///   - event: The event name
    ///   - data: The data to broadcast
    func broadcast<T: Codable & Sendable>(event: String, data: T) async throws
    
    /// Broadcast a message to a specific WebSocket
    func send(message: String, to id: UUID) async throws
    
    /// Broadcast a message to a specific WebSocket
    func send<T: Codable & Sendable>(event: String, data: T, to id: UUID) async throws
    
    /// Get the current number of connections
    /// - Returns: The number of active connections
    func connectionCount() async -> Int
}