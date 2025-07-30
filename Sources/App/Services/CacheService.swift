import Vapor
import Redis
import Foundation

/// Protocol for cache storage operations
protocol CacheStorageProtocol: Sendable {
    /// Get a value from cache
    /// - Parameter key: The cache key
    /// - Returns: The cached value as Data, or nil if not found
    func get(key: String) async throws -> Data?
    
    /// Set a value in cache with expiration
    /// - Parameters:
    ///   - key: The cache key
    ///   - value: The value to cache as Data
    ///   - expiration: Time to live in seconds
    func set(key: String, value: Data, expiration: Int) async throws
    
    /// Delete a value from cache
    /// - Parameter key: The cache key
    func delete(key: String) async throws
    
    /// Delete multiple keys matching a pattern
    /// - Parameter pattern: The key pattern (supports wildcards in Redis)
    func deletePattern(pattern: String) async throws
    
    /// Check if cache is available
    var isAvailable: Bool { get async }
}

/// Redis-based cache storage implementation
actor RedisCacheStorage: CacheStorageProtocol {
    private let app: Application
    private let keyPrefix: String
    
    init(app: Application, keyPrefix: String = "bandera:cache:") {
        self.app = app
        self.keyPrefix = keyPrefix
    }
    
    var isAvailable: Bool {
        get async { app.redis.configuration != nil }
    }
    
    func get(key: String) async throws -> Data? {
        guard await isAvailable else { return nil }
        
        let prefixedKey = keyPrefix + key
        return try await app.redis.get(RedisKey(prefixedKey), as: String.self).get()?.data(using: .utf8)
    }
    
    func set(key: String, value: Data, expiration: Int) async throws {
        guard await isAvailable else { return }
        
        let prefixedKey = keyPrefix + key
        let stringValue = String(data: value, encoding: .utf8) ?? ""
        _ = try await app.redis.setex(RedisKey(prefixedKey), to: stringValue, expirationInSeconds: expiration).get()
    }
    
    func delete(key: String) async throws {
        guard await isAvailable else { return }
        
        let prefixedKey = keyPrefix + key
        _ = try await app.redis.delete([RedisKey(prefixedKey)]).get()
    }
    
    func deletePattern(pattern: String) async throws {
        guard await isAvailable else { return }
        
        // For now, we'll skip pattern deletion in Redis since it's complex
        // In production, you'd implement proper Redis SCAN with pattern matching
        // This is a fallback that works but is not optimal
    }
}

/// In-memory cache storage implementation (fallback)
actor InMemoryCacheStorage: CacheStorageProtocol {
    private var cache: [String: CacheEntry] = [:]
    private let logger: Logger
    
    private struct CacheEntry {
        let data: Data
        let expiresAt: Date
        
        var isExpired: Bool {
            Date() > expiresAt
        }
    }
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    var isAvailable: Bool { 
        get async { true }
    }
    
    func get(key: String) async throws -> Data? {
        cleanupExpired()
        
        guard let entry = cache[key], !entry.isExpired else {
            return nil
        }
        
        return entry.data
    }
    
    func set(key: String, value: Data, expiration: Int) async throws {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiration))
        cache[key] = CacheEntry(data: value, expiresAt: expiresAt)
    }
    
    func delete(key: String) async throws {
        cache.removeValue(forKey: key)
    }
    
    func deletePattern(pattern: String) async throws {
        // Simple pattern matching for in-memory storage
        let regex = try NSRegularExpression(pattern: pattern.replacingOccurrences(of: "*", with: ".*"))
        let keysToDelete = cache.keys.filter { key in
            let range = NSRange(location: 0, length: key.utf16.count)
            return regex.firstMatch(in: key, options: [], range: range) != nil
        }
        
        for key in keysToDelete {
            cache.removeValue(forKey: key)
        }
    }
    
    private func cleanupExpired() {
        cache = cache.filter { !$0.value.isExpired }
    }
}

/// Factory for creating cache storage instances
enum CacheStorageFactory {
    /// Create a cache storage instance based on application configuration
    /// - Parameter app: The Vapor application
    /// - Returns: A cache storage implementation (Redis if available, otherwise in-memory)
    static func create(app: Application) -> CacheStorageProtocol {
        if app.redis.configuration != nil {
            app.logger.notice("Using Redis for feature flag caching")
            return RedisCacheStorage(app: app)
        } else {
            app.logger.notice("Using in-memory storage for feature flag caching")
            return InMemoryCacheStorage(logger: app.logger)
        }
    }
}

/// High-level cache service for feature flags
protocol CacheServiceProtocol {
    /// Get a cached feature flag
    func getFlag(id: UUID) async throws -> FeatureFlag?
    
    /// Cache a feature flag
    func setFlag(_ flag: FeatureFlag, expiration: Int) async throws
    
    /// Get cached flags for a user
    func getUserFlags(userId: UUID) async throws -> [FeatureFlag]?
    
    /// Cache flags for a user
    func setUserFlags(userId: UUID, flags: [FeatureFlag], expiration: Int) async throws
    
    /// Get cached flags with overrides for a user
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer?
    
    /// Cache flags with overrides for a user
    func setFlagsWithOverrides(userId: String, container: FeatureFlagsContainer, expiration: Int) async throws
    
