import Vapor
import Fluent
import JWT

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Use optional authentication for auth routes
        let auth = routes.grouped(AuthMiddleware.optional).grouped("auth")
        
        auth.get("login", use: loginPage)
        auth.post("login", use: login)
        auth.post("register", use: register)
        auth.post("logout", use: logout)
    }
    
    // Show login page
    @Sendable
    func loginPage(req: Request) async throws -> View {
        var context = ViewContext(title: "Login")
        
        // Check if there's an error query parameter
        if let errorMessage = req.query[String.self, at: "error"] {
            context.error = errorMessage
        }
        
        return try await req.view.render("login", context)
    }
    
    // Registration endpoint
    @Sendable
    func register(req: Request) async throws -> AuthResponse {
        try RegisterRequest.validate(content: req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        
        // Use the auth service to register the user
        return try await req.services.authService.register(registerRequest)
    }
    
    // Login endpoint
    @Sendable
    func login(req: Request) async throws -> Response {
        try LoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(LoginRequest.self)
        
        do {
            // Use the auth service to login the user
            let authResponse = try await req.services.authService.login(loginRequest)
            
            // Check if this is an API call or a web request
            if req.headers.accept.first?.mediaType == .json {
                // API call, return JSON response
                return try await authResponse.encodeResponse(for: req)
            } else {
                // Web request, set cookie and redirect to dashboard
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
        } catch {
            // Check if this is an API call or a web request
            if req.headers.accept.first?.mediaType == .json {
                // API call, return JSON error
                throw error
            } else {
                // Web request, redirect to login page with error
                let errorMessage = (error as? any BanderaErrorProtocol)?.reason ?? "Invalid credentials"
                return req.redirect(to: "/auth/login?error=\(errorMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            }
        }
    }
    
    // Logout endpoint
    @Sendable
    func logout(req: Request) async throws -> Response {
        // Clear the auth cookie
        let response = req.redirect(to: "/auth/login")
        response.cookies["vapor-auth-token"] = .init(
            string: "",
            expires: Date().addingTimeInterval(-86400), // Expired
            isSecure: true,
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
