import Vapor
import Fluent

/// Container for all services and repositories in the application.
final class ServiceContainer: @unchecked Sendable {
    var webSocketService: WebSocketServiceProtocol
    var featureFlagRepository: FeatureFlagRepositoryProtocol
    var userRepository: UserRepositoryProtocol
    var organizationRepository: OrganizationRepositoryProtocol
    var featureFlagService: FeatureFlagServiceProtocol
    var authService: AuthServiceProtocol
    var organizationService: OrganizationServiceProtocol
    
    /// Initialize with all services and repositories
    /// - Parameters:
    ///   - webSocketService: The WebSocket service
    ///   - featureFlagRepository: The feature flag repository
    ///   - userRepository: The user repository
    ///   - organizationRepository: The organization repository
    ///   - featureFlagService: The feature flag service
    ///   - authService: The authentication service
    ///   - organizationService: The organization service
    init(
        webSocketService: WebSocketServiceProtocol,
        featureFlagRepository: FeatureFlagRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        organizationRepository: OrganizationRepositoryProtocol,
        featureFlagService: FeatureFlagServiceProtocol,
        authService: AuthServiceProtocol,
        organizationService: OrganizationServiceProtocol
    ) {
        self.webSocketService = webSocketService
        self.featureFlagRepository = featureFlagRepository
        self.userRepository = userRepository
        self.organizationRepository = organizationRepository
        self.featureFlagService = featureFlagService
        self.authService = authService
        self.organizationService = organizationService
    }
    
    /// Initialize with the Vapor application
    /// - Parameter app: The Vapor application
    convenience init(app: Application) {
        // Create repositories
        let featureFlagRepository = FeatureFlagRepository(database: app.db)
        let userRepository = UserRepository(database: app.db)
        let organizationRepository = OrganizationRepository(db: app.db)
        
        // Create services
        let webSocketService = WebSocketService()
        let featureFlagService = FeatureFlagService(
            repository: featureFlagRepository,
            webSocketService: webSocketService
        )
        let authService = AuthService(
            userRepository: userRepository,
            jwtSigner: app.jwt.signers
        )
        let organizationService = OrganizationService(
            organizationRepository: organizationRepository,
            userRepository: userRepository
        )
        
        // Initialize with all services and repositories
        self.init(
            webSocketService: webSocketService,
            featureFlagRepository: featureFlagRepository,
            userRepository: userRepository,
            organizationRepository: organizationRepository,
            featureFlagService: featureFlagService,
            authService: authService,
            organizationService: organizationService
        )
    }
}

// MARK: - Application Extension

extension Application {
    /// Storage key for the service container in the application storage
    private struct ServiceContainerKey: StorageKey {
        typealias Value = ServiceContainer
    }
    
    /// The application's service container.
    var services: ServiceContainer {
        get {
            if let existing = storage[ServiceContainerKey.self] {
                return existing
            }
            let new = ServiceContainer(app: self)
            storage[ServiceContainerKey.self] = new
            return new
        }
        set {
            storage[ServiceContainerKey.self] = newValue
        }
    }
}

// MARK: - Empty Implementations

private struct EmptyWebSocketService: WebSocketServiceProtocol {
    func add(_ ws: WebSocket, id: UUID) async {}
    func remove(id: UUID) async {}
    func send(message: String, to id: UUID) async throws {}
    func send<T: Codable & Sendable>(event: String, data: T, to id: UUID) async throws {}
    func broadcast(message: String) async throws {}
    func broadcast<T: Codable & Sendable>(event: String, data: T) async throws {}
    func connectionCount() async -> Int { 0 }
}

private struct EmptyFeatureFlagRepository: FeatureFlagRepositoryProtocol {
    var database: Database {
        fatalError("EmptyFeatureFlagRepository does not have a database")
    }
    func create(_ flag: FeatureFlag) async throws -> FeatureFlag { flag }
    func update(_ flag: FeatureFlag) async throws -> FeatureFlag { flag }
    func get(id: UUID) async throws -> FeatureFlag? { nil }
    func getAll() async throws -> [FeatureFlag] { [] }
    func all() async throws -> [FeatureFlag] { [] }
    func getAllForUser(userId: UUID) async throws -> [FeatureFlag] { [] }
    func getAllForOrganization(organizationId: UUID) async throws -> [FeatureFlag] { [] }
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer { 
        FeatureFlagsContainer(flags: [:]) 
    }
    func exists(key: String, userId: UUID) async throws -> Bool { false }
    func save(_ flag: FeatureFlag) async throws {}
    func delete(_ flag: FeatureFlag) async throws {}
    func getOverrides(flagId: UUID) async throws -> [UserFeatureFlag] { [] }
    func getAuditLogs(flagId: UUID) async throws -> [AuditLog] { [] }
    func isEnabled(id: UUID) async throws -> Bool { false }
    func setEnabled(id: UUID, enabled: Bool) async throws {}
    func createAuditLog(type: String, message: String, flagId: UUID, userId: UUID) async throws {}
    func saveOverride(_ override: UserFeatureFlag) async throws {}
    func findOverride(id: UUID) async throws -> UserFeatureFlag? { nil }
    func deleteOverride(_ override: UserFeatureFlag) async throws {}
}

private struct EmptyUserRepository: UserRepositoryProtocol {
    func save(_ user: User) async throws {}
    func exists(email: String) async throws -> Bool { false }
    func get(id: UUID) async throws -> User? { nil }
    func getById(_ id: UUID) async throws -> User? { nil }
    func getByEmail(_ email: String) async throws -> User? { nil }
    func findByEmail(_ email: String) async throws -> User? { nil }
    func delete(_ user: User) async throws {}
    func getAllUsers() async throws -> [User] { [] }
}

