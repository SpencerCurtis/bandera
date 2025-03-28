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
        // Clear any potentially invalid tokens
        req.session.data["user_id"] = nil
        req.session.data["is_admin"] = nil
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Login",
            isAuthenticated: false
        )
        
        // Create login-specific context
        let context = LoginViewContext(
            base: baseContext,
            returnTo: req.query["returnTo"]
        )
        
        // Simply render the login page
        return try await req.view.render("login", context)
    }
    
    /// Render the signup page
    @Sendable
    static func signupPage(req: Request) async throws -> View {
        // Create base context
        let baseContext = BaseViewContext(
            title: "Sign Up",
            isAuthenticated: false
        )
        
        // Create register-specific context
        let context = RegisterViewContext(base: baseContext)
        
        return try await req.view.render("signup", context)
    }
    
    /// Handle user signup
    @Sendable
    static func signup(req: Request) async throws -> Response {
        do {
            // Validate the request
            try RegisterRequest.validate(content: req)
            let registerRequest = try req.content.decode(RegisterRequest.self)
            
            // Check if user already exists
            if try await User.query(on: req.db)
                .filter(\.$email == registerRequest.email)
                .first() != nil {
                // Create error context
                let baseContext = BaseViewContext(
                    title: "Sign Up",
                    isAuthenticated: false,
                    errorMessage: "A user with this email already exists"
                )
                let context = RegisterViewContext.failedRegistration(base: baseContext)
                return try await req.view.render("signup", context).encodeResponse(for: req)
            }
            
            // Create and save the user
            let user = try User.create(from: registerRequest)
            try await user.save(on: req.db)
            
            // Create personal organization for the user
            let personalOrgName = "\(registerRequest.email.split(separator: "@").first?.trimmingCharacters(in: .whitespaces) ?? "User")'s Personal Organization"
            let organizationService = try req.organizationService()
            let personalOrg = try await organizationService.create(
                CreateOrganizationRequest(name: personalOrgName),
                creatorId: user.id!
            )
            req.logger.info("Created personal organization \(personalOrg.id!) for user \(user.id!)")
            
            // Authenticate user for the current request
            req.auth.login(user)
            
            // Set session data
            req.session.data["user_id"] = user.id?.uuidString
            req.session.data["is_admin"] = String(user.isAdmin)
            
            // Create JWT payload and token
            let payload = try UserJWTPayload(user: user)
            let token = try req.jwt.sign(payload)
            
            // Set the token cookie
            let response = req.redirect(to: "/dashboard")
            response.cookies["bandera-auth-token"] = HTTPCookies.Value(
                string: token,
                expires: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
                domain: nil,
                path: "/",
                isSecure: req.application.environment.isRelease,
                isHTTPOnly: true,
                sameSite: .lax
            )
            
            return response
        } catch {
            // Create error context
            let baseContext = BaseViewContext(
                title: "Sign Up",
                isAuthenticated: false,
                errorMessage: error.localizedDescription
            )
            let context = RegisterViewContext.failedRegistration(base: baseContext)
            return try await req.view.render("signup", context).encodeResponse(for: req)
        }
    }
    
    /// Handle user login
    @Sendable
    static func login(req: Request) async throws -> Response {
        do {
            req.logger.debug("AuthController.login: Processing login request")
            try LoginRequest.validate(content: req)
            let loginRequest = try req.content.decode(LoginRequest.self)
            
            // Debug the login credentials
            req.logger.debug("AuthController.login: Login attempt with email: \(loginRequest.email)")
            
            guard let user = try await User.query(on: req.db)
                .filter(\.$email == loginRequest.email)
                .first() else {
                req.logger.warning("AuthController.login: User not found with email: \(loginRequest.email)")
                
                // Create error context
                let baseContext = BaseViewContext(
                    title: "Login",
                    isAuthenticated: false,
                    errorMessage: "Invalid email or password"
                )
                let context = LoginViewContext.failedLogin(
                    base: baseContext,
                    returnTo: try? req.content.get(String.self, at: "returnTo")
                )
                return try await req.view.render("login", context).encodeResponse(for: req)
            }
            
            req.logger.debug("AuthController.login: Found user with ID: \(user.id?.uuidString ?? "nil")")
            
            guard try user.verify(password: loginRequest.password) else {
                req.logger.warning("AuthController.login: Password verification failed for user: \(loginRequest.email)")
                
                // Create error context
                let baseContext = BaseViewContext(
                    title: "Login",
                    isAuthenticated: false,
                    errorMessage: "Invalid email or password"
                )
                let context = LoginViewContext.failedLogin(
                    base: baseContext,
                    returnTo: try? req.content.get(String.self, at: "returnTo")
                )
                return try await req.view.render("login", context).encodeResponse(for: req)
            }
            
            req.logger.debug("AuthController.login: Password verification succeeded")
            
            // Authenticate user for the current request
            req.auth.login(user)
            req.logger.debug("AuthController.login: User authenticated in auth container")
            
            // Set session data
            req.session.data["user_id"] = user.id?.uuidString
            req.session.data["is_admin"] = String(user.isAdmin)
            req.logger.debug("AuthController.login: Set session data: user_id=\(user.id?.uuidString ?? "nil"), is_admin=\(user.isAdmin)")
            
            // Create response with redirect
            let redirectTo = (try? req.content.get(String.self, at: "returnTo")) ?? "/dashboard"
            let response = req.redirect(to: redirectTo)
            req.logger.debug("AuthController.login: Created redirect response to \(redirectTo)")
            
            // Create JWT payload directly from user model
            let payload = try UserJWTPayload(user: user)
            req.logger.debug("AuthController.login: Created JWT payload with subject: \(payload.subject.value)")
            
            let token = try req.jwt.sign(payload)
            
            // Debug the JWT token being set
            req.logger.debug("AuthController.login: Signed JWT token for user \(user.email): \(token.prefix(20))...")
            
            // Set the token cookie with detailed debug info
            response.cookies["bandera-auth-token"] = HTTPCookies.Value(
                string: token,
                expires: Date().addingTimeInterval(7 * 24 * 60 * 60),
                domain: nil,
                path: "/",
                isSecure: req.application.environment != .development,
                isHTTPOnly: true,
                sameSite: .lax
            )
            
            req.logger.debug("AuthController.login: Set cookie 'bandera-auth-token' with expiry: \(Date().addingTimeInterval(7 * 24 * 60 * 60))")
            req.logger.debug("AuthController.login: Login process completed successfully")
            
            return response
        } catch {
            req.logger.error("AuthController.login: Error during login: \(error)")
            
            // Create error context
            let baseContext = BaseViewContext(
                title: "Login",
                isAuthenticated: false,
                errorMessage: error.localizedDescription
            )
            let context = LoginViewContext.failedLogin(
                base: baseContext,
                returnTo: try? req.content.get(String.self, at: "returnTo")
            )
            return try await req.view.render("login", context).encodeResponse(for: req)
        }
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
