import Vapor
import JWT

// Custom middleware to extract JWT from cookie and authenticate user
struct JWTCookieMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check for JWT in cookie
        if let token = request.cookies["vapor-auth-token"]?.string {
            // Try to verify and decode the JWT
            do {
                let payload = try request.application.jwt.signers.verify(token, as: UserJWTPayload.self)
                // Set the payload in the auth cache
                request.auth.login(payload)
                request.logger.debug("JWT cookie authentication successful: \(payload.subject.value)")
            } catch {
                request.logger.debug("JWT cookie verification failed: \(error)")
            }
        }
        
        return try await next.respond(to: request)
    }
} 