import Vapor
import WebSocketKit
import NIOCore
import NIOConcurrencyHelpers

actor WebSocketService {
    private var connections: [UUID: WebSocket]
    private let logger: Logger
    
    init() {
        self.connections = [:]
        self.logger = Logger(label: "codes.vapor.websocket")
    }
    
    func add(_ ws: WebSocket, id: UUID) async {
        connections[id] = ws
        logger.info("Added WebSocket connection: \(id). Total connections: \(connections.count)")
    }
    
    func remove(id: UUID) async {
        connections[id] = nil
        logger.info("Removed WebSocket connection: \(id). Total connections: \(connections.count)")
    }
    
    func broadcast(message: String) async throws {
        logger.info("Broadcasting message to \(connections.count) connections")
        
        for ws in connections.values {
            try await ws.send(message)
        }
    }
    
    func broadcast<T: Codable>(event: String, data: T) async throws {
        let payload = WebSocketMessage(event: event, data: data)
        let jsonData = try JSONEncoder().encode(payload)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            logger.error("Failed to create JSON string from payload")
            throw Abort(.internalServerError)
        }
        logger.info("Broadcasting event: \(event)")
        try await broadcast(message: jsonString)
    }
    
    func connectionCount() async -> Int {
        connections.count
    }
}

// MARK: - WebSocket Message Types
struct WebSocketMessage<T: Codable>: Codable {
    let event: String
    let data: T
}

// MARK: - Feature Flag Events
extension WebSocketService {
    enum FeatureFlagEvent: String {
        case created = "feature_flag.created"
        case updated = "feature_flag.updated"
        case deleted = "feature_flag.deleted"
        case overrideCreated = "feature_flag.override.created"
        case overrideUpdated = "feature_flag.override.updated"
        case overrideDeleted = "feature_flag.override.deleted"
    }
}

// MARK: - Application Extension
extension Application {
    private struct WebSocketServiceKey: StorageKey {
        typealias Value = WebSocketService
    }
    
    var webSocketService: WebSocketService {
        get {
            if let existing = storage[WebSocketServiceKey.self] {
                return existing
            }
            let new = WebSocketService()
            storage[WebSocketServiceKey.self] = new
            return new
        }
        set {
            storage[WebSocketServiceKey.self] = newValue
        }
    }
} 