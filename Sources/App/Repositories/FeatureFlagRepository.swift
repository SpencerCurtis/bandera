import Vapor
import Fluent

/// Repository for feature flag data access
struct FeatureFlagRepository: FeatureFlagRepositoryProtocol {
    /// The database to use for queries
    let database: Database
    
    init(database: Database) {
        self.database = database
    }
    
    func get(id: UUID) async throws -> FeatureFlag? {
        try await FeatureFlag.find(id, on: database)
    }
    
    func all() async throws -> [FeatureFlag] {
        try await FeatureFlag.query(on: database).all()
    }
    
    func getAllForUser(userId: UUID) async throws -> [FeatureFlag] {
        try await FeatureFlag.query(on: database)
            .filter(\FeatureFlag.$userId, .equal, userId)
            .all()
    }
    
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer {
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
        var response: [String: FeatureFlagResponse] = [:]
        
        for flag in flags {
            let override = overrides.first { $0.$featureFlag.id == flag.id }
            response[flag.key] = .init(
                flag: flag,
                value: override?.value,
                isOverridden: override != nil
            )
        }
        
        return FeatureFlagsContainer(flags: response)
    }
    
    func exists(key: String, userId: UUID) async throws -> Bool {
        try await FeatureFlag.query(on: database)
            .filter(\FeatureFlag.$key, .equal, key)
            .filter(\FeatureFlag.$userId, .equal, userId)
            .first() != nil
    }
    
    func save(_ flag: FeatureFlag) async throws {
        try await flag.save(on: database)
    }
    
    func delete(_ flag: FeatureFlag) async throws {
        try await flag.delete(on: database)
    }
}