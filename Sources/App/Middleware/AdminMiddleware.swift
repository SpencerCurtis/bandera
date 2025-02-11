import Vapor

struct AdminMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.logger.debug("AdminMiddleware: Starting authentication check")
        
        // Try to get the payload from the auth session first
        if let payload = request.auth.get(UserJWTPayload.self) {
            request.logger.debug("Found payload in auth session: subject=\(payload.subject.value), isAdmin=\(payload.isAdmin)")
            guard payload.isAdmin else {
                request.logger.debug("User in session is not admin")
                throw Abort(.forbidden, reason: "Admin access required")
            }
            return try await next.respond(to: request)
        }
        
        // If not in session, try to get from cookie
        if let token = request.cookies["vapor-auth-token"]?.string {
            request.logger.debug("Found token in cookie")
            do {
                let payload = try request.jwt.verify(token, as: UserJWTPayload.self)
                request.logger.debug("Verified JWT token: subject=\(payload.subject.value), isAdmin=\(payload.isAdmin)")
                
                guard payload.isAdmin else {
                    request.logger.debug("User from token is not admin")
                    throw Abort(.forbidden, reason: "Admin access required")
                }
                
                // Store in auth session for future requests
                request.auth.login(payload)
                return try await next.respond(to: request)
            } catch {
                request.logger.debug("Failed to verify JWT token: \(error)")
                throw Abort(.unauthorized)
            }
        }
        
        request.logger.debug("No valid authentication found")
        throw Abort(.unauthorized)
    }
} 