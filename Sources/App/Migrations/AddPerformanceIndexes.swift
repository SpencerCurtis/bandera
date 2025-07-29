import Fluent
import SQLKit

/// Migration to add database indexes for improved query performance
struct AddPerformanceIndexes: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Ensure we're working with a SQL database
        guard let sql = database as? SQLDatabase else {
            return
        }
        
        // Add index on feature_flags.user_id for efficient user-specific queries
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_feature_flags_user_id ON feature_flags (user_id)").run()
        
        // Add index on feature_flags.organization_id for efficient organization-specific queries  
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_feature_flags_organization_id ON feature_flags (organization_id)").run()
    }
    
    func revert(on database: Database) async throws {
        // Ensure we're working with a SQL database
        guard let sql = database as? SQLDatabase else {
            return
        }
        
        // Remove the indexes we created
        try await sql.raw("DROP INDEX IF EXISTS idx_feature_flags_user_id").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_feature_flags_organization_id").run()
    }
} 