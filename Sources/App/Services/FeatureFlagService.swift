import Vapor
import Fluent

/// Service for feature flag business logic
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
    ///   - id: The unique identifier of the feature flag
    ///   - userId: The unique identifier of the user making the request
    /// - Returns: The feature flag if found and accessible
    func getFlag(id: UUID, userId: UUID) async throws -> FeatureFlag {
        guard let flag = try await repository.get(id: id) else {
            throw BanderaError.resourceNotFound("Feature flag")
        }
        
        // Check if flag belongs to this user
        if flag.$userId.wrappedValue != userId {
            throw BanderaError.accessDenied
        }
        
        return flag
    }
    
    /// Get all feature flags for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: All feature flags for the user
    func getAllFlags(userId: UUID) async throws -> [FeatureFlag] {
        try await repository.getAllForUser(userId: userId)
    }
    
    /// Get all feature flags with their overrides for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: A container with all feature flags and their overrides for the user
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagDTOs.FlagsContainer {
        try await repository.getFlagsWithOverrides(userId: userId)
    }
    
    /// Create a new feature flag
    /// - Parameters:
    ///   - dto: The DTO with feature flag data
    ///   - userId: The unique identifier of the user creating the flag
    /// - Returns: The created feature flag
    func createFlag(_ dto: FeatureFlagDTOs.CreateRequest, userId: UUID) async throws -> FeatureFlag {
        // Check if flag with same key exists for this user
        if try await repository.exists(key: dto.key, userId: userId) {
            throw BanderaError.resourceAlreadyExists("Feature flag with key '\(dto.key)'")
        }
        
        // Create new flag
        let flag = FeatureFlag(
            key: dto.key,
            type: dto.type,
            defaultValue: dto.defaultValue,
            description: dto.description,
            userId: userId
        )
        
        // Save flag
        try await repository.save(flag)
        
        // Broadcast event
        try await broadcastEvent(.created, flag: flag)
        
        return flag
    }
    
    /// Update a feature flag
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag
    ///   - dto: The DTO with updated feature flag data
    ///   - userId: The unique identifier of the user updating the flag
    /// - Returns: The updated feature flag
    func updateFlag(id: UUID, _ dto: FeatureFlagDTOs.UpdateRequest, userId: UUID) async throws -> FeatureFlag {
        let flag = try await getFlag(id: id, userId: userId)
        
        // Check if key is being changed and if new key already exists
        if dto.key != flag.key, try await repository.exists(key: dto.key, userId: userId) {
            throw BanderaError.resourceAlreadyExists("Feature flag with key '\(dto.key)'")
        }
        
        // Update flag
        flag.key = dto.key
        flag.type = dto.type
        flag.defaultValue = dto.defaultValue
        flag.description = dto.description
        
        // Save flag
        try await repository.save(flag)
        
        // Broadcast event
        try await broadcastEvent(.updated, flag: flag)
        
        return flag
    }
    
    /// Delete a feature flag
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag
    ///   - userId: The unique identifier of the user deleting the flag
    func deleteFlag(id: UUID, userId: UUID) async throws {
        let flag = try await getFlag(id: id, userId: userId)
        
        // Delete flag
        try await repository.delete(flag)
        
        // Broadcast event
        try await broadcastDeleteEvent(id: id, userId: userId)
    }
    
    /// Broadcast a feature flag event
    /// - Parameters:
    ///   - event: The event type
    ///   - flag: The feature flag
    func broadcastEvent(_ event: WebSocketDTOs.FeatureFlagEvent, flag: FeatureFlag) async throws {
        try await webSocketService.broadcast(
            event: event.rawValue,
            data: [
                "id": flag.id!.uuidString,
                "key": flag.key,
                "type": flag.type.rawValue,
                "defaultValue": flag.defaultValue,
                "description": flag.description ?? "",
                "userId": flag.$userId.wrappedValue?.uuidString ?? ""
            ]
        )
    }
    
    /// Broadcast a feature flag deletion event
    /// - Parameters:
    ///   - id: The unique identifier of the deleted feature flag
    ///   - userId: The unique identifier of the user who deleted the flag
    func broadcastDeleteEvent(id: UUID, userId: UUID) async throws {
        try await webSocketService.broadcast(
            event: WebSocketDTOs.FeatureFlagEvent.deleted.rawValue,
            data: [
                "id": id.uuidString,
                "userId": userId.uuidString
            ]
        )
    }
} 