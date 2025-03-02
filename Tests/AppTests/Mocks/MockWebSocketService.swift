import Vapor
import WebSocketKit
@testable import App

/// A mock implementation of WebSocketServiceProtocol for testing
final class MockWebSocketService: WebSocketServiceProtocol {
    // MARK: - Properties
    
    /// Messages that have been broadcast
    private(set) var broadcastedMessages: [String] = []
    
    /// Events that have been broadcast
    private(set) var broadcastedEvents: [(event: String, data: Any)] = []
    
    /// Connections that have been added
    private(set) var connections: [UUID: WebSocket] = [:]
    
    // MARK: - WebSocketServiceProtocol
    
    func add(_ ws: WebSocket, id: UUID) async {
        connections[id] = ws
    }
    
    func remove(id: UUID) async {
        connections[id] = nil
    }
    
    func broadcast(message: String) async throws {
        broadcastedMessages.append(message)
    }
    
    func broadcast<T: Codable & Sendable>(event: String, data: T) async throws {
        broadcastedEvents.append((event: event, data: data))
    }
    
    func connectionCount() async -> Int {
        connections.count
    }
    
    // MARK: - Testing Helpers
    
    /// Reset all recorded data
    func reset() {
        broadcastedMessages = []
        broadcastedEvents = []
        connections = [:]
    }
} 