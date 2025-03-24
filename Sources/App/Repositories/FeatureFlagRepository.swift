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
        guard let uuid = UUID(uuidString: userId) else {
            throw ValidationError.failed("Invalid user ID")
        }
        
        // First verify the user exists
        guard try await User.find(uuid, on: database) != nil else {
            throw ResourceError.notFound("User with ID \(uuid)")
        }
        
        // Get all feature flags for this user
        let flags = try await FeatureFlag.query(on: database)
            .filter(\FeatureFlag.$userId, .equal, uuid)
            .all()
        
        // Get user overrides, joining with User to ensure we only get overrides for existing users
        let overrides = try await UserFeatureFlag.query(on: database)
            .join(User.self, on: \UserFeatureFlag.$user.$id == \User.$id)
            .filter(\.$user.$id, .equal, uuid)
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
    
    /// Get all user overrides for a feature flag
    func getOverrides(flagId: UUID) async throws -> [UserFeatureFlag] {
        let overrides = try await UserFeatureFlag.query(on: database)
            .filter(\.$featureFlag.$id == flagId)
            .all()
            
        // Load user relationships for each override
        for override in overrides {
            try await override.$user.load(on: database)
        }
        
        return overrides
    }
    
    /// Get all audit logs for a feature flag
    func getAuditLogs(flagId: UUID) async throws -> [AuditLog] {
        try await AuditLog.query(on: database)
            .join(User.self, on: \AuditLog.$user.$id == \User.$id)
            .filter(\.$featureFlag.$id == flagId)
            .with(\.$user)
            .sort(\.$createdAt, .descending)
            .all()
    }
    
    /// Check if a feature flag is enabled
    func isEnabled(id: UUID) async throws -> Bool {
        // Check if the flag exists
        _ = try await get(id: id).map { _ in true } ?? { throw ResourceError.notFound("Feature flag with ID \(id)") }()
        
        // Check the enabled status in the database
        return try await FlagStatus.query(on: database)
            .filter(\.$featureFlag.$id == id)
            .first()
            .map { $0.isEnabled } ?? false
    }
    
    /// Set the enabled status of a feature flag
    func setEnabled(id: UUID, enabled: Bool) async throws {
        // Check if the flag exists
        _ = try await get(id: id).map { _ in true } ?? { throw ResourceError.notFound("Feature flag with ID \(id)") }()
        
        // Update or create the flag status
        if let status = try await FlagStatus.query(on: database)
            .filter(\.$featureFlag.$id == id)
            .first() {
            status.isEnabled = enabled
            try await status.save(on: database)
        } else {
            let status = FlagStatus(featureFlagId: id, isEnabled: enabled)
            try await status.save(on: database)
        }
    }
    
    /// Create an audit log entry for a feature flag
    func createAuditLog(type: String, message: String, flagId: UUID, userId: UUID) async throws {
        let log = AuditLog(
            type: type,
            message: message,
            featureFlagId: flagId,
            userId: userId
        )
        try await log.save(on: database)
    }
    
    /// Save a UserFeatureFlag
    func saveOverride(_ override: UserFeatureFlag) async throws {
        try await override.save(on: database)
    }
    
    /// Find a UserFeatureFlag by ID
    func findOverride(id: UUID) async throws -> UserFeatureFlag? {
        try await UserFeatureFlag.find(id, on: database)
    }
    
    /// Delete a UserFeatureFlag
    func deleteOverride(_ override: UserFeatureFlag) async throws {
        try await override.delete(on: database)
    }
    
    func getAllForOrganization(organizationId: UUID) async throws -> [FeatureFlag] {
        return try await FeatureFlag.query(on: database)
            .filter(\.$organizationId == organizationId)
            .all()
    }
}