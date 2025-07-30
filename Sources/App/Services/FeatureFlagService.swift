import Vapor
import Fluent

/// Service for feature flag business logic.
///
/// This service implements the business logic for feature flag operations,
/// including creating, updating, deleting, and retrieving feature flags.
/// It uses a repository for data access, a cache service for performance,
/// and a WebSocket service for broadcasting real-time updates.
struct FeatureFlagService: FeatureFlagServiceProtocol {
    /// The repository for feature flag data access
    let repository: FeatureFlagRepositoryProtocol
    
    /// The WebSocket service for broadcasting events
    let webSocketService: WebSocketServiceProtocol
    
    /// The cache service for performance optimization
    let cacheService: CacheServiceProtocol?
    
    /// Initialize a new feature flag service
    /// - Parameters:
    ///   - repository: The repository for feature flag data access
    ///   - webSocketService: The WebSocket service for broadcasting events
    ///   - cacheService: The cache service for performance optimization (optional)
    init(repository: FeatureFlagRepositoryProtocol, webSocketService: WebSocketServiceProtocol, cacheService: CacheServiceProtocol? = nil) {
        self.repository = repository
        self.webSocketService = webSocketService
        self.cacheService = cacheService
    }
    
    /// Get a feature flag by ID
    /// - Parameters:
    ///   - id: The ID of the feature flag
    ///   - userId: The ID of the user requesting the flag
    /// - Returns: The feature flag
    /// - Throws: ResourceError if the flag is not found or not accessible
    func getFlag(id: UUID, userId: UUID) async throws -> FeatureFlag {
        return try await withErrorHandling {
            // Try cache first
            if let cacheService = cacheService,
               let cachedFlag = try await cacheService.getFlag(id: id) {
                // Still need to verify access permissions
                if await hasAccessToFlag(flag: cachedFlag, userId: userId) {
                    return cachedFlag
                }
            }
            
            // Cache miss or access verification failed, get from repository
            guard let flag = try await repository.get(id: id) else {
                throw ResourceError.notFound("Feature flag with ID \(id)")
            }
            
            // Verify access permissions
            try await verifyFlagAccess(flag: flag, userId: userId)
            
            // Cache the flag for future requests
            try await cacheService?.setFlag(flag, expiration: 300)
            
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
            // Try cache first
            if let cacheService = cacheService,
               let cachedContainer = try await cacheService.getFlagsWithOverrides(userId: userId) {
                return cachedContainer
            }
            
            // Cache miss, get from repository
            let container = try await repository.getFlagsWithOverrides(userId: userId)
            
            // Cache the result with shorter expiration (flag overrides change more frequently)
            try await cacheService?.setFlagsWithOverrides(userId: userId, container: container, expiration: 120)
            
            return container
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
            // Check if a flag with this key already exists
            if let organizationId = dto.organizationId {
                // Check if the flag exists in the organization
                let orgFlags = try await repository.getAllForOrganization(organizationId: organizationId)
                if orgFlags.contains(where: { $0.key == dto.key }) {
                    throw ResourceError.alreadyExists("Feature flag with key '\(dto.key)' already exists in this organization")
                }
            } else if try await repository.exists(key: dto.key, userId: userId) {
                // Check if the flag exists for this user
                throw ResourceError.alreadyExists("Feature flag with key '\(dto.key)'")
            }
            
            // Create the flag
            let flag = FeatureFlag.create(from: dto, userId: userId, organizationId: dto.organizationId)
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
            
            // Invalidate relevant caches
            try await cacheService?.invalidateUser(userId: userId)
            if let organizationId = dto.organizationId {
                try await cacheService?.invalidateOrganization(organizationId: organizationId)
            }
            
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
            
            // Invalidate caches for this flag
            try await cacheService?.invalidateFlag(id: id)
            
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
            
            // Invalidate caches for this flag
            try await cacheService?.invalidateFlag(id: id)
            
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
            
            // Get user's organizations (for import functionality)
            let organizations = try await OrganizationUser.query(on: repository.database)
                .filter(\.$user.$id == userId)
                .with(\.$organization)
                .all()
                .map { 
                    OrganizationWithRoleDTO(
                        organization: $0.organization,
                        role: $0.role
                    )
                }
            
            // Convert to DTO
            return FeatureFlagDetailDTO(
                id: flag.id!,
                key: flag.key,
                type: flag.type,
                defaultValue: flag.defaultValue,
                description: flag.description,
                isEnabled: isEnabled,
                createdAt: flag.createdAt,
                updatedAt: flag.updatedAt,
                organizationId: flag.organizationId,
                userOverrides: overrides.map { $0.toDTO() },
                auditLogs: auditLogs.map { $0.toDTO() },
                organizations: organizations
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
            
            // Invalidate caches for this flag
            try await cacheService?.invalidateFlag(id: id)
            
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
            
            // Check if an override already exists for this user/flag combination
            let existingOverrides = try await UserFeatureFlag.query(on: repository.database)
                .filter(\.$featureFlag.$id == flagId)
                .filter(\.$user.$id == userId)
                .all()
                
            // Delete existing overrides to avoid unique constraint violations
            for existing in existingOverrides {
                try await existing.delete(on: repository.database)
            }
            
            // Create a new override
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
    
    /// Import a feature flag to an organization
    /// - Parameters:
    ///   - flagId: The unique identifier of the flag to import
    ///   - organizationId: The organization to import the flag to
    ///   - userId: The user performing the import
    /// - Returns: The imported feature flag
    func importFlagToOrganization(flagId: UUID, organizationId: UUID, userId: UUID) async throws -> FeatureFlag {
        return try await withErrorHandling {
            // Get the original flag
            guard let originalFlag = try await repository.get(id: flagId) else {
                throw ResourceError.notFound("Feature flag with ID \(flagId)")
            }
            
            // Check if the user has access to this flag
            if originalFlag.userId != userId {
                throw AuthenticationError.insufficientPermissions
            }
            
            // Check if the user is an admin of the target organization
            let db = repository.database
            let isAdmin = try await OrganizationUser.query(on: db)
                .filter(\.$organization.$id == organizationId)
                .filter(\.$user.$id == userId)
                .filter(\.$role == .admin)
                .first() != nil
                
            if !isAdmin {
                throw AuthenticationError.notAuthorized(reason: "You must be an admin of the organization to import flags")
            }
            
            // Check if a flag with the same key already exists in the organization
            let exists = try await FeatureFlag.query(on: db)
                .filter(\.$key == originalFlag.key)
                .filter(\.$organizationId == organizationId)
                .first() != nil
                
            if exists {
                throw ValidationError.failed("A flag with the key '\(originalFlag.key)' already exists in this organization")
            }
            
            // Create a new flag for the organization
            let newFlag = FeatureFlag(
                key: originalFlag.key,
                type: originalFlag.type,
                defaultValue: originalFlag.defaultValue,
                description: originalFlag.description,
                userId: userId,  // Track who imported it
                organizationId: organizationId
            )
            
            try await repository.save(newFlag)
            
            // Create initial flag status (disabled by default)
            try await repository.setEnabled(id: newFlag.id!, enabled: false)
            
            // Delete the original flag
            try await repository.delete(originalFlag)
            
            // Create audit log
            try await repository.createAuditLog(
                type: "imported",
                message: "Flag imported from personal flag (ID: \(originalFlag.id!)) and original deleted",
                flagId: newFlag.id!,
                userId: userId
            )
            
            return newFlag
        }
    }
    
    /// Export a feature flag from an organization to a user's personal flags
    /// - Parameters:
    ///   - flagId: The unique identifier of the flag to export
    ///   - userId: The user to export the flag to
    /// - Returns: The exported feature flag
    func exportFlagToPersonal(flagId: UUID, userId: UUID) async throws -> FeatureFlag {
        return try await withErrorHandling {
            // Get the original flag
            guard let originalFlag = try await repository.get(id: flagId) else {
                throw ResourceError.notFound("Feature flag with ID \(flagId)")
            }
            
            // Check if the flag belongs to an organization
            guard let organizationId = originalFlag.organizationId else {
                throw ValidationError.failed("This flag is not an organization flag")
            }
            
            // Check if the user is a member of the organization
            let db = repository.database
            let isMember = try await OrganizationUser.query(on: db)
                .filter(\.$organization.$id == organizationId)
                .filter(\.$user.$id == userId)
                .first() != nil
                
            if !isMember {
                throw AuthenticationError.notAuthorized(reason: "You must be a member of the organization to export flags")
            }
            
            // Check if a flag with the same key already exists for this user
            let exists = try await FeatureFlag.query(on: db)
                .filter(\.$key == originalFlag.key)
                .filter(\.$userId == userId)
                .filter(\.$organizationId == nil)  // Personal flags have no organization
                .first() != nil
                
            if exists {
                throw ValidationError.failed("A personal flag with the key '\(originalFlag.key)' already exists")
            }
            
            // Create a new personal flag
            let newFlag = FeatureFlag(
                key: originalFlag.key,
                type: originalFlag.type,
                defaultValue: originalFlag.defaultValue,
                description: originalFlag.description,
                userId: userId,
                organizationId: nil  // No organization = personal flag
            )
            
            try await repository.save(newFlag)
            
            // Create initial flag status (disabled by default)
            try await repository.setEnabled(id: newFlag.id!, enabled: false)
            
            // Delete the original flag
            try await repository.delete(originalFlag)
            
            // Create audit log
            try await repository.createAuditLog(
                type: "exported",
                message: "Flag exported from organization (ID: \(organizationId)) and original deleted",
                flagId: newFlag.id!,
                userId: userId
            )
            
            return newFlag
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Verify that a user has access to a feature flag
    /// - Parameters:
    ///   - flag: The feature flag to verify access for
    ///   - userId: The user requesting access
    /// - Throws: AuthenticationError.insufficientPermissions if access is denied
    private func verifyFlagAccess(flag: FeatureFlag, userId: UUID) async throws {
        // If this is a personal flag, check if it belongs to this user
        if flag.organizationId == nil {
            if flag.$userId.wrappedValue != userId {
                throw AuthenticationError.insufficientPermissions
            }
        } else {
            // This is an organization flag, check if user is a member of the organization
            let isMember = try await OrganizationUser.query(on: repository.database)
                .filter(\.$organization.$id == flag.organizationId!)
                .filter(\.$user.$id == userId)
                .first() != nil
                
            if !isMember {
                throw AuthenticationError.insufficientPermissions
            }
        }
    }
    
    /// Check if a user has access to a feature flag (non-throwing version for cached flags)
    /// - Parameters:
    ///   - flag: The feature flag to check access for
    ///   - userId: The user requesting access
    /// - Returns: true if access is allowed, false otherwise
    private func hasAccessToFlag(flag: FeatureFlag, userId: UUID) async -> Bool {
        do {
            try await verifyFlagAccess(flag: flag, userId: userId)
            return true
        } catch {
            return false
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