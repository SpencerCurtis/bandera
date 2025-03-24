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
                throw AuthenticationError.insufficientPermissions
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
            
            // Create initial flag status (disabled by default)
            try await repository.setEnabled(id: flag.id!, enabled: false)
            
            // Create audit log
            try await repository.createAuditLog(
                type: "created",
                message: "Flag created",
                flagId: flag.id!,
                userId: userId
            )
            
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
    
    /// Get detailed information about a feature flag
    /// - Parameters:
    ///   - id: The ID of the feature flag
    ///   - userId: The ID of the user requesting the details
    /// - Returns: The feature flag details DTO
    /// - Throws: ResourceError if the flag is not found or not accessible
    func getFlagDetails(id: UUID, userId: UUID) async throws -> FeatureFlagDetailDTO {
        return try await withErrorHandling {
            // Get the flag
            let flag = try await getFlag(id: id, userId: userId)
            
            // Get user overrides
            let overrides = try await repository.getOverrides(flagId: id)
            
            // Get audit logs
            let auditLogs = try await repository.getAuditLogs(flagId: id)
            
            // Get enabled status
            let isEnabled = try await repository.isEnabled(id: id)
            
            // Convert to DTO
            return flag.toDetailDTO(
                isEnabled: isEnabled,
                userOverrides: overrides,
                auditLogs: auditLogs
            )
        }
    }
    
    /// Toggle a feature flag on/off
    /// - Parameters:
    ///   - id: The ID of the feature flag
    ///   - userId: The ID of the user toggling the flag
    /// - Returns: The updated feature flag
    /// - Throws: ResourceError if the flag cannot be toggled
    func toggleFlag(id: UUID, userId: UUID) async throws -> FeatureFlag {
        return try await withErrorHandling {
            // Get the flag
            let flag = try await getFlag(id: id, userId: userId)
            
            // Get current status
            let isEnabled = try await repository.isEnabled(id: id)
            
            // Toggle the flag
            try await repository.setEnabled(id: id, enabled: !isEnabled)
            
            // Create audit log
            try await repository.createAuditLog(
                type: isEnabled ? "disabled" : "enabled",
                message: "Flag \(isEnabled ? "disabled" : "enabled")",
                flagId: id,
                userId: userId
            )
            
            // Broadcast the event
            try await broadcastEvent(FeatureFlagEventType.updated, flag: flag)
            
            return flag
        }
    }
    
    /// Create a feature flag override for a user
    /// - Parameters:
    ///   - flagId: The unique identifier of the feature flag
    ///   - userId: The unique identifier of the user to create the override for
    ///   - value: The override value
    ///   - createdBy: The unique identifier of the user creating the override
    func createOverride(flagId: UUID, userId: UUID, value: String, createdBy: UUID) async throws {
        try await withErrorHandling {
            // Verify the flag exists and the creator has access to it
            let flag = try await getFlag(id: flagId, userId: createdBy)
            
            // Create or update the override
            let override = UserFeatureFlag(
                featureFlagId: flagId,
                userId: userId,
                value: value
            )
            
            // Save the override using the repository
            try await repository.saveOverride(override)
            
            // Try to find the user to get their email for the audit log
            let auditMessage: String
            if let targetUser = try? await repository.database.query(User.self)
                                        .filter(\User.$id == userId)
                                        .first() {
                // If we found the user, include their email in the message
                auditMessage = "Created override for user \(targetUser.email)"
            } else {
                // If we couldn't find the user, just use the UUID
                auditMessage = "Created override for user \(userId)"
            }
            
            // Create audit log with user-friendly message
            try await repository.createAuditLog(
                type: "override_created",
                message: auditMessage,
                flagId: flagId,
                userId: createdBy
            )
            
            // Broadcast the event
            try await broadcastEvent(FeatureFlagEventType.overrideCreated, flag: flag)
        }
    }
    
    /// Delete a feature flag override
    /// - Parameters:
    ///   - id: The unique identifier of the override
    ///   - userId: The unique identifier of the user deleting the override
    func deleteOverride(id: UUID, userId: UUID) async throws {
        try await withErrorHandling {
            // Find the override using the repository
            guard let override = try await repository.findOverride(id: id) else {
                throw ResourceError.notFound("Override with ID \(id)")
            }
            
            // Get the flag ID (without try since this property access is not throwing)
            let flagId = override.$featureFlag.id
            
            // Verify the user has access to the flag
            _ = try await getFlag(id: flagId, userId: userId)
            
            // Delete the override
            try await repository.deleteOverride(override)
            
            // Create audit log
            try await repository.createAuditLog(
                type: "override_deleted",
                message: "Override deleted",
                flagId: flagId,
                userId: userId
            )
            
            // Get the flag
            guard let flag = try await repository.get(id: flagId) else {
                return
            }
            
            // Broadcast the event
            try await broadcastEvent(FeatureFlagEventType.overrideDeleted, flag: flag)
        }
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