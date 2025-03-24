import Vapor
import Fluent
import JWT

final class AuthController: RouteCollection, @unchecked Sendable {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        
        // Login routes
        auth.get("login", use: Self.loginPage)
        auth.post("login", use: Self.login)
        
        // Signup routes
        auth.get("signup", use: Self.signupPage)
        auth.post("signup", use: Self.signup)
        
        // Logout route
        auth.get("logout", use: Self.logout)
    }
    
    /// Render the login page
    @Sendable
    static func loginPage(req: Request) async throws -> View {
        return try await req.view.render("login")
    }
    
    /// Render the signup page
    @Sendable
    static func signupPage(req: Request) async throws -> View {
        return try await req.view.render("signup")
    }
    
    /// Handle user signup
    @Sendable
    static func signup(req: Request) async throws -> Response {
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
    static func login(req: Request) async throws -> Response {
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
        
        // Set session data
        req.session.data["user_id"] = user.id?.uuidString
        req.session.data["is_admin"] = String(user.isAdmin)
        
        // Create response with redirect
        let response = req.redirect(to: "/dashboard")
        
        // Set auth cookie
        let payload = UserJWTPayload(
            subject: .init(value: user.id?.uuidString ?? ""),
            expiration: .init(value: Date().addingTimeInterval(7 * 24 * 60 * 60)), // 7 days
            isAdmin: user.isAdmin
        )
        let token = try req.jwt.sign(payload)
        
        response.cookies["bandera-auth-token"] = .init(
            string: token,
            expires: Date().addingTimeInterval(7 * 24 * 60 * 60),
            isSecure: req.application.environment != .development,
            isHTTPOnly: true,
            sameSite: .lax
        )
        
        return response
    }
    
    /// Handle user logout
    @Sendable
    static func logout(req: Request) async throws -> Response {
        req.session.destroy()
        let response = req.redirect(to: "/login")
        response.cookies["bandera-auth-token"] = .expired
        return response
    }
}

// Helper struct for error responses
private struct ErrorResponse: Content {
    let error: Bool
    let reason: String
    let statusCode: UInt
} 
