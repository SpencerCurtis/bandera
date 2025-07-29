import XCTVapor
import Fluent
@testable import App

final class OrganizationRepositoryTests: XCTestCase {
    var app: Application!
    var repository: OrganizationRepository!
    var userRepository: UserRepository!
    
    override func setUp() async throws {
        self.app = try await setupTestApp()
        self.repository = OrganizationRepository(db: app.db)
        self.userRepository = UserRepository(database: app.db)
    }
    
    override func tearDown() async throws {
        try await teardownTestApp(app)
        self.app = nil
        self.repository = nil
        self.userRepository = nil
    }
    
    // MARK: - Organization CRUD Tests
    
    func testCreateOrganization() async throws {
        // Given
        let organization = Organization(name: "Test Organization")
        
        // When
        let createdOrg = try await repository.create(organization)
        
        // Then
        XCTAssertNotNil(createdOrg.id)
        XCTAssertEqual(createdOrg.name, "Test Organization")
    }
    
    func testFindOrganizationById() async throws {
        // Given
        let organization = Organization(name: "Find Test Org")
        let createdOrg = try await repository.create(organization)
        
        // When
        let foundOrg = try await repository.find(id: createdOrg.id!)
        
        // Then
        XCTAssertNotNil(foundOrg)
        XCTAssertEqual(foundOrg?.name, "Find Test Org")
    }
    
    func testFindNonExistentOrganization() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When
        let foundOrg = try await repository.find(id: nonExistentId)
        
