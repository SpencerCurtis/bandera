import Vapor
import Fluent

/// Service for feature flag business logic.
///
/// This service implements the business logic for feature flag operations,
/// including creating, updating, deleting, and retrieving feature flags.
/// It uses a repository for data access and a WebSocket service for
/// broadcasting real-time updates.
struct FeatureFlagService: FeatureFlagServiceProtocol {
    /// The repository for feature flag data access
    let repository: FeatureFlagRepositoryProtocol
    
    /// The WebSocket service for broadcasting events
    let webSocketService: WebSocketServiceProtocol
    
    /// Initialize a new feature flag service
    /// - Parameters:
    ///   - repository: The repository for feature flag data access
    ///   - webSocketService: The WebSocket service for broadcasting events
    init(repository: FeatureFlagRepositoryProtocol, webSocketService: WebSocketServiceProtocol) {
        self.repository = repository
        self.webSocketService = webSocketService
    }
    
    /// Get a feature flag by ID
    /// - Parameters:
    ///   - id: The ID of the feature flag
    ///   - userId: The ID of the user requesting the flag
    /// - Returns: The feature flag
    /// - Throws: ResourceError if the flag is not found or not accessible
    func getFlag(id: UUID, userId: UUID) async throws -> FeatureFlag {
        return try await withErrorHandling {
            guard let flag = try await repository.get(id: id) else {
                throw ResourceError.notFound("Feature flag with ID \(id)")
            }
            
            // Check if flag belongs to this user
            if flag.$userId.wrappedValue != userId {
                throw AuthenticationError.accessDenied
            }
            
            return flag
        }
    }
    
    /// Get all feature flags for a user
    /// - Parameter userId: The ID of the user
    /// - Returns: An array of feature flags
    /// - Throws: ResourceError if the operation fails
    func getAllFlags(userId: UUID) async throws -> [FeatureFlag] {
        return try await withErrorHandling {
            try await repository.getAllForUser(userId: userId)
        }
    }
    
    /// Get all feature flags with their overrides for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: A container with all feature flags and their overrides for the user
    /// - Throws: BanderaError if the operation fails
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer {
        return try await withErrorHandling {
            try await repository.getFlagsWithOverrides(userId: userId)
        }
    }
    
    /// Create a new feature flag
    /// - Parameters:
    ///   - dto: The feature flag data
    ///   - userId: The ID of the user creating the flag
    /// - Returns: The created feature flag
    /// - Throws: ResourceError if the flag cannot be created
    func createFlag(_ dto: CreateFeatureFlagRequest, userId: UUID) async throws -> FeatureFlag {
        return try await withErrorHandling {
            // Check if a flag with this key already exists for this user
            if try await repository.exists(key: dto.key, userId: userId) {
                throw ResourceError.alreadyExists("Feature flag with key '\(dto.key)'")
            }
            
            // Create the flag
            let flag = FeatureFlag.create(from: dto, userId: userId)
            try await repository.save(flag)
            
            // Broadcast the event
            try await broadcastEvent(FeatureFlagEventType.created, flag: flag)
            
            return flag
        }
    }
    
    /// Update a feature flag
    /// - Parameters:
    ///   - id: The ID of the feature flag
    ///   - dto: The updated feature flag data
    ///   - userId: The ID of the user updating the flag
    /// - Returns: The updated feature flag
    /// - Throws: ResourceError if the flag cannot be updated
    func updateFlag(id: UUID, _ dto: UpdateFeatureFlagRequest, userId: UUID) async throws -> FeatureFlag {
        return try await withErrorHandling {
            // Get the flag
            let flag = try await getFlag(id: id, userId: userId)
            
            // Check if another flag with this key already exists for this user
            if dto.key != flag.key, try await repository.exists(key: dto.key, userId: userId) {
                throw ResourceError.alreadyExists("Feature flag with key '\(dto.key)'")
            }
            
            // Update the flag
            flag.update(from: dto)
            try await repository.save(flag)
            
            // Broadcast the event
            try await broadcastEvent(FeatureFlagEventType.updated, flag: flag)
            
            return flag
        }
    }
    
    /// Delete a feature flag
    /// - Parameters:
    ///   - id: The ID of the feature flag
    ///   - userId: The ID of the user deleting the flag
    /// - Throws: ResourceError if the flag cannot be deleted
    func deleteFlag(id: UUID, userId: UUID) async throws {
        try await withErrorHandling {
            // Get the flag
            let flag = try await getFlag(id: id, userId: userId)
            
            // Delete the flag
            try await repository.delete(flag)
            
            // Broadcast the event
            try await broadcastDeleteEvent(id: id, userId: userId)
        }
    }
    
    /// Broadcast a feature flag event
    /// - Parameters:
    ///   - event: The event type
    ///   - flag: The feature flag
    func broadcastEvent(_ event: FeatureFlagEventType, flag: FeatureFlag) async throws {
        // Create the event payload
        let payload = FeatureFlagEventPayload(
            event: event,
            flag: FeatureFlagResponse(flag: flag)
        )
        
        // Broadcast to all clients
        try await webSocketService.broadcast(event: event.rawValue, data: payload)
    }
    
    /// Broadcast a feature flag deletion event
    /// - Parameters:
    ///   - id: The unique identifier of the deleted feature flag
    ///   - userId: The unique identifier of the user who deleted the flag
    func broadcastDeleteEvent(id: UUID, userId: UUID) async throws {
        // Create the event payload
        let payload = FeatureFlagDeleteEventPayload(
            event: .deleted,
            flagId: id,
            userId: userId
        )
        
        // Broadcast to all clients
        try await webSocketService.broadcast(event: FeatureFlagEventType.deleted.rawValue, data: payload)
    }
}

// MARK: - Error Handling

/// Execute a block with error handling
private func withErrorHandling<T>(_ block: () async throws -> T) async throws -> T {
    do {
        return try await block()
    } catch let error as any BanderaErrorProtocol {
        throw error
    } catch {
        throw ServerError.generic("An unexpected error occurred: \(error.localizedDescription)")
    }
} 