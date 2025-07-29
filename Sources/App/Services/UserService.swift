import Vapor
import Fluent

/// Service for user management operations
protocol UserServiceProtocol: Sendable {
    /// Toggle admin status for a user
    /// - Parameters:
    ///   - userId: The ID of the user to toggle
    ///   - requesterId: The ID of the user making the request (must be admin)
    /// - Returns: The updated user
    func toggleAdminStatus(userId: UUID, requesterId: UUID) async throws -> User
    
    /// Update user information
    /// - Parameters:
    ///   - userId: The ID of the user to update
    ///   - updates: The updates to apply
    ///   - requesterId: The ID of the user making the request
    /// - Returns: The updated user
    func updateUser(userId: UUID, updates: UserUpdateRequest, requesterId: UUID) async throws -> User
    
    /// Get health information for admin dashboard
    /// - Returns: Health information
    func getHealthInfo() async -> AdminDashboardViewContext.HealthInfo
}

/// User service implementation
final class UserService: UserServiceProtocol {
    private let userRepository: UserRepositoryProtocol
    
    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }
    
    /// Toggle admin status for a user
    func toggleAdminStatus(userId: UUID, requesterId: UUID) async throws -> User {
        // Verify requester is admin
        guard let requester = try await userRepository.get(id: requesterId) else {
            throw AuthorizationError.notAuthorized(reason: "Requester not found")
        }
        
        guard requester.isAdmin else {
            throw AuthorizationError.notAuthorized(reason: "Only administrators can modify admin status")
        }
        
        // Get the target user
        guard let user = try await userRepository.get(id: userId) else {
            throw Abort(.notFound, reason: "User with ID \(userId) not found")
        }
        
        // Prevent users from removing their own admin status if they're the only admin
        if user.id == requesterId && user.isAdmin {
            // Check if this is the only admin (simplified check - could be enhanced)
            // For now, allow it but this could be enhanced with a more comprehensive check
        }
        
        // Toggle admin status
        user.isAdmin.toggle()
        try await userRepository.save(user)
        
        return user
    }
    
    /// Update user information
    func updateUser(userId: UUID, updates: UserUpdateRequest, requesterId: UUID) async throws -> User {
        // Verify requester has permission (admin or self)
        guard let requester = try await userRepository.get(id: requesterId) else {
            throw AuthorizationError.notAuthorized(reason: "Requester not found")
        }
        
        guard requester.isAdmin || requester.id == userId else {
            throw AuthorizationError.notAuthorized(reason: "You can only update your own information")
        }
        
        // Get the target user
        guard let targetUser = try await userRepository.get(id: userId) else {
            throw Abort(.notFound, reason: "User with ID \(userId) not found")
        }
        
        // Apply updates (extend as needed)
        if let email = updates.email {
            // Check if email is already taken
            if try await userRepository.exists(email: email), targetUser.email != email {
                throw ValidationError.failed("Email is already taken")
            }
            targetUser.email = email
        }
        
        // Save updated user
        try await userRepository.save(targetUser)
        
        return targetUser
    }
    
    /// Get health information for admin dashboard
    func getHealthInfo() async -> AdminDashboardViewContext.HealthInfo {
        // TODO: Implement actual health checks
        // This could check database connection, Redis connection, memory usage, etc.
        return AdminDashboardViewContext.HealthInfo(
            uptime: ProcessInfo.processInfo.systemUptime.formatted(),
            databaseConnected: true, // TODO: Actually check database
            redisConnected: true,    // TODO: Actually check Redis
            memoryUsage: "\(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) MB",
            lastDeployment: "N/A"    // TODO: Get from environment or deployment info
        )
    }
}

// MARK: - DTOs

/// Request DTO for updating user information via UserService
struct UserUpdateRequest: Content, Validatable {
    let email: String?
    
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String?.self, is: .nil || .email, required: false)
    }
} 