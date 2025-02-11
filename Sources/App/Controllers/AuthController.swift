import Vapor
import Fluent
import JWT

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
    }
    
    // Registration endpoint
    @Sendable
    func register(req: Request) async throws -> DTOs.AuthResponse {
        try User.Create.validate(content: req)
        let create = try req.content.decode(User.Create.self)
        
        if try await User.query(on: req.db)
            .filter(\.$email == create.email)
            .first() != nil {
            throw Abort(.conflict, reason: "A user with this email already exists")
        }
        // Check if user already exists
        
        // Create new user
        let user = try await User.create(from: create)
        try await user.save(on: req.db)
        
        // Generate token
        let payload = try UserJWTPayload(user: user)
        let token = try req.jwt.sign(payload)
        
        // Return structured response
        return DTOs.AuthResponse(
            token: token,
            user: .init(user: user)
        )
    }
    
    // Login endpoint
    @Sendable
    func login(req: Request) async throws -> DTOs.AuthResponse {
        let login = try req.content.decode(DTOs.LoginRequest.self)
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == login.email)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        guard user.verify(password: login.password) else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Generate token
        let payload = try UserJWTPayload(user: user)
        let token = try req.jwt.sign(payload)
        
        // Return structured response
        return DTOs.AuthResponse(
            token: token,
            user: .init(user: user)
        )
    }
} 
