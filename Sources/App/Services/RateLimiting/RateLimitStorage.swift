@preconcurrency
import Vapor
@preconcurrency
import Redis
import NIOCore

/// Protocol for rate limit storage backends
protocol RateLimitStorage: Sendable {
    /// Increment the counter for a key and return the current count and time remaining
    /// - Parameters:
    ///   - key: The rate limit key
    ///   - window: The time window in seconds
    /// - Returns: A tuple containing the current count and time remaining in seconds
    func increment(key: String, window: Int64) async throws -> (count: Int, timeRemaining: Int64)
}

/// In-memory implementation of rate limit storage
actor InMemoryRateLimitStorage: RateLimitStorage {
    /// Entry in the rate limit storage
    private struct Entry: Sendable {
        let count: Int
        let expiry: Date
    }
    
    /// The stored entries
    private var entries: [String: Entry] = [:]
    
    /// Clean up expired entries
    private func cleanup() {
        let now = Date()
        entries = entries.filter { $0.value.expiry > now }
    }
    
    init() {
        // Start periodic cleanup
        Task {
            while !Task.isCancelled {
                await cleanup()
                try? await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000)) // 30 seconds
            }
        }
    }
    
    func increment(key: String, window: Int64) async throws -> (count: Int, timeRemaining: Int64) {
        let now = Date()
        
        if let entry = entries[key], entry.expiry > now {
            // Key exists and hasn't expired
            let newEntry = Entry(count: entry.count + 1, expiry: entry.expiry)
            entries[key] = newEntry
            let remaining = Int64(entry.expiry.timeIntervalSince(now))
            return (count: newEntry.count, timeRemaining: remaining)
        } else {
            // Key doesn't exist or has expired
            let expiry = now.addingTimeInterval(TimeInterval(window))
            let newEntry = Entry(count: 1, expiry: expiry)
            entries[key] = newEntry
            return (count: 1, timeRemaining: window)
        }
    }
}

/// Redis implementation of rate limit storage
@preconcurrency
actor RedisRateLimitStorage: RateLimitStorage {
    private let app: Application
    
    init(app: Application) {
        self.app = app
    }
    
    func increment(key: String, window: Int64) async throws -> (count: Int, timeRemaining: Int64) {
        // Get Redis client for this event loop
        let redis = app.redis
        let redisKey = RedisKey(key)
        
        // Increment the counter
        let count = try await redis.increment(redisKey).get()
        
        // If this is the first request for this key, set the expiration
        if count == 1 {
            _ = try await redis.expire(redisKey, after: TimeAmount.seconds(Int64(window))).get()
            return (count: Int(count), timeRemaining: window)
        }
        
        // Get the TTL
        let ttl = try await redis.ttl(redisKey).get()
        
        // Convert TTL to seconds
        let remaining: Int64
        switch ttl {
        case .keyDoesNotExist:
            remaining = window
        case .unlimited:
            remaining = window
        case .limited(let duration):
            remaining = Int64(duration.timeAmount.nanoseconds / 1_000_000_000)
        }
        
        return (count: Int(count), timeRemaining: max(0, remaining))
    }
}

/// Factory for creating rate limit storage
struct RateLimitStorageFactory {
    /// Create appropriate storage based on application configuration
    static func create(app: Application) -> RateLimitStorage {
        // If Redis is not configured, use in-memory storage
        guard app.redis.configuration != nil else {
            return InMemoryRateLimitStorage()
        }
        
        // We'll use Redis storage, but if it fails to connect later, it will
        // throw errors that can be handled by the rate limit middleware
        return RedisRateLimitStorage(app: app)
    }
} 