        // Then
        XCTAssertNil(foundOrg)
    }
    
    func testGetAllOrganizations() async throws {
        // Given
        let org1 = Organization(name: "Org 1")
        let org2 = Organization(name: "Org 2")
        let org3 = Organization(name: "Org 3")
        
        _ = try await repository.create(org1)
        _ = try await repository.create(org2)
        _ = try await repository.create(org3)
        
        // When
        let allOrgs = try await repository.allUnpaginated()
        
        // Then
        XCTAssertEqual(allOrgs.count, 3)
        let names = allOrgs.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Org 1", "Org 2", "Org 3"])
    }
    
    func testUpdateOrganization() async throws {
        // Given
        let organization = Organization(name: "Original Name")
        let createdOrg = try await repository.create(organization)
        
        // When
        createdOrg.name = "Updated Name"
        try await repository.update(createdOrg)
        
        let updatedOrg = try await repository.find(id: createdOrg.id!)
        
        // Then
        XCTAssertEqual(updatedOrg?.name, "Updated Name")
    }
    
    func testDeleteOrganization() async throws {
        // Given
        let organization = Organization(name: "Delete Test Org")
        let createdOrg = try await repository.create(organization)
        let orgId = createdOrg.id!
        
        // When
        try await repository.delete(createdOrg)
        
        // Then
        let deletedOrg = try await repository.find(id: orgId)
        XCTAssertNil(deletedOrg)
    }
    
    // MARK: - User Membership Tests
    
    func testAddUserToOrganization() async throws {
        // Given
        let user = User(email: "member@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Member Test Org")
        let createdOrg = try await repository.create(organization)
        
        // When
        let membership = try await repository.addUser(
            to: createdOrg.id!,
            userId: user.id!,
            role: .member
        )
        
        // Then
        XCTAssertEqual(membership.role, .member)
        XCTAssertEqual(membership.$organization.id, createdOrg.id!)
        XCTAssertEqual(membership.$user.id, user.id!)
    }
    
    func testAddUserToOrganizationAsAdmin() async throws {
        // Given
        let user = User(email: "admin@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Admin Test Org")
        let createdOrg = try await repository.create(organization)
        
        // When
        let membership = try await repository.addUser(
            to: createdOrg.id!,
            userId: user.id!,
            role: .admin
        )
        
        // Then
        XCTAssertEqual(membership.role, .admin)
    }
    
    func testPreventDuplicateUserMembership() async throws {
        // Given
        let user = User(email: "duplicate@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Duplicate Test Org")
        let createdOrg = try await repository.create(organization)
        
        // Add user once
        _ = try await repository.addUser(to: createdOrg.id!, userId: user.id!, role: .member)
        
        // When/Then - Adding the same user again should throw an error
        do {
            _ = try await repository.addUser(to: createdOrg.id!, userId: user.id!, role: .admin)
            XCTFail("Expected duplicate membership error")
        } catch {
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testRemoveUserFromOrganization() async throws {
        // Given
        let user = User(email: "remove@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let organization = Organization(name: "Remove Test Org")
        let createdOrg = try await repository.create(organization)
        
        // Add user first
        _ = try await repository.addUser(to: createdOrg.id!, userId: user.id!, role: .member)
        
        // When
        try await repository.removeUser(from: createdOrg.id!, userId: user.id!)
        
        // Then
        let isMember = try await repository.isMember(userId: user.id!, organizationId: createdOrg.id!)
        XCTAssertFalse(isMember)
    }
    
    func testGetOrganizationsForUser() async throws {
        // Given
        let user = User(email: "multiorg@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let org1 = Organization(name: "User Org 1")
        let org2 = Organization(name: "User Org 2")
        let org3 = Organization(name: "Other Org")
        
        let createdOrg1 = try await repository.create(org1)
        let createdOrg2 = try await repository.create(org2)
        _ = try await repository.create(org3)
        
        // Add user to first two organizations
        _ = try await repository.addUser(to: createdOrg1.id!, userId: user.id!, role: .member)
        _ = try await repository.addUser(to: createdOrg2.id!, userId: user.id!, role: .admin)
        
        // When
        let userOrgs = try await repository.getForUser(userId: user.id!)
        
        // Then
        XCTAssertEqual(userOrgs.count, 2)
        let orgNames = userOrgs.map { $0.name }.sorted()
        XCTAssertEqual(orgNames, ["User Org 1", "User Org 2"])
    }
    
    func testGetMembersOfOrganization() async throws {
        // Given
        let user1 = User(email: "member1@example.com", passwordHash: "password", isAdmin: false)
        let user2 = User(email: "member2@example.com", passwordHash: "password", isAdmin: false)
        let user3 = User(email: "nonmember@example.com", passwordHash: "password", isAdmin: false)
        
        try await userRepository.save(user1)
        try await userRepository.save(user2)
        try await userRepository.save(user3)
        
        let organization = Organization(name: "Members Test Org")
        let createdOrg = try await repository.create(organization)
        
        // Add two users to the organization
        _ = try await repository.addUser(to: createdOrg.id!, userId: user1.id!, role: .member)
        _ = try await repository.addUser(to: createdOrg.id!, userId: user2.id!, role: .admin)
        
        // When
        let members = try await repository.getMembers(organizationId: createdOrg.id!)
        
        // Then
        XCTAssertEqual(members.count, 2)
        let memberUserIds = members.map { $0.$user.id as UUID }.sorted()
        XCTAssertEqual(memberUserIds, [user1.id!, user2.id!].sorted())
    }
    
    // MARK: - Membership Check Tests
    
    func testIsMemberCheck() async throws {
        // Given
        let user = User(email: "check@example.com", passwordHash: "password", isAdmin: false)
        let nonMemberUser = User(email: "nonmember@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        try await userRepository.save(nonMemberUser)
        
        let organization = Organization(name: "Check Org")
        let createdOrg = try await repository.create(organization)
        
        // Add only one user
        _ = try await repository.addUser(to: createdOrg.id!, userId: user.id!, role: .member)
        
        // When/Then
        let isMember = try await repository.isMember(userId: user.id!, organizationId: createdOrg.id!)
        XCTAssertTrue(isMember)
        
        let isNotMember = try await repository.isMember(userId: nonMemberUser.id!, organizationId: createdOrg.id!)
        XCTAssertFalse(isNotMember)
    }
    
    func testIsAdminCheck() async throws {
        // Given
        let adminUser = User(email: "admin@example.com", passwordHash: "password", isAdmin: false)
        let memberUser = User(email: "member@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(adminUser)
        try await userRepository.save(memberUser)
        
        let organization = Organization(name: "Admin Check Org")
        let createdOrg = try await repository.create(organization)
        
        // Add users with different roles
        _ = try await repository.addUser(to: createdOrg.id!, userId: adminUser.id!, role: .admin)
        _ = try await repository.addUser(to: createdOrg.id!, userId: memberUser.id!, role: .member)
        
        // When/Then
        let isAdmin = try await repository.isAdmin(userId: adminUser.id!, organizationId: createdOrg.id!)
        XCTAssertTrue(isAdmin)
        
        let isNotAdmin = try await repository.isAdmin(userId: memberUser.id!, organizationId: createdOrg.id!)
        XCTAssertFalse(isNotAdmin)
    }
    
    func testGetMembershipsForUser() async throws {
        // Given
        let user = User(email: "membership@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user)
        
        let org1 = Organization(name: "Membership Org 1")
        let org2 = Organization(name: "Membership Org 2")
        
        let createdOrg1 = try await repository.create(org1)
        let createdOrg2 = try await repository.create(org2)
        
        // Add user with different roles
        _ = try await repository.addUser(to: createdOrg1.id!, userId: user.id!, role: .member)
        _ = try await repository.addUser(to: createdOrg2.id!, userId: user.id!, role: .admin)
        
        // When
        let memberships = try await repository.getMembershipsForUser(userId: user.id!)
        
        // Then
        XCTAssertEqual(memberships.count, 2)
        let roles = memberships.map { $0.role }.sorted { $0.rawValue < $1.rawValue }
        XCTAssertEqual(roles, [OrganizationRole.admin, OrganizationRole.member])
    }
    
    func testGetAllMembershipsForOrganization() async throws {
        // Given
        let user1 = User(email: "orgmember1@example.com", passwordHash: "password", isAdmin: false)
        let user2 = User(email: "orgmember2@example.com", passwordHash: "password", isAdmin: false)
        try await userRepository.save(user1)
        try await userRepository.save(user2)
        
        let organization = Organization(name: "All Memberships Org")
        let createdOrg = try await repository.create(organization)
        
        // Add users
        _ = try await repository.addUser(to: createdOrg.id!, userId: user1.id!, role: .member)
        _ = try await repository.addUser(to: createdOrg.id!, userId: user2.id!, role: .admin)
        
        // When
        let allMemberships = try await repository.getAllMembershipsForOrganization(id: createdOrg.id!)
        
        // Then
        XCTAssertEqual(allMemberships.count, 2)
        let userIds = allMemberships.map { $0.$user.id as UUID }.sorted()
        XCTAssertEqual(userIds, [user1.id!, user2.id!].sorted())
    }
} 