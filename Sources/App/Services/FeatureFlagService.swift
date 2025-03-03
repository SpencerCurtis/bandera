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
    ///   - id: The unique identifier of the feature flag
    ///   - userId: The unique identifier of the user making the request
    /// - Returns: The feature flag if found and accessible
    /// - Throws: BanderaError if the flag is not found or not accessible
    func getFlag(id: UUID, userId: UUID) async throws -> FeatureFlag {
        return try await ErrorHandling.withErrorHandling {
            guard let flag = try await repository.get(id: id) else {
                throw ErrorHandling.handleNotFound(id: id, resourceName: "Feature flag")
            }
            
            // Check if flag belongs to this user
            if flag.$userId.wrappedValue != userId {
                throw ErrorHandling.handleAccessDenied(id: id, resourceName: "Feature flag")
            }
            
            return flag
        }
    }
    
    /// Get all feature flags for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: All feature flags for the user
    /// - Throws: BanderaError if the operation fails
    func getAllFlags(userId: UUID) async throws -> [FeatureFlag] {
        return try await ErrorHandling.withErrorHandling {
            try await repository.getAllForUser(userId: userId)
        }
    }
    
    /// Get all feature flags with their overrides for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: A container with all feature flags and their overrides for the user
    /// - Throws: BanderaError if the operation fails
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagDTOs.FlagsContainer {
        return try await ErrorHandling.withErrorHandling {
            try await repository.getFlagsWithOverrides(userId: userId)
        }
    }
    
    /// Create a new feature flag
    /// - Parameters:
    ///   - dto: The DTO containing feature flag data
    ///   - userId: The unique identifier of the user creating the flag
    /// - Returns: The created feature flag
    /// - Throws: BanderaError if the flag cannot be created
    func createFlag(_ dto: FeatureFlagDTOs.CreateRequest, userId: UUID) async throws -> FeatureFlag {
        return try await ErrorHandling.withErrorHandling {
            // Check if a flag with this key already exists for this user
            let exists = try await repository.exists(key: dto.key, userId: userId)
            if exists {
                throw ErrorHandling.handleResourceExists(key: dto.key, resourceName: "Feature flag")
            }
            
            // Create the flag
            let flag = FeatureFlag.create(from: dto, userId: userId)
            
            // Save the flag
            try await repository.save(flag)
            
            // Broadcast the event
            await webSocketService.broadcastFlagCreated(flag, userId: userId.uuidString)
            
            return flag
        }
    }
    
    /// Update an existing feature flag
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag to update
    ///   - dto: The DTO containing updated feature flag data
    ///   - userId: The unique identifier of the user updating the flag
    /// - Returns: The updated feature flag
    /// - Throws: BanderaError if the flag cannot be updated
    func updateFlag(id: UUID, _ dto: FeatureFlagDTOs.UpdateRequest, userId: UUID) async throws -> FeatureFlag {
        return try await ErrorHandling.withErrorHandling {
            // Get the flag
            guard let flag = try await repository.get(id: id) else {
                throw ErrorHandling.handleNotFound(id: id, resourceName: "Feature flag")
            }
            
            // Check if flag belongs to this user
            if flag.$userId.wrappedValue != userId {
                throw ErrorHandling.handleAccessDenied(id: id, resourceName: "Feature flag")
            }
            
            // Check if the key is being changed and if a flag with the new key already exists
            if flag.key != dto.key {
                let exists = try await repository.exists(key: dto.key, userId: userId)
                if exists {
                    throw ErrorHandling.handleResourceExists(key: dto.key, resourceName: "Feature flag")
                }
            }
            
            // Update the flag
            flag.update(from: dto)
            
            // Save the flag
            try await repository.save(flag)
            
            // Broadcast the event
            await webSocketService.broadcastFlagUpdated(flag, userId: userId.uuidString)
            
            return flag
        }
    }
    
    /// Delete a feature flag
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag to delete
    ///   - userId: The unique identifier of the user deleting the flag
    /// - Throws: BanderaError if the flag cannot be deleted
    func deleteFlag(id: UUID, userId: UUID) async throws {
        try await ErrorHandling.withErrorHandling {
            // Get the flag
            guard let flag = try await repository.get(id: id) else {
                throw ErrorHandling.handleNotFound(id: id, resourceName: "Feature flag")
            }
            
            // Check if flag belongs to this user
            if flag.$userId.wrappedValue != userId {
                throw ErrorHandling.handleAccessDenied(id: id, resourceName: "Feature flag")
            }
            
            // Delete the flag
            try await repository.delete(flag)
            
            // Broadcast the event
            await webSocketService.broadcastFlagDeleted(id, userId: userId.uuidString)
        }
    }
    
    /// Broadcast a feature flag event
    /// - Parameters:
    ///   - event: The event type
    ///   - flag: The feature flag
    func broadcastEvent(_ event: WebSocketDTOs.FeatureFlagEvent, flag: FeatureFlag) async throws {
        // Extract the event type from the event
        let eventTypeString = event.eventType
        
        // Determine the event type and broadcast accordingly
        if eventTypeString == "feature_flag.created" {
            await webSocketService.broadcastFlagCreated(flag, userId: flag.userId?.uuidString ?? "")
        } else if eventTypeString == "feature_flag.updated" {
            await webSocketService.broadcastFlagUpdated(flag, userId: flag.userId?.uuidString ?? "")
        }
    }
    
    /// Broadcast a feature flag deletion event
    /// - Parameters:
    ///   - id: The unique identifier of the deleted feature flag
    ///   - userId: The unique identifier of the user who deleted the flag
    func broadcastDeleteEvent(id: UUID, userId: UUID) async throws {
        await webSocketService.broadcastFlagDeleted(id, userId: userId.uuidString)
    }
} 