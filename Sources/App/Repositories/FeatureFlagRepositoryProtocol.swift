import Vapor
import Fluent

/// Protocol defining the interface for feature flag repository operations
protocol FeatureFlagRepositoryProtocol {
    /// Get a feature flag by ID
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag
    /// - Returns: The feature flag if found, nil otherwise
    func get(id: UUID) async throws -> FeatureFlag?
    
    /// Get all feature flags
    /// - Returns: All feature flags
    func all() async throws -> [FeatureFlag]
    
    /// Get all feature flags for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: All feature flags for the user
    func getAllForUser(userId: UUID) async throws -> [FeatureFlag]
    
    /// Get all feature flags with their overrides for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: A container with all feature flags and their overrides for the user
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagDTOs.FlagsContainer
    
    /// Check if a feature flag with the given key exists for a user
    /// - Parameters:
    ///   - key: The key of the feature flag
    ///   - userId: The unique identifier of the user
    /// - Returns: True if a feature flag with the given key exists for the user, false otherwise
    func exists(key: String, userId: UUID) async throws -> Bool
    
    /// Save a feature flag
    /// - Parameter flag: The feature flag to save
    func save(_ flag: FeatureFlag) async throws
    
    /// Delete a feature flag
    /// - Parameter flag: The feature flag to delete
    func delete(_ flag: FeatureFlag) async throws
} 