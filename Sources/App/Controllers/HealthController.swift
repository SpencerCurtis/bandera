import Vapor
import Foundation

struct HealthController: RouteCollection {
    private let startTime = Date()
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("health", use: healthCheck)
    }
    
    @Sendable
    func healthCheck(req: Request) async throws -> Response {
        // Check if this is an API call or a web request
        if req.headers.accept.first?.mediaType == .json {
            // Return simple JSON response for API calls
            return try await HealthStatus(
                status: "healthy",
                environment: req.application.environment.name,
                uptime: formatUptime(from: startTime),
                databaseConnected: true,
                redisConnected: true,
                memoryUsage: formatMemoryUsage(),
                lastDeployment: formatDate(startTime)
            ).encodeResponse(for: req)
        }
        
        // For web requests, render the health page
        let context = ViewContext(
            title: "System Health",
            isAuthenticated: req.auth.get(UserJWTPayload.self) != nil,
            isAdmin: req.auth.get(UserJWTPayload.self)?.isAdmin ?? false,
            environment: req.application.environment.name,
            uptime: formatUptime(from: startTime),
            databaseConnected: true, // TODO: Implement actual database check
            redisConnected: true,    // TODO: Implement actual Redis check
            memoryUsage: formatMemoryUsage(),
            lastDeployment: formatDate(startTime)
        )
        
        return try await req.view.render("health", context).encodeResponse(for: req)
    }
    
    // MARK: - Helper Functions
    
    private func formatUptime(from startTime: Date) -> String {
        let interval = Date().timeIntervalSince(startTime)
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
        
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        parts.append("\(seconds)s")
        
        return parts.joined(separator: " ")
    }
    
    private func formatMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return String(format: "%.1f MB", usedMB)
        }
        
        return "Unknown"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Response Types

struct HealthStatus: Content {
    let status: String
    let environment: String
    let uptime: String
    let databaseConnected: Bool
    let redisConnected: Bool
    let memoryUsage: String
    let lastDeployment: String
}

// MARK: - View Context Extension

extension ViewContext {
    init(title: String,
         isAuthenticated: Bool,
         isAdmin: Bool,
         environment: String,
         uptime: String,
         databaseConnected: Bool,
         redisConnected: Bool,
         memoryUsage: String,
         lastDeployment: String) {
        self.init(title: title,
                 isAuthenticated: isAuthenticated,
                 isAdmin: isAdmin)
        self.environment = environment
        self.uptime = uptime
        self.databaseConnected = databaseConnected
        self.redisConnected = redisConnected
        self.memoryUsage = memoryUsage
        self.lastDeployment = lastDeployment
    }
} 