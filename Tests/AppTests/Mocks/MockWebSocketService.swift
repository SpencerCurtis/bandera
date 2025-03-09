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
    
    /// Feature flag events that have been broadcast
    private(set) var broadcastedFeatureFlagEvents: [(flag: FeatureFlag, userId: String, eventType: String)] = []
    
    /// Feature flag deletion events that have been broadcast
    private(set) var broadcastedFeatureFlagDeletions: [(id: UUID, userId: String)] = []
    
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
        
        // Handle feature flag events
        if event.contains("feature_flag.") {
            if let payload = data as? FeatureFlagEventPayload {
                // For created and updated events
                if event == FeatureFlagEventType.created.rawValue || event == FeatureFlagEventType.updated.rawValue {
                    // Extract the flag from the payload
                    let flag = FeatureFlag(
                        id: payload.flag.id,
                        key: payload.flag.key,
                        type: payload.flag.type,
                        defaultValue: payload.flag.value,
                        description: payload.flag.description
                    )
                    
                    // Add to the broadcastedFeatureFlagEvents array
                    broadcastedFeatureFlagEvents.append((flag: flag, userId: "test-user", eventType: event))
                }
            } else if let payload = data as? FeatureFlagDeleteEventPayload {
                // For deleted events
                if event == FeatureFlagEventType.deleted.rawValue {
                    // Add to the broadcastedFeatureFlagDeletions array
                    broadcastedFeatureFlagDeletions.append((id: payload.flagId, userId: "test-user"))
                }
            }
        }
    }
    
    func send(message: String, to id: UUID) async throws {
        broadcastedMessages.append(message)
    }
    
    func send<T: Codable & Sendable>(event: String, data: T, to id: UUID) async throws {
        broadcastedEvents.append((event: event, data: data))
    }
    
    func connectionCount() async -> Int {
        connections.count
    }
    
    func broadcastFlagCreated(_ flag: FeatureFlag, userId: String) async {
        broadcastedFeatureFlagEvents.append((flag: flag, userId: userId, eventType: "feature_flag.created"))
    }
    
    func broadcastFlagUpdated(_ flag: FeatureFlag, userId: String) async {
        broadcastedFeatureFlagEvents.append((flag: flag, userId: userId, eventType: "feature_flag.updated"))
    }
    
    func broadcastFlagDeleted(_ id: UUID, userId: String) async {
        broadcastedFeatureFlagDeletions.append((id: id, userId: userId))
    }
    
    // MARK: - Testing Helpers
    
    /// Reset all recorded data
    func reset() {
        broadcastedMessages = []
        broadcastedEvents = []
        broadcastedFeatureFlagEvents = []
        broadcastedFeatureFlagDeletions = []
        connections = [:]
    }
} 