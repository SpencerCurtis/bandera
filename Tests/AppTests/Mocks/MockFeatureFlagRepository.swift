@testable import App
import Vapor
import Fluent

final class MockFeatureFlagRepository: FeatureFlagRepositoryProtocol {
    private var flags: [UUID: FeatureFlag] = [:]
    private var userFlags: [String: [UUID: UserFeatureFlag]] = [:]
    
    func get(id: UUID) async throws -> FeatureFlag? {
        return flags[id]
    }
    
    func getByKey(_ key: String) async throws -> FeatureFlag? {
        return flags.values.first { $0.key == key }
    }
    
    func all() async throws -> [FeatureFlag] {
        return Array(flags.values)
    }
    
    func getAllForUser(userId: UUID) async throws -> [FeatureFlag] {
        return flags.values.filter { $0.userId == userId }
    }
    
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer {
        let allFlags = Array(flags.values)
        var result: [String: FeatureFlagResponse] = [:]
        
        for flag in allFlags {
            let override = userFlags[userId]?[flag.id!]
            let isOverridden = override != nil
            let value = override?.value ?? flag.defaultValue
            
            result[flag.key] = FeatureFlagResponse(
                flag: flag,
                value: value,
                isOverridden: isOverridden
            )
        }
        
        return FeatureFlagsContainer(flags: result)
    }
    
    func exists(key: String, userId: UUID) async throws -> Bool {
        return flags.values.contains { $0.key == key && $0.userId == userId }
    }
    
    func save(_ flag: FeatureFlag) async throws {
        if flag.id == nil {
            flag.id = UUID()
        }
        flags[flag.id!] = flag
    }
    
    func delete(_ flag: FeatureFlag) async throws {
        guard let id = flag.id else { return }
        flags.removeValue(forKey: id)
        
        // Also delete any user overrides for this flag
        try await deleteUserOverrides(flagId: id)
    }
    
    func getUserOverride(userId: String, flagId: UUID) async throws -> UserFeatureFlag? {
        return userFlags[userId]?[flagId]
    }
    
    func getUserOverrides(userId: String) async throws -> [UserFeatureFlag] {
        if let userOverrides = userFlags[userId] {
            return Array(userOverrides.values)
        }
        return []
    }
    
    func saveUserOverride(_ override: UserFeatureFlag) async throws {
        if userFlags[override.userId] == nil {
            userFlags[override.userId] = [:]
        }
        userFlags[override.userId]![override.$featureFlag.id] = override
    }
    
    func deleteUserOverride(_ override: UserFeatureFlag) async throws {
        userFlags[override.userId]?.removeValue(forKey: override.$featureFlag.id)
    }
    
    func deleteUserOverrides(flagId: UUID) async throws {
        for userId in userFlags.keys {
            userFlags[userId]?.removeValue(forKey: flagId)
        }
    }
    
    // Testing helpers
    func reset() {
        flags = [:]
        userFlags = [:]
    }
    
    func addTestFlag(key: String, type: FeatureFlagType, defaultValue: String, description: String, userId: UUID = UUID()) -> FeatureFlag {
        let flag = FeatureFlag(
            id: UUID(),
            key: key,
            type: type,
            defaultValue: defaultValue,
            description: description,
            userId: userId
        )
        flags[flag.id!] = flag
        return flag
    }
} 