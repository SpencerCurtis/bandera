import Vapor
import WebSocketKit
import NIOCore
import NIOConcurrencyHelpers

/// Service for managing WebSocket connections
public actor WebSocketService: WebSocketServiceProtocol {
    private var connections: [UUID: WebSocket]
    private let logger: Logger
    
    /// Initialize a new WebSocket service
    public init() {
        self.connections = [:]
        self.logger = Logger(label: "codes.vapor.websocket")
    }
    
    /// Add a WebSocket connection
    /// - Parameters:
    ///   - ws: The WebSocket to add
    ///   - id: The unique identifier for the connection
    public func add(_ ws: WebSocket, id: UUID) async {
        connections[id] = ws
        logger.info("Added WebSocket connection: \(id). Total connections: \(connections.count)")
    }
    
    /// Remove a WebSocket connection
    /// - Parameter id: The unique identifier of the connection to remove
    public func remove(id: UUID) async {
        connections[id] = nil
        logger.info("Removed WebSocket connection: \(id). Total connections: \(connections.count)")
    }
    
    /// Broadcast a message to all connected WebSockets
    /// - Parameter message: The message to broadcast
    public func broadcast(message: String) async throws {
        logger.info("Broadcasting message to \(connections.count) connections")
        
        for ws in connections.values {
            try await ws.send(message)
        }
    }
    
    /// Broadcast an event with data to all connected WebSockets
    /// - Parameters:
    ///   - event: The event name
    ///   - data: The data to broadcast
    public func broadcast<T: Codable & Sendable>(event: String, data: T) async throws {
        let payload = DTOs.Message(event: event, data: data)
        let jsonData = try JSONEncoder().encode(payload)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            logger.error("Failed to create JSON string from payload")
            throw BanderaError.internalServerError("Failed to create JSON string from payload")
        }
        logger.info("Broadcasting event: \(event)")
        try await broadcast(message: jsonString)
    }
    
    /// Get the current number of connections
    /// - Returns: The number of active connections
    public func connectionCount() async -> Int {
        connections.count
    }
}

// MARK: - Feature Flag Events (Deprecated)
@available(*, deprecated, message: "Use WebSocketDTOs.FeatureFlagEvent instead")
extension WebSocketService {
    /// Events that can be broadcast over WebSockets
    public enum FeatureFlagEvent: String {
        case created = "feature_flag.created"
        case updated = "feature_flag.updated"
        case deleted = "feature_flag.deleted"
        case overrideCreated = "feature_flag.override.created"
        case overrideUpdated = "feature_flag.override.updated"
        case overrideDeleted = "feature_flag.override.deleted"
    }
}

// MARK: - Legacy Application Extension (Deprecated)
@available(*, deprecated, message: "Use Request.services.webSocketService instead")
extension Application {
    private struct WebSocketServiceKey: StorageKey {
        typealias Value = WebSocketService
    }
    
    var webSocketService: WebSocketService {
        get {
            if let existing = storage[WebSocketServiceKey.self] {
                return existing
            }
            
            // Create a new instance if we don't have one
            let new = WebSocketService()
            storage[WebSocketServiceKey.self] = new
            return new
        }
        set {
            storage[WebSocketServiceKey.self] = newValue
        }
    }
} 