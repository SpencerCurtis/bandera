import Vapor
import Fluent

/// Container for all services and repositories in the application.
final class ServiceContainer: @unchecked Sendable {
    var webSocketService: WebSocketServiceProtocol
    var featureFlagRepository: FeatureFlagRepositoryProtocol
    var userRepository: UserRepositoryProtocol
    var featureFlagService: FeatureFlagServiceProtocol
    var authService: AuthServiceProtocol
    
    /// Initialize with all services and repositories
    /// - Parameters:
    ///   - webSocketService: The WebSocket service
    ///   - featureFlagRepository: The feature flag repository
    ///   - userRepository: The user repository
    ///   - featureFlagService: The feature flag service
    ///   - authService: The authentication service
    init(
        webSocketService: WebSocketServiceProtocol,
        featureFlagRepository: FeatureFlagRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        featureFlagService: FeatureFlagServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.webSocketService = webSocketService
        self.featureFlagRepository = featureFlagRepository
        self.userRepository = userRepository
        self.featureFlagService = featureFlagService
        self.authService = authService
    }
    
    /// Initialize with the Vapor application
    /// - Parameter app: The Vapor application
    convenience init(app: Application) {
        // Create repositories
        let featureFlagRepository = FeatureFlagRepository(database: app.db)
        let userRepository = UserRepository(database: app.db)
        
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
        
        // Initialize with all services and repositories
        self.init(
            webSocketService: webSocketService,
            featureFlagRepository: featureFlagRepository,
            userRepository: userRepository,
            featureFlagService: featureFlagService,
            authService: authService
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

// MARK: - Request Extension

extension Request {
    /// The request's service container.
    var services: ServiceContainer {
        application.services
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
            description: "",
            isEnabled: false,
            createdAt: Date(),
            updatedAt: Date(),
            userOverrides: [],
            auditLogs: []
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