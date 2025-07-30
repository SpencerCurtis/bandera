import Fluent
import FluentSQL

struct AddOrganizationIdToFeatureFlag: AsyncMigration {
    func prepare(on database: Database) async throws {
        // For SQLite, we need to create a new table with the desired schema
        // and then copy data from the old table
        
        // 1. Create a new table with the new schema
        try await database.schema(AppConstants.DatabaseTables.featureFlagsTemp)
            .id()
            .field("key", .string, .required)
            .field("type", .string, .required)
            .field("default_value", .string, .required)
            .field("description", .string)
            .field("user_id", .uuid)
            .field("organization_id", .uuid)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "key", "user_id", "organization_id")
            .create()
        
        // 2. Copy data from the old table to the new one
        if let sql = database as? SQLDatabase {
            try await sql.raw("INSERT INTO \(unsafeRaw: AppConstants.DatabaseTables.featureFlagsTemp) SELECT id, key, type, default_value, description, user_id, NULL as organization_id, created_at, updated_at FROM \(unsafeRaw: AppConstants.DatabaseTables.featureFlags)").run()
        } else {
            // Fallback for non-SQL databases
            let flags = try await FeatureFlag.query(on: database).all()
            for flag in flags {
                let newFlag = FeatureFlag(
                    id: flag.id,
                    key: flag.key,
                    type: flag.type,
                    defaultValue: flag.defaultValue,
                    description: flag.description,
                    userId: flag.userId,
                    organizationId: nil // Set to nil for existing flags
                )
                newFlag.createdAt = flag.createdAt
                newFlag.updatedAt = flag.updatedAt
                try await newFlag.save(on: database)
            }
        }
        
        // 3. Drop the old table
        try await database.schema(FeatureFlag.schema).delete()
        
        // 4. Create the new table with the correct name
        try await database.schema(FeatureFlag.schema)
            .id()
            .field("key", .string, .required)
            .field("type", .string, .required)
            .field("default_value", .string, .required)
            .field("description", .string)
            .field("user_id", .uuid)
            .field("organization_id", .uuid)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "key", "user_id", "organization_id")
            .create()
        
        // 5. Copy data from the temp table to the new one
        if let sql = database as? SQLDatabase {
            try await sql.raw("INSERT INTO feature_flags SELECT * FROM feature_flags_temp").run()
            try await sql.raw("DROP TABLE feature_flags_temp").run()
        } else {
            // This is a simplified approach - in a real app, you'd need to handle this more carefully
            let tempFlags = try await database.query(FeatureFlag.self).all()
            for flag in tempFlags {
                try await flag.save(on: database)
            }
            try await database.schema("feature_flags_temp").delete()
        }
    }

    func revert(on database: Database) async throws {
        // For revert, we'll simply recreate the original schema without organization_id
        
        // 1. Drop the current table
        try await database.schema(FeatureFlag.schema).delete()
        
        // 2. Create the table with the original schema
        try await database.schema(FeatureFlag.schema)
            .id()
            .field("key", .string, .required)
            .field("type", .string, .required)
            .field("default_value", .string, .required)
            .field("description", .string)
            .field("user_id", .uuid)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "key", "user_id")
            .create()
    }
} 