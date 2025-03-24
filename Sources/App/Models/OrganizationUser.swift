import Fluent
import Vapor

/// Role of a user in an organization
enum OrganizationRole: String, Codable {
    case admin
    case member
}

/// Model representing a user's membership in an organization.
final class OrganizationUser: Model, Content {
    static let schema = "organization_users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "organization_id")
    var organization: Organization
    
    @Parent(key: "user_id")
    var user: User
    
    @Enum(key: "role")
    var role: OrganizationRole
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         organizationId: UUID,
         userId: UUID,
         role: OrganizationRole = .member) {
        self.id = id
        self.$organization.id = organizationId
        self.$user.id = userId
        self.role = role
    }
}

// MARK: - Migrations
extension OrganizationUser {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            let roleEnum = try await database.enum("organization_role")
                .case("admin")
                .case("member")
                .create()
            
            try await database.schema(OrganizationUser.schema)
                .id()
                .field("organization_id", .uuid, .required, .references(Organization.schema, "id", onDelete: .cascade))
                .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("role", roleEnum, .required)
                .field("created_at", .datetime)
                .field("updated_at", .datetime)
                .unique(on: "organization_id", "user_id")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(OrganizationUser.schema).delete()
            try await database.enum("organization_role").delete()
        }
    }
}

// MARK: - DTO Conversion
extension OrganizationUser {
    /// Convert to a membership DTO.
    func toDTO() async throws -> OrganizationMembershipDTO {
        return OrganizationMembershipDTO(from: self)
    }
}

// MARK: - Sendable Conformance
extension OrganizationUser: @unchecked Sendable {} 