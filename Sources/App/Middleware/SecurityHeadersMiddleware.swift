import Vapor

/// Middleware that adds security headers to HTTP responses
/// Implements OWASP security best practices for web applications
final class SecurityHeadersMiddleware: AsyncMiddleware {
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        
        // Only add security headers to HTML responses and web routes
        let isWebRoute = !request.url.path.hasPrefix("/api/")
        
        if isWebRoute {
            // Prevent MIME type sniffing
            response.headers.replaceOrAdd(name: .contentTypeOptions, value: "nosniff")
            
            // Prevent clickjacking attacks
            response.headers.replaceOrAdd(name: .xFrameOptions, value: "DENY")
            
            // Enable XSS protection in browsers
            response.headers.replaceOrAdd(name: .xXSSProtection, value: "1; mode=block")
            
            // Only load resources over HTTPS in production
            if request.application.environment.isRelease {
                response.headers.replaceOrAdd(name: .strictTransportSecurity, value: "max-age=31536000; includeSubDomains")
            }
            
            // Referrer policy for privacy
            response.headers.replaceOrAdd(name: .referrerPolicy, value: "strict-origin-when-cross-origin")
            
            // Content Security Policy (basic policy for now)
            let csp = [
                "default-src 'self'",
                "script-src 'self' 'unsafe-inline'", // Allow inline scripts for now
                "style-src 'self' 'unsafe-inline'",  // Allow inline styles for now
                "img-src 'self' data:",
                "font-src 'self'",
                "connect-src 'self'",
                "frame-ancestors 'none'"
            ].joined(separator: "; ")
            
            response.headers.replaceOrAdd(name: .contentSecurityPolicy, value: csp)
        }
        
        return response
    }
}

// MARK: - HTTPHeaders Extensions

extension HTTPHeaders.Name {
    static let contentTypeOptions = HTTPHeaders.Name("X-Content-Type-Options")
    static let xFrameOptions = HTTPHeaders.Name("X-Frame-Options")
    static let xXSSProtection = HTTPHeaders.Name("X-XSS-Protection")
    static let strictTransportSecurity = HTTPHeaders.Name("Strict-Transport-Security")
    static let referrerPolicy = HTTPHeaders.Name("Referrer-Policy")
    static let contentSecurityPolicy = HTTPHeaders.Name("Content-Security-Policy")
} 