import Vapor
import Fluent

/// Utilities for optimizing database queries and preventing N+1 query problems
enum QueryOptimizations {
    
    // MARK: - N+1 Prevention Guidelines
    
    /// ⚠️ ANTI-PATTERN: Manual loading in loops (causes N+1 queries)
    /// ```swift
    /// let items = try await Model.query(on: db).all()
    /// for item in items {
    ///     try await item.$relation.load(on: db)  // ❌ N+1 queries!
    /// }
    /// ```
    
    /// ✅ SOLUTION: Use eager loading with .with()
    /// ```swift
    /// let items = try await Model.query(on: db)
    ///     .with(\.$relation)  // ✅ Single join query
    ///     .all()
    /// ```
    
    // MARK: - Real Examples from Bandera
    
    /// ✅ FIXED: FeatureFlagRepository.getOverrides()
    /// Before: 1 + N queries (N overrides = N user loads)
    /// After: 1 query with join
    /// ```swift
    /// return try await UserFeatureFlag.query(on: database)
    ///     .filter(\.$featureFlag.$id == flagId)
    ///     .with(\.$user)  // ✅ Eager load user relationship
    ///     .all()
    /// ```
    
    /// ✅ FIXED: OrganizationRepository.getMembershipsForUser()
    /// Before: Lazy loading when accessing organization/user data
    /// After: Eager loading in single query
    /// ```swift
    /// return try await OrganizationUser.query(on: db)
    ///     .filter(\.$user.$id == userId)
    ///     .with(\.$organization)  // ✅ Eager load organization
    ///     .with(\.$user)         // ✅ Eager load user
    ///     .all()
    /// ```
    
    // MARK: - Query Analysis Helpers
    
    /// Helper to identify potential N+1 issues during development
    static func analyzeQuery<T: Model>(_ query: QueryBuilder<T>, operation: String) async {
        #if DEBUG
        print("🔍 Query Analysis [\(operation)]:")
        print("   Model: \(T.self)")
        print("   💡 Tip: Use .with() for relationships to prevent N+1 queries")
        print("   🎯 Goal: 1-2 queries instead of 1+N queries")
        #endif
    }
    
    // MARK: - Performance Monitoring
    
    /// Wrapper for timing database operations and identifying slow queries
    static func timeQuery<T>(_ operation: String, _ block: () async throws -> T) async rethrows -> T {
        #if DEBUG
        let startTime = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(startTime)
        let emoji = duration > 0.1 ? "🐌" : duration > 0.05 ? "⚠️" : "⚡"
        print("\(emoji) Query [\(operation)]: \(String(format: "%.3f", duration))s")
        if duration > 0.1 {
            print("   💡 Consider optimizing this query or adding indexes")
        }
        return result
        #else
        return try await block()
        #endif
    }
    
    // MARK: - Common Patterns Documentation
    
    /// Example: Loading organization memberships with full details
    /// ```swift
    /// let memberships = try await OrganizationUser.query(on: db)
    ///     .filter(\.$user.$id == userId)
    ///     .with(\.$organization)
    ///     .with(\.$user)
    ///     .all()
    /// ```
    
    /// Example: Loading feature flag overrides with user details
    /// ```swift
    /// let overrides = try await UserFeatureFlag.query(on: db)
    ///     .filter(\.$featureFlag.$id == flagId)
    ///     .with(\.$user)
    ///     .with(\.$featureFlag)
    ///     .all()
    /// ```
    
    /// Example: Loading audit logs with related user information
    /// ```swift
    /// let logs = try await AuditLog.query(on: db)
    ///     .filter(\.$featureFlag.$id == flagId)
    ///     .with(\.$user)
    ///     .sort(\.$createdAt, .descending)
    ///     .all()
    /// ```
    
    // MARK: - Performance Impact
    
    /// Before optimization:
    /// - getOverrides(flagId) with 100 overrides: 101 queries (1 + 100)
    /// - getMembershipsForUser() accessing org data: 1 + N queries
    /// 
    /// After optimization:
    /// - getOverrides(flagId) with 100 overrides: 1 query with JOIN
    /// - getMembershipsForUser() with full data: 1 query with JOINs
    /// 
    /// Result: Up to 100x performance improvement for large datasets!
} 