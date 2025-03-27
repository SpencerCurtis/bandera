import Vapor

/// Context for the health status view
struct HealthViewContext: Content {
    /// Base context containing common properties
    let base: BaseViewContext
    
    /// Health information
    let environment: String
    let uptime: String
    let databaseConnected: Bool
    let redisConnected: Bool
    let memoryUsage: String
    let lastDeployment: String
    
    /// Initialize with base context and health information
    /// - Parameters:
    ///   - base: The base context
    ///   - environment: The current environment (e.g., development, production)
    ///   - uptime: The system uptime
    ///   - databaseConnected: Whether the database is connected
    ///   - redisConnected: Whether Redis is connected
    ///   - memoryUsage: Current memory usage
    ///   - lastDeployment: When the system was last deployed
    init(
        base: BaseViewContext,
        environment: String,
        uptime: String,
        databaseConnected: Bool,
        redisConnected: Bool,
        memoryUsage: String,
        lastDeployment: String
    ) {
        self.base = base
        self.environment = environment
        self.uptime = uptime
        self.databaseConnected = databaseConnected
        self.redisConnected = redisConnected
        self.memoryUsage = memoryUsage
        self.lastDeployment = lastDeployment
    }
} 