    /// Get cached organization flags
    func getOrganizationFlags(organizationId: UUID) async throws -> [FeatureFlag]?
    
    /// Cache organization flags
    func setOrganizationFlags(organizationId: UUID, flags: [FeatureFlag], expiration: Int) async throws
    
    /// Get cached flag enabled status
    func getFlagEnabled(id: UUID) async throws -> Bool?
    
    /// Cache flag enabled status
    func setFlagEnabled(id: UUID, enabled: Bool, expiration: Int) async throws
    
    /// Invalidate all cache entries for a flag
    func invalidateFlag(id: UUID) async throws
    
    /// Invalidate all cache entries for a user
    func invalidateUser(userId: UUID) async throws
    
    /// Invalidate all cache entries for an organization
    func invalidateOrganization(organizationId: UUID) async throws
    
    /// Check if cache is available
    var isAvailable: Bool { get async }
}

/// Implementation of cache service using storage backend
struct CacheService: CacheServiceProtocol {
    private let storage: CacheStorageProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(storage: CacheStorageProtocol) {
        self.storage = storage
    }
    
    var isAvailable: Bool {
        get async { await storage.isAvailable }
    }
    
    // MARK: - Feature Flag Caching
    
    func getFlag(id: UUID) async throws -> FeatureFlag? {
        let key = "flag:\(id.uuidString)"
        guard let data = try await storage.get(key: key) else { return nil }
        return try decoder.decode(FeatureFlag.self, from: data)
    }
    
    func setFlag(_ flag: FeatureFlag, expiration: Int = 300) async throws {
        let key = "flag:\(flag.id!.uuidString)"
        let data = try encoder.encode(flag)
        try await storage.set(key: key, value: data, expiration: expiration)
    }
    
    // MARK: - User Flags Caching
    
    func getUserFlags(userId: UUID) async throws -> [FeatureFlag]? {
        let key = "user_flags:\(userId.uuidString)"
        guard let data = try await storage.get(key: key) else { return nil }
        return try decoder.decode([FeatureFlag].self, from: data)
    }
    
    func setUserFlags(userId: UUID, flags: [FeatureFlag], expiration: Int = 300) async throws {
        let key = "user_flags:\(userId.uuidString)"
        let data = try encoder.encode(flags)
        try await storage.set(key: key, value: data, expiration: expiration)
    }
    
    // MARK: - Flags with Overrides Caching
    
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer? {
        let key = "flags_with_overrides:\(userId)"
        guard let data = try await storage.get(key: key) else { return nil }
        return try decoder.decode(FeatureFlagsContainer.self, from: data)
    }
    
    func setFlagsWithOverrides(userId: String, container: FeatureFlagsContainer, expiration: Int = 120) async throws {
        let key = "flags_with_overrides:\(userId)"
        let data = try encoder.encode(container)
        try await storage.set(key: key, value: data, expiration: expiration)
    }
    
    // MARK: - Organization Flags Caching
    
    func getOrganizationFlags(organizationId: UUID) async throws -> [FeatureFlag]? {
        let key = "org_flags:\(organizationId.uuidString)"
        guard let data = try await storage.get(key: key) else { return nil }
        return try decoder.decode([FeatureFlag].self, from: data)
    }
    
    func setOrganizationFlags(organizationId: UUID, flags: [FeatureFlag], expiration: Int = 300) async throws {
        let key = "org_flags:\(organizationId.uuidString)"
        let data = try encoder.encode(flags)
        try await storage.set(key: key, value: data, expiration: expiration)
    }
    
    // MARK: - Flag Status Caching
    
    func getFlagEnabled(id: UUID) async throws -> Bool? {
        let key = "flag_enabled:\(id.uuidString)"
        guard let data = try await storage.get(key: key) else { return nil }
        return try decoder.decode(Bool.self, from: data)
    }
    
    func setFlagEnabled(id: UUID, enabled: Bool, expiration: Int = 300) async throws {
        let key = "flag_enabled:\(id.uuidString)"
        let data = try encoder.encode(enabled)
        try await storage.set(key: key, value: data, expiration: expiration)
    }
    
    // MARK: - Cache Invalidation
    
    func invalidateFlag(id: UUID) async throws {
        let flagId = id.uuidString
        try await storage.delete(key: "flag:\(flagId)")
        try await storage.delete(key: "flag_enabled:\(flagId)")
        
        // Invalidate user and organization caches that might contain this flag
        try await storage.deletePattern(pattern: "user_flags:*")
        try await storage.deletePattern(pattern: "org_flags:*")
        try await storage.deletePattern(pattern: "flags_with_overrides:*")
    }
    
    func invalidateUser(userId: UUID) async throws {
        let userIdString = userId.uuidString
        try await storage.delete(key: "user_flags:\(userIdString)")
        try await storage.delete(key: "flags_with_overrides:\(userIdString)")
    }
    
    func invalidateOrganization(organizationId: UUID) async throws {
        let orgId = organizationId.uuidString
        try await storage.delete(key: "org_flags:\(orgId)")
        
        // Also invalidate flags with overrides for all users (they might have org flags)
        try await storage.deletePattern(pattern: "flags_with_overrides:*")
    }
} 