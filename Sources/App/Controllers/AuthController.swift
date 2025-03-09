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
        
        // Get the returnTo parameter if present
        if let returnTo = req.query[String.self, at: "returnTo"] {
            context.returnTo = returnTo
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
        
        // Get the returnTo parameter if present
        let returnTo: String
        // First check form data
        if let returnToValue = try? req.content.get(String.self, at: "returnTo") {
            returnTo = returnToValue
        } 
        // Then check query string
        else if let returnToValue = req.query[String.self, at: "returnTo"] {
            returnTo = returnToValue
        } 
        // Default to dashboard
        else {
            returnTo = "/dashboard"
        }
        
        do {
            // Use the auth service to login the user
            let authResponse = try await req.services.authService.login(loginRequest)
            
            // Check if this is an API call or a web request
            if req.headers.accept.first?.mediaType == .json {
                // API call, return JSON response
                return try await authResponse.encodeResponse(for: req)
            } else {
                // Web request, set cookie and redirect to the returnTo path or dashboard
                // Use 302 Found instead of 303 See Other for better browser compatibility
                let response = Response(status: .found)
                response.headers.replaceOrAdd(name: .location, value: returnTo)
                
                // Only set secure flag in production environment
                let isSecure = req.application.environment == .production
                
                response.cookies["bandera-auth-token"] = .init(
                    string: authResponse.token,
                    expires: Date().addingTimeInterval(7 * 86400), // 7 days instead of 24 hours
                    path: "/", // Ensure cookie is available for all paths
                    isSecure: isSecure, // Only secure in production
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
                // Web request, redirect to login page with error and returnTo parameter
                let errorMessage = (error as? any BanderaErrorProtocol)?.reason ?? "Invalid credentials"
                let encodedError = errorMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedReturnTo = returnTo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                
                // Use 302 Found instead of 303 See Other for better browser compatibility
                let response = Response(status: .found)
                response.headers.replaceOrAdd(name: .location, value: "/auth/login?error=\(encodedError)&returnTo=\(encodedReturnTo)")
                return response
            }
        }
    }
    
    // Logout endpoint
    @Sendable
    func logout(req: Request) async throws -> Response {
        // Clear the auth cookie
        // Use 302 Found instead of 303 See Other for better browser compatibility
        let response = Response(status: .found)
        response.headers.replaceOrAdd(name: .location, value: "/auth/login")
        
        // Only set secure flag in production environment
        let isSecure = req.application.environment == .production
        
        response.cookies["bandera-auth-token"] = .init(
            string: "",
            expires: Date().addingTimeInterval(-86400), // Expired
            path: "/", // Ensure cookie is cleared for all paths
            isSecure: isSecure, // Only secure in production
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
