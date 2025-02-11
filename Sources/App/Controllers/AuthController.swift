import Vapor
import Fluent
import JWT

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        
        auth.get("login", use: loginPage)
        auth.post("login", use: login)
        auth.post("register", use: register)
        auth.post("logout", use: logout)
    }
    
    // Show login page
    @Sendable
    func loginPage(req: Request) async throws -> View {
        return try await req.view.render(
            "login",
            ViewContext(
                title: "Login",
                error: req.query[String.self, at: "error"]
            )
        )
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
        
        // Create new user
        let user = try await User.create(from: create)
        try await user.save(on: req.db)
        
        // Generate token
        let payload = try UserJWTPayload(user: user)
        let token = try req.application.jwt.signers.sign(payload)
        
        // Return structured response
        return DTOs.AuthResponse(
            token: token,
            user: .init(user: user)
        )
    }
    
    // Login endpoint
    @Sendable
    func login(req: Request) async throws -> Response {
        let credentials = try req.content.decode(LoginCredentials.self)
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == credentials.email)
            .first() else {
            req.logger.debug("User not found: \(credentials.email)")
            return req.redirect(to: "/auth/login?error=Invalid+credentials")
        }
        
        guard try user.verify(password: credentials.password) else {
            req.logger.debug("Invalid password for user: \(credentials.email)")
            return req.redirect(to: "/auth/login?error=Invalid+credentials")
        }
        
        req.logger.debug("User authenticated successfully: \(credentials.email), isAdmin: \(user.isAdmin)")
        
        // Generate JWT payload and token
        let payload = try UserJWTPayload(user: user)
        let token = try req.jwt.sign(payload)
        
        req.logger.debug("Generated JWT token with payload: subject=\(payload.subject.value), isAdmin=\(payload.isAdmin)")
        
        // Store the token in a secure, HTTP-only cookie
        let cookie = HTTPCookies.Value(
            string: token,
            expires: payload.expiration.value,
            isSecure: false,
            isHTTPOnly: true,
            sameSite: .lax
        )
        
        // Create response with cookie
        let response = req.redirect(to: "/admin/dashboard")
        response.cookies["vapor-auth-token"] = cookie
        
        // Store the payload in the auth session
        req.auth.login(payload)
        
        return response
    }
    
    // Logout endpoint
    @Sendable
    func logout(req: Request) async throws -> Response {
        // Clear the auth token cookie by setting an expired cookie
        let expiredCookie = HTTPCookies.Value(
            string: "",
            expires: Date(timeIntervalSince1970: 0),
            maxAge: -1,
            isSecure: false,
            isHTTPOnly: true,
            sameSite: .lax
        )
        
        // Create response with cache control headers
        let response = req.redirect(to: "/auth/login")
        response.cookies["vapor-auth-token"] = expiredCookie
        
        // Add cache control headers to prevent caching
        response.headers.cacheControl = .init(noCache: true)
        response.headers.add(name: .pragma, value: "no-cache")
        response.headers.add(name: .expires, value: "0")
        
        // Clear the auth session
        req.auth.logout(UserJWTPayload.self)
        req.session.destroy()
        
        return response
    }
} 
