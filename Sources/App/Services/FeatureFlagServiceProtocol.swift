import Vapor
import Fluent

/// Protocol defining the interface for feature flag service operations
protocol FeatureFlagServiceProtocol {
    /// Get a feature flag by ID
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag
    ///   - userId: The unique identifier of the user making the request
    /// - Returns: The feature flag if found and accessible
    func getFlag(id: UUID, userId: UUID) async throws -> FeatureFlag
    
    /// Get all feature flags for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: All feature flags for the user
    func getAllFlags(userId: UUID) async throws -> [FeatureFlag]
    
    /// Get all feature flags with their overrides for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: A container with all feature flags and their overrides for the user
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer
    
    /// Create a new feature flag
    /// - Parameters:
    ///   - dto: The DTO with feature flag data
    ///   - userId: The unique identifier of the user creating the flag
    /// - Returns: The created feature flag
    func createFlag(_ dto: CreateFeatureFlagRequest, userId: UUID) async throws -> FeatureFlag
    
    /// Update a feature flag
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag
    ///   - dto: The DTO with updated feature flag data
    ///   - userId: The unique identifier of the user updating the flag
    /// - Returns: The updated feature flag
    func updateFlag(id: UUID, _ dto: UpdateFeatureFlagRequest, userId: UUID) async throws -> FeatureFlag
    
    /// Delete a feature flag
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag
    ///   - userId: The unique identifier of the user deleting the flag
    func deleteFlag(id: UUID, userId: UUID) async throws
    
    /// Get detailed information about a feature flag
    func getFlagDetails(id: UUID, userId: UUID) async throws -> FeatureFlagDetailDTO
    
    /// Toggle a feature flag on/off
    func toggleFlag(id: UUID, userId: UUID) async throws -> FeatureFlag
    
    /// Broadcast a feature flag event
    /// - Parameters:
    ///   - event: The event type
    ///   - flag: The feature flag
    func broadcastEvent(_ event: FeatureFlagEventType, flag: FeatureFlag) async throws
    
    /// Broadcast a feature flag deletion event
    /// - Parameters:
    ///   - id: The unique identifier of the deleted feature flag
    ///   - userId: The unique identifier of the user who deleted the flag
    func broadcastDeleteEvent(id: UUID, userId: UUID) async throws
    
    /// Create a feature flag override for a user
    /// - Parameters:
    ///   - flagId: The unique identifier of the feature flag
    ///   - userId: The unique identifier of the user to create the override for
    ///   - value: The override value
    ///   - createdBy: The unique identifier of the user creating the override
    func createOverride(flagId: UUID, userId: UUID, value: String, createdBy: UUID) async throws
    
    /// Delete a feature flag override
    /// - Parameters:
    ///   - id: The unique identifier of the override
    ///   - userId: The unique identifier of the user deleting the override
    func deleteOverride(id: UUID, userId: UUID) async throws
} 