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
            ViewContextDTOs.LoginContext(
                error: req.query[String.self, at: "error"]
            )
        )
    }
    
    // Registration endpoint
    @Sendable
    func register(req: Request) async throws -> DTOs.AuthResponse {
        try DTOs.RegisterRequest.validate(content: req)
        let registerRequest = try req.content.decode(DTOs.RegisterRequest.self)
        
        // Use the auth service to register the user
        return try await req.services.authService.register(registerRequest)
    }
    
    // Login endpoint
    @Sendable
    func login(req: Request) async throws -> Response {
        try DTOs.LoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(DTOs.LoginRequest.self)
        
        // Use the auth service to login the user
        let authResponse = try await req.services.authService.login(loginRequest)
        
        // Check if this is an API call or a web request
        if req.headers.accept.first?.mediaType == .json {
            // API call, return JSON response
            return Response(status: .ok, body: .init(data: try JSONEncoder().encode(authResponse)))
        } else {
            // Web request, set cookie and redirect
            let response = req.redirect(to: "/dashboard")
            response.cookies["vapor-auth-token"] = .init(
                string: authResponse.token,
                expires: Date().addingTimeInterval(86400), // 24 hours
                isSecure: true,
                isHTTPOnly: true,
                sameSite: .lax
            )
            return response
        }
    }
    
    // Logout endpoint
    @Sendable
    func logout(req: Request) async throws -> Response {
        // Clear the auth cookie
        let response = req.redirect(to: "/auth/login")
        response.cookies["vapor-auth-token"] = .init(
            string: "",
            expires: Date(timeIntervalSince1970: 0),
            isSecure: true,
            isHTTPOnly: true,
            sameSite: .lax
        )
        
        // Destroy session
        req.session.destroy()
        
        return response
    }
} 
