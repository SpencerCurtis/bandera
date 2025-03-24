import Vapor
import Fluent

/// Protocol defining the interface for feature flag repository operations
protocol FeatureFlagRepositoryProtocol {
    /// The database connection to use
    var database: Database { get }
    
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
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer
    
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
    
    /// Get all user overrides for a feature flag
    func getOverrides(flagId: UUID) async throws -> [UserFeatureFlag]
    
    /// Get all audit logs for a feature flag
    func getAuditLogs(flagId: UUID) async throws -> [AuditLog]
    
    /// Check if a feature flag is enabled
    func isEnabled(id: UUID) async throws -> Bool
    
    /// Set the enabled status of a feature flag
    func setEnabled(id: UUID, enabled: Bool) async throws
    
    /// Create an audit log entry for a feature flag
    func createAuditLog(type: String, message: String, flagId: UUID, userId: UUID) async throws
    
    /// Save a UserFeatureFlag
    func saveOverride(_ override: UserFeatureFlag) async throws
    
    /// Find a UserFeatureFlag by ID
    func findOverride(id: UUID) async throws -> UserFeatureFlag?
    
    /// Delete a UserFeatureFlag
    func deleteOverride(_ override: UserFeatureFlag) async throws
} 