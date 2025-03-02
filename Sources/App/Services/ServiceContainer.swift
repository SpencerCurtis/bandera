import Vapor

/// A container for all application services
public final class ServiceContainer: @unchecked Sendable {
    // MARK: - Properties
    
    /// The WebSocket service for managing WebSocket connections
    public let webSocketService: WebSocketServiceProtocol
    
    // MARK: - Initialization
    
    /// Creates a new service container with the specified services
    /// - Parameter webSocketService: The WebSocket service
    public init(webSocketService: WebSocketServiceProtocol) {
        self.webSocketService = webSocketService
    }
    
    /// Creates a new service container with default services
    public convenience init() {
        self.init(
            webSocketService: WebSocketService()
        )
    }
}

// MARK: - Application Extension

extension Application {
    private struct ServiceContainerKey: StorageKey {
        typealias Value = ServiceContainer
    }
    
    /// The application's service container
    public var services: ServiceContainer {
        get {
            if let existing = storage[ServiceContainerKey.self] {
                return existing
            }
            let new = ServiceContainer()
            storage[ServiceContainerKey.self] = new
            return new
        }
        set {
            storage[ServiceContainerKey.self] = newValue
        }
    }
}

// MARK: - Request Extension

extension Request {
    /// The request's service container
    public var services: ServiceContainer {
        application.services
    }
} 