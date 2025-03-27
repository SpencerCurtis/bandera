import Vapor

/// Context for the health check view
struct HealthCheckViewContext: Content {
    /// Base context
    let base: BaseViewContext
    
    /// System health information
    struct HealthInfo: Content {
        let uptime: String
        let databaseConnected: Bool
        let redisConnected: Bool
        let memoryUsage: String
        let lastDeployment: String
        let environment: String
    }
    
    /// Health information
    let healthInfo: HealthInfo
    
    /// Initialize with health information
    /// - Parameters:
    ///   - base: The base context
    ///   - healthInfo: System health information
    init(
        base: BaseViewContext,
        healthInfo: HealthInfo
    ) {
        self.base = base
        self.healthInfo = healthInfo
    }
} 