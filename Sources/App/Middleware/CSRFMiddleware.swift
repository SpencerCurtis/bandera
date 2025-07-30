import Vapor
import Foundation

/// CSRF protection middleware that generates and validates CSRF tokens
/// Protects against Cross-Site Request Forgery attacks on web forms
final class CSRFMiddleware: AsyncMiddleware {
    
    // MARK: - Configuration
    
    /// Configuration for CSRF protection
    struct Configuration {
        /// The session key where CSRF tokens are stored
        let sessionKey: String
        
        /// The form field name for CSRF tokens
        let fieldName: String
        
        /// The header name for CSRF tokens (for AJAX requests)
        let headerName: String
        
        /// Methods that require CSRF protection
        let protectedMethods: [HTTPMethod]
        
        /// Paths to exclude from CSRF protection (e.g., API endpoints)
        let excludedPaths: [String]
        
        /// Token lifetime in seconds
        let tokenLifetime: TimeInterval
        
        /// Default configuration
        static let `default` = Configuration(
            sessionKey: "csrf_token",
            fieldName: "csrf_token",
            headerName: "X-CSRF-Token",
            protectedMethods: [.POST, .PUT, .PATCH, .DELETE],
            excludedPaths: ["/api/"], // Exclude API routes that use JWT
            tokenLifetime: 3600 // 1 hour
        )
    }
    
    private let configuration: Configuration
    private let logger: Logger
    
    // MARK: - Initialization
    
    init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.logger = Logger(label: "csrf-middleware")
    }
    
    // MARK: - Middleware Implementation
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Skip CSRF protection for excluded paths
        if shouldExcludePath(request.url.path) {
            return try await next.respond(to: request)
        }
        
        // Generate or validate CSRF token based on HTTP method
        if configuration.protectedMethods.contains(request.method) {
            try await validateCSRFToken(request)
        } else {
            // For safe methods (GET, HEAD, OPTIONS), ensure a token exists
            try await ensureCSRFToken(request)
        }
        
        // Continue to next middleware
        let response = try await next.respond(to: request)
        
        // For HTML responses to safe methods, ensure CSRF token is available for forms
        if request.method == .GET && isHTMLResponse(response) {
            try await ensureCSRFToken(request)
        }
        
        return response
    }
    
    // MARK: - CSRF Token Management
    
    /// Generates a new CSRF token and stores it in the session
    private func generateCSRFToken(_ request: Request) throws -> String {
        let token = [UInt8].random(count: 32).base64
        
        // Store token with timestamp
        let tokenData = CSRFTokenData(
            token: token,
            createdAt: Date()
        )
        
        request.session.data[configuration.sessionKey] = try tokenData.encoded()
        logger.debug("Generated new CSRF token for session")
        
        return token
    }
    
    /// Retrieves the current CSRF token from the session
    private func getCurrentCSRFToken(_ request: Request) throws -> String? {
        guard let tokenDataString = request.session.data[configuration.sessionKey],
              let tokenData = try? CSRFTokenData.decoded(from: tokenDataString) else {
            return nil
        }
        
        // Check if token has expired
        if Date().timeIntervalSince(tokenData.createdAt) > configuration.tokenLifetime {
            logger.debug("CSRF token expired, will generate new one")
            request.session.data[configuration.sessionKey] = nil
            return nil
        }
        
        return tokenData.token
    }
    
    /// Ensures a CSRF token exists, generating one if necessary
    private func ensureCSRFToken(_ request: Request) async throws {
        if try getCurrentCSRFToken(request) == nil {
            let _ = try generateCSRFToken(request)
        }
    }
    
    /// Validates the CSRF token from the request
    private func validateCSRFToken(_ request: Request) async throws {
        guard let expectedToken = try getCurrentCSRFToken(request) else {
            logger.warning("No CSRF token found in session")
            throw CSRFError.missingToken
        }
        
        // Try to get token from form field first, then header
        let submittedToken = try getSubmittedToken(request)
        
        guard let token = submittedToken else {
            logger.warning("No CSRF token provided in request")
            throw CSRFError.missingToken
        }
        
        // Use timing-safe comparison
        guard secureCompare(expectedToken, token) else {
            logger.warning("CSRF token mismatch")
            throw CSRFError.invalidToken
        }
        
        logger.debug("CSRF token validation successful")
    }
    
    /// Extracts the submitted CSRF token from form data or headers
    private func getSubmittedToken(_ request: Request) throws -> String? {
        // Try form field first
        if let formToken = try? request.content.get(String.self, at: configuration.fieldName) {
            return formToken
        }
        
        // Try header for AJAX requests
        if let headerToken = request.headers.first(name: configuration.headerName) {
            return headerToken
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Checks if a path should be excluded from CSRF protection
    private func shouldExcludePath(_ path: String) -> Bool {
        return configuration.excludedPaths.contains { excludedPath in
            path.hasPrefix(excludedPath)
        }
    }
    
    /// Checks if the response is HTML content
    private func isHTMLResponse(_ response: Response) -> Bool {
        guard let contentType = response.headers.contentType else { return false }
        return contentType.type == "text" && contentType.subType == "html"
    }
    
    /// Performs timing-safe string comparison to prevent timing attacks
    private func secureCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        
        var result = 0
        for i in 0..<aBytes.count {
            result |= Int(aBytes[i] ^ bBytes[i])
        }
        
        return result == 0
    }
}

// MARK: - CSRF Token Data

/// Structure to store CSRF token with metadata
private struct CSRFTokenData: Codable {
    let token: String
    let createdAt: Date
    
    func encoded() throws -> String {
        let data = try JSONEncoder().encode(self)
        return data.base64EncodedString()
    }
    
    static func decoded(from string: String) throws -> CSRFTokenData {
        guard let data = Data(base64Encoded: string) else {
            throw CSRFError.invalidTokenData
        }
        return try JSONDecoder().decode(CSRFTokenData.self, from: data)
    }
}

// MARK: - CSRF Errors

/// Errors related to CSRF protection
enum CSRFError: Error, AbortError {
    case missingToken
    case invalidToken
    case invalidTokenData
    
    var reason: String {
        switch self {
        case .missingToken:
            return "CSRF token is missing. This request appears to be a Cross-Site Request Forgery attempt."
        case .invalidToken:
            return "Invalid CSRF token. This request appears to be a Cross-Site Request Forgery attempt."
        case .invalidTokenData:
            return "Corrupted CSRF token data."
        }
    }
    
    var status: HTTPResponseStatus {
        return .forbidden
    }
}

// MARK: - Request Extension

extension Request {
    /// Gets the current CSRF token for use in templates
    var csrfToken: String {
        do {
            // Try to get existing token
            if let tokenDataString = session.data["csrf_token"],
               let tokenData = try? CSRFTokenData.decoded(from: tokenDataString) {
                return tokenData.token
            }
            
            // Generate new token if none exists
            let token = [UInt8].random(count: 32).base64
            let tokenData = CSRFTokenData(token: token, createdAt: Date())
            session.data["csrf_token"] = try tokenData.encoded()
            return token
        } catch {
            // Fallback: generate a simple token
            let token = [UInt8].random(count: 32).base64
            session.data["csrf_token"] = token
            return token
        }
    }
} 