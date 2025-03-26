import Fluent
import Vapor

/// Model representing an organization in the system.
final class Organization: Model, Content {
    /// Database schema name
    static let schema = "organizations"
    
    /// Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    /// Organization name
    @Field(key: "name")
    var name: String
    
    /// When the organization was created
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    /// When the organization was last updated
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    /// Default initializer
    init() { }
    
    /// Initializer with all properties
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Helper Methods
extension Organization {
    /// Create an organization from a DTO
    static func create(from dto: CreateOrganizationRequest) -> Organization {
        Organization(
            name: dto.name
        )
    }
    
    /// Update an organization from a DTO
    func update(from dto: UpdateOrganizationRequest) {
        self.name = dto.name
    }
}

// MARK: - DTO Conversion
extension Organization {
    /// Convert to a simplified organization DTO.
    func toDTO() -> OrganizationDTO {
        OrganizationDTO(
            id: id!,
            name: name
        )
    }
}

// MARK: - Sendable Conformance
extension Organization: @unchecked Sendable {
    // Fluent models are thread-safe by design when using property wrappers
    // The @unchecked Sendable conformance is safe because:
    // 1. All properties use Fluent property wrappers that handle thread safety
    // 2. Properties are only modified through Fluent's thread-safe operations
    // 3. The Model protocol requires internal access for setters
} 