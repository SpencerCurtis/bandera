import Vapor
import Fluent
import JWT

/// Controller for authentication-related routes
struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        
        // Login routes
        auth.get("login", use: loginPage)
        auth.post("login", use: login)
        
        // Signup routes
        auth.get("signup", use: signupPage)
        auth.post("signup", use: signup)
        
        // Logout route
        auth.get("logout", use: logout)
    }
    
    /// Render the login page
    @Sendable
    func loginPage(req: Request) async throws -> View {
        return try await req.view.render("login")
    }
    
    /// Render the signup page
    @Sendable
    func signupPage(req: Request) async throws -> View {
        return try await req.view.render("signup")
    }
    
    /// Handle user signup
    @Sendable
    func signup(req: Request) async throws -> Response {
        // Validate the request
        try RegisterRequest.validate(content: req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        
        // Check if user already exists
        if try await User.query(on: req.db)
            .filter(\.$email == registerRequest.email)
            .first() != nil {
            return try await req.view.render("signup", ["error": "A user with this email already exists"]).encodeResponse(for: req)
        }
        
        // Create and save the user
        let user = try User.create(from: registerRequest)
        try await user.save(on: req.db)
        
        // Create JWT payload and token
        let payload = try UserJWTPayload(user: user)
        let token = try req.jwt.sign(payload)
        
        // Set the token cookie
        let response = req.redirect(to: "/dashboard")
        response.cookies["bandera-auth-token"] = .init(
            string: token,
            expires: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            domain: nil,
            path: "/",
            isSecure: req.application.environment.isRelease,
            isHTTPOnly: true,
            sameSite: .lax
        )
        
        return response
    }
    
    /// Handle user login
    @Sendable
    func login(req: Request) async throws -> Response {
        try LoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(LoginRequest.self)
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == loginRequest.email)
            .first() else {
            throw AuthenticationError.invalidCredentials
        }
        
        guard try user.verify(password: loginRequest.password) else {
            throw AuthenticationError.invalidCredentials
        }
        
        let payload = try UserJWTPayload(user: user)
        let token = try req.jwt.sign(payload)
        
        let response = req.redirect(to: "/dashboard")
        response.cookies["bandera-auth-token"] = .init(
            string: token,
            expires: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            domain: nil,
            path: "/",
            isSecure: req.application.environment.isRelease,
            isHTTPOnly: true,
            sameSite: .lax
        )
        
        return response
    }
    
    /// Handle user logout
    @Sendable
    func logout(req: Request) async throws -> Response {
        // Clear the session
        req.session.data = [:]
        
        // Clear the token cookie
        let response = req.redirect(to: "/auth/login")
        response.cookies["bandera-auth-token"] = .init(
            string: "",
            expires: Date(timeIntervalSince1970: 0),
            domain: nil,
            path: "/",
            isSecure: req.application.environment.isRelease,
            isHTTPOnly: true,
            sameSite: .lax
        )
        
        return response
    }
}

// Helper struct for error responses
private struct ErrorResponse: Content {
    let error: Bool
    let reason: String
    let statusCode: UInt
} 