private struct EmptyFeatureFlagService: FeatureFlagServiceProtocol {
    func createFlag(_ dto: CreateFeatureFlagRequest, userId: UUID) async throws -> FeatureFlag { 
        FeatureFlag(
            key: "",
            type: .boolean,
            defaultValue: "false",
            description: "",
            userId: userId
        )
    }
    func updateFlag(id: UUID, _ dto: UpdateFeatureFlagRequest, userId: UUID) async throws -> FeatureFlag {
        FeatureFlag(
            id: id,
            key: "",
            type: .boolean,
            defaultValue: "false",
            description: "",
            userId: userId
        )
    }
    func deleteFlag(id: UUID, userId: UUID) async throws {}
    func toggleFlag(id: UUID, userId: UUID) async throws -> FeatureFlag {
        FeatureFlag(
            id: id,
            key: "",
            type: .boolean,
            defaultValue: "false",
            description: "",
            userId: userId
        )
    }
    func getFlagDetails(id: UUID, userId: UUID) async throws -> FeatureFlagDetailDTO {
        FeatureFlagDetailDTO(
            id: id,
            key: "",
            type: .boolean,
            defaultValue: "false",
            description: nil,
            isEnabled: false,
            createdAt: nil,
            updatedAt: nil,
            organizationId: nil,
            userOverrides: [],
            auditLogs: [],
            organizations: []
        )
    }
    func getAllFlags(userId: UUID) async throws -> [FeatureFlag] { [] }
    func getFlag(id: UUID, userId: UUID) async throws -> FeatureFlag {
        FeatureFlag(
            id: id,
            key: "",
            type: .boolean,
            defaultValue: "false",
            description: "",
            userId: userId
        )
    }
    func getFlagsWithOverrides(userId: String) async throws -> FeatureFlagsContainer {
        FeatureFlagsContainer(flags: [:])
    }
    func broadcastEvent(_ event: FeatureFlagEventType, flag: FeatureFlag) async throws {}
    func broadcastDeleteEvent(id: UUID, userId: UUID) async throws {}
    func createOverride(flagId: UUID, userId: UUID, value: String, createdBy: UUID) async throws {}
    func deleteOverride(id: UUID, userId: UUID) async throws {}
    func importFlagToOrganization(flagId: UUID, organizationId: UUID, userId: UUID) async throws -> FeatureFlag {
        FeatureFlag(
            key: "imported-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Imported flag"
        )
    }
    func exportFlagToPersonal(flagId: UUID, userId: UUID) async throws -> FeatureFlag {
        FeatureFlag(
            key: "exported-flag",
            type: .boolean,
            defaultValue: "false",
            description: "Exported flag"
        )
    }
}

private struct EmptyAuthService: AuthServiceProtocol {
    func register(_ dto: RegisterRequest) async throws -> AuthResponse {
        AuthResponse(token: "", user: UserResponse(user: User(email: "", passwordHash: "", isAdmin: false)))
    }
    func login(_ dto: LoginRequest) async throws -> AuthResponse {
        AuthResponse(token: "", user: UserResponse(user: User(email: "", passwordHash: "", isAdmin: false)))
    }
    func generateToken(for user: User) throws -> String { "" }
    func validateTargetUser(requestedUserId: UUID, authenticatedUserId: UUID) async throws -> UUID { 
        authenticatedUserId 
    }
}

private struct EmptyOrganizationService: OrganizationServiceProtocol {
    func create(_ dto: CreateOrganizationRequest, creatorId: UUID) async throws -> Organization {
        Organization(name: "")
    }
    
    func get(id: UUID) async throws -> Organization {
        Organization(name: "")
    }
    
    func update(id: UUID, dto: UpdateOrganizationRequest) async throws -> Organization {
        Organization(name: "")
    }
    
    func delete(id: UUID) async throws {}
    
    func getForUser(userId: UUID) async throws -> [OrganizationWithRoleDTO] {
        []
    }
    
    func addUser(organizationId: UUID, dto: AddUserToOrganizationRequest, requesterId: UUID) async throws -> OrganizationMembershipDTO {
        // Need to create a membership object first to initialize from
        let orgUser = OrganizationUser(organizationId: organizationId, userId: dto.userId, role: dto.role)
        return OrganizationMembershipDTO(from: orgUser)
    }
    
    func removeUser(organizationId: UUID, userId: UUID, requesterId: UUID) async throws {}
    
    func getMembers(organizationId: UUID, requesterId: UUID) async throws -> [OrganizationMemberDTO] {
        []
    }
    
    func getWithMembers(id: UUID, requesterId: UUID) async throws -> OrganizationWithMembersDTO {
        OrganizationWithMembersDTO(organization: OrganizationDTO(id: id, name: "", isPersonal: false, createdAt: Date(), updatedAt: Date()), members: [])
    }
    
    func updateUserRole(to organizationId: UUID, userId: UUID, role: OrganizationRole) async throws -> OrganizationUser {
        OrganizationUser(organizationId: organizationId, userId: userId, role: role)
    }
    
    func createOrganizationDTO(from organization: Organization) -> OrganizationDTO {
        OrganizationDTO(id: organization.id ?? UUID(), name: organization.name, isPersonal: false, createdAt: organization.createdAt, updatedAt: organization.updatedAt)
    }
}