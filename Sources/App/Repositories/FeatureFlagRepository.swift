import Vapor
import Fluent

/// Repository for feature flag data access
struct FeatureFlagRepository: FeatureFlagRepositoryProtocol {
    /// The database to use for queries
    let database: Database
    
    /// Initialize a new feature flag repository
    /// - Parameter database: The database to use for queries
    init(database: Database) {
        self.database = database
    }
    
    /// Get a feature flag by ID
    /// - Parameters:
    ///   - id: The unique identifier of the feature flag
    /// - Returns: The feature flag if found, nil otherwise
    func get(id: UUID) async throws -> FeatureFlag? {
        try await FeatureFlag.find(id, on: database)
    }
    
    /// Get all feature flags
    /// - Returns: All feature flags
    func all() async throws -> [FeatureFlag] {
        try await FeatureFlag.query(on: database).all()
    }
    
    /// Get all feature flags for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: All feature flags for the user
    func getAllForUser(userId: UUID) async throws -> [FeatureFlag] {
        try await FeatureFlag.query(on: database)
            .filter(\FeatureFlag.$userId, .equal, userId)
            .all()
    }
    
    /// Get all feature flags with their overrides for a user
    /// - Parameter userId: The unique identifier of the user
    /// - Returns: A container with all feature flags and their overrides for the user
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagDTOs.FlagsContainer {
        // Get all feature flags for this user
        let flags = try await FeatureFlag.query(on: database)
            .filter(\FeatureFlag.$userId, .equal, UUID(uuidString: userId))
            .all()
        
        // Get user overrides
        let overrides = try await UserFeatureFlag.query(on: database)
            .filter(\UserFeatureFlag.$userId, .equal, userId)
            .with(\.$featureFlag)
            .all()
        
        // Create response dictionary
        var response: [String: FeatureFlagDTOs.Response] = [:]
        
        for flag in flags {
            let override = overrides.first { $0.$featureFlag.id == flag.id }
            response[flag.key] = .init(
                flag: flag,
                value: override?.value,
                isOverridden: override != nil
            )
        }
        
        return FeatureFlagDTOs.FlagsContainer(flags: response)
    }
    
    /// Check if a feature flag with the given key exists for a user
    /// - Parameters:
    ///   - key: The key of the feature flag
    ///   - userId: The unique identifier of the user
    /// - Returns: Whether a feature flag with the given key exists for the user
    func exists(key: String, userId: UUID) async throws -> Bool {
        try await FeatureFlag.query(on: database)
            .filter(\FeatureFlag.$key, .equal, key)
            .filter(\FeatureFlag.$userId, .equal, userId)
            .first() != nil
    }
    
    /// Save a feature flag
    /// - Parameter flag: The feature flag to save
    func save(_ flag: FeatureFlag) async throws {
        try await flag.save(on: database)
    }
    
    /// Delete a feature flag
    /// - Parameter flag: The feature flag to delete
    func delete(_ flag: FeatureFlag) async throws {
        try await flag.delete(on: database)
    }
} 