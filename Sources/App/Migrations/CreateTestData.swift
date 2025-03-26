import Fluent
import Vapor

/// Migration to create test organizations and flags for development
struct CreateTestData: AsyncMigration {
    /// The environment in which the application is running
    let environment: Environment
    
    /// Initialize with the application environment
    init(environment: Environment) {
        self.environment = environment
    }
    
    /// Create test organizations and flags
    func prepare(on database: Database) async throws {
        // Only create test data in development mode
        guard environment == .development else {
            database.logger.notice("Skipping test data creation: not in development environment")
            return
        }
        
        database.logger.notice("Starting test data creation...")
        
        do {
            // Get the admin user
            guard let adminUser = try await User.query(on: database)
                .filter(\.$email == "admin@example.com")
                .first() else {
                throw Abort(.notFound, reason: "Admin user not found")
            }
            
            // Create a test organization
            let organization = Organization(
                name: "Test Organization"
            )
            try await organization.save(on: database)
            
            // Add admin user to organization
            let orgUser = try OrganizationUser(
                organizationId: organization.requireID(),
                userId: adminUser.requireID(),
                role: .admin
            )
            try await orgUser.save(on: database)
            
            // Create test feature flags
            let flags = [
                FeatureFlag(
                    key: "test-flag-1",
                    type: .boolean,
                    defaultValue: "false",
                    description: "A test boolean flag",
                    userId: adminUser.id,
                    organizationId: organization.id
                ),
                FeatureFlag(
                    key: "test-flag-2",
                    type: .string,
                    defaultValue: "test",
                    description: "A test string flag",
                    userId: adminUser.id,
                    organizationId: organization.id
                ),
                FeatureFlag(
                    key: "personal-flag",
                    type: .boolean,
                    defaultValue: "true",
                    description: "A personal test flag",
                    userId: adminUser.id,
                    organizationId: nil
                )
            ]
            
            for flag in flags {
                try await flag.save(on: database)
                
                // Create an audit log for the flag
                let auditLog = AuditLog(
                    type: "created",
                    message: "Flag created during test data setup",
                    featureFlagId: try flag.requireID(),
                    userId: try adminUser.requireID()
                )
                try await auditLog.save(on: database)
            }
            
            database.logger.notice("Test data created successfully")
            
        } catch {
            database.logger.error("Error creating test data: \(error)")
            throw error
        }
    }
    
    /// Remove test data
    func revert(on database: Database) async throws {
        // Only remove test data in development mode
        guard environment == .development else {
            return
        }
        
        database.logger.notice("Removing test data...")
        
        // Remove test flags and organizations
        try await FeatureFlag.query(on: database).delete()
        try await Organization.query(on: database).delete()
        try await OrganizationUser.query(on: database).delete()
        try await AuditLog.query(on: database).delete()
        
        database.logger.notice("Test data removed")
    }
} 