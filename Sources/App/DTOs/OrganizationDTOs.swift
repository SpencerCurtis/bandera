import Vapor
import Fluent

/// DTO representing an Organization with the user's role in that organization
struct OrganizationWithRoleDTO: Content {
    let id: UUID
    let name: String
    let role: OrganizationRole
    let createdAt: Date?
    let updatedAt: Date?
    
    init(organization: Organization, role: OrganizationRole) {
        self.id = organization.id!
        self.name = organization.name
        self.role = role
        self.createdAt = organization.createdAt
        self.updatedAt = organization.updatedAt
    }
    
    func toOrganization() -> Organization {
        Organization(id: id, name: name)
    }
}

/// DTO representing an Organization
struct OrganizationDTO: Content {
    let id: UUID
    let name: String
    let isPersonal: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    internal init(id: UUID, name: String, isPersonal: Bool = false, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.isPersonal = isPersonal
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    internal init(from organization: Organization) {
        self.id = organization.id!
        self.name = organization.name
        self.isPersonal = false // Organizations from the database are never personal
        self.createdAt = organization.createdAt
        self.updatedAt = organization.updatedAt
    }
    
    internal init(from organization: OrganizationWithRoleDTO) {
        self.id = organization.id
        self.name = organization.name
        self.isPersonal = false // Organizations with roles are never personal
        self.createdAt = organization.createdAt
        self.updatedAt = organization.updatedAt
    }
    
    internal init(from organization: OrganizationWithMembersDTO) {
        self.id = organization.id
        self.name = organization.name
        self.isPersonal = false // Organizations with members are never personal
        self.createdAt = organization.createdAt
        self.updatedAt = organization.updatedAt
    }
    
    internal init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.isPersonal = try container.decodeIfPresent(Bool.self, forKey: .isPersonal) ?? false
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isPersonal
        case createdAt
        case updatedAt
    }
}

/// DTO representing a member of an organization with their role
struct OrganizationMemberDTO: Content {
    let id: UUID
    let email: String
    let role: String
    let user: User
    
    init(id: UUID, email: String, role: OrganizationRole, user: User) {
        self.id = id
        self.email = email
        self.role = role.rawValue
        self.user = user
    }
}

/// DTO for creating a new organization
struct CreateOrganizationDTO: Content, Validatable {
    let name: String
    
    init(name: String) {
        self.name = name
    }
    
    /// Validation rules for creating an organization
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty && .count(2...100))
    }
}

/// DTO for updating an organization
struct UpdateOrganizationDTO: Content, Validatable {
    let name: String
    
    init(name: String) {
        self.name = name
    }
    
    /// Validation rules for updating an organization
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty && .count(2...100))
    }
}

/// DTO for adding a user to an organization
struct AddOrganizationUserDTO: Content, Validatable {
    let userId: UUID
    let role: String
    
    init(userId: UUID, role: String) {
        self.userId = userId
        self.role = role
    }
    
    /// Validation rules for adding a user to an organization
    static func validations(_ validations: inout Validations) {
        // UUID validation happens automatically during decoding
        validations.add("role", as: String.self, is: !.empty)
    }
}

/// DTO for updating a user's role in an organization
struct UpdateOrganizationUserRoleDTO: Content, Validatable {
    let role: String
    
    init(role: String) {
        self.role = role
    }
    
    /// Validation rules for updating a user's role
    static func validations(_ validations: inout Validations) {
        validations.add("role", as: String.self, is: !.empty)
    }
}

// Request DTOs
struct CreateOrganizationRequest: Content, Validatable {
    let name: String
    
    /// Validation rules for creating an organization
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty && .count(2...100))
    }
}

struct UpdateOrganizationRequest: Content, Validatable {
    let name: String
    
    /// Validation rules for updating an organization
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty && .count(2...100))
    }
}

struct AddUserToOrganizationRequest: Content, Validatable {
    let userId: UUID
    let role: OrganizationRole
    
    /// Validation rules for adding a user to an organization
    static func validations(_ validations: inout Validations) {
        // UUID validation happens automatically during decoding
        // No additional validation needed for UUID fields
    }
}

struct OrganizationWithMembersDTO: Content {
    let id: UUID
    let name: String
    let createdAt: Date?
    let updatedAt: Date?
    let members: [OrganizationMemberDTO]
    
    init(organization: Organization, members: [OrganizationMemberDTO]) {
        self.id = organization.id!
        self.name = organization.name
        self.createdAt = organization.createdAt
        self.updatedAt = organization.updatedAt
        self.members = members
    }
    
    init(organization: OrganizationDTO, members: [OrganizationMemberDTO]) {
        self.id = organization.id
        self.name = organization.name
        self.createdAt = organization.createdAt
        self.updatedAt = organization.updatedAt
        self.members = members
    }
}

struct OrganizationMembershipDTO: Content {
    let organizationId: UUID
    let userId: UUID
    let role: OrganizationRole
    let createdAt: Date?
    
    init(from membership: OrganizationUser) {
        self.organizationId = membership.$organization.id
        self.userId = membership.$user.id
        self.role = membership.role
        self.createdAt = membership.createdAt
    }
}

struct UserOrganizationsDTO: Content {
    let organizations: [OrganizationWithRoleDTO]
    
    init(organizations: [OrganizationWithRoleDTO]) {
        self.organizations = organizations
    }
} 