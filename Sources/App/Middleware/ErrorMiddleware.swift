import Vapor

/// Custom error handling middleware for the Bandera application.
///
/// This middleware intercepts all errors thrown during request processing
/// and converts them to appropriate HTTP responses. It provides different
/// response formats based on the client's Accept header (JSON, HTML, or plain text).
/// It also logs errors for debugging and monitoring purposes.
struct BanderaErrorMiddleware: AsyncMiddleware {
    /// The environment to respect when presenting errors
    let environment: Environment
    
    /// Creates a new `BanderaErrorMiddleware`.
    /// - Parameter environment: The environment to respect when presenting errors.
    init(environment: Environment) {
        self.environment = environment
    }
    
    /// Process the request and handle any errors that occur.
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the chain
    /// - Returns: The HTTP response
    /// - Throws: Any error that wasn't handled
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            // Log the error with appropriate severity based on the error type
            self.logError(error, for: request)
            
            // Convert the error to a response
            let response = await self.buildErrorResponse(for: request, with: error)
            
            // Return the response
            return response
        }
    }
    
    /// Logs the error with appropriate severity based on the error type.
    /// - Parameters:
    ///   - error: The error to log
    ///   - request: The request that caused the error
    private func logError(_ error: Error, for request: Request) {
        // Determine log level based on error type and status code
        let logLevel: Logger.Level
        let statusCode: UInt
        let errorDomain: String?
        
        // Handle different error types
        if let banderaError = error as? any BanderaErrorProtocol {
            statusCode = banderaError.status.code
            errorDomain = banderaError.domain.rawValue
        } else if let abort = error as? AbortError {
            statusCode = abort.status.code
            errorDomain = nil
        } else {
            statusCode = HTTPStatus.internalServerError.code
            errorDomain = nil
        }
        
        // Set log level based on status code
        switch statusCode {
        case 400..<500:
            // Client errors (4xx) are warnings
            logLevel = .warning
        case 500..<600:
            // Server errors (5xx) are errors
            logLevel = .error
        default:
            // Other status codes are notices
            logLevel = .notice
        }
        
        // Create log metadata
        var metadata: Logger.Metadata = [
            "error_type": .string(String(describing: type(of: error))),
            "status_code": .string(String(statusCode)),
            "path": .string(request.url.path)
        ]
        
        // Add error domain if available
        if let domain = errorDomain {
            metadata["error_domain"] = .string(domain)
        }
        
        // Add request ID if available
        if let requestId = request.headers.first(name: "X-Request-ID") {
            metadata["request_id"] = .string(requestId)
        }
        
        // Add user ID if authenticated
        if let user = request.auth.get(UserJWTPayload.self) {
            metadata["user_id"] = .string(user.subject.value)
        }
        
        // Log the error with appropriate level and metadata
        request.logger.log(
            level: logLevel,
            "Request failed with error: \(error.localizedDescription)",
            metadata: metadata
        )
        
        // For server errors, also report the full error details
        if statusCode >= 500 {
            request.logger.report(error: error)
        }
    }
    
    /// Builds a response for an error.
    /// - Parameters:
    ///   - request: The request that caused the error
    ///   - error: The error to build a response for
    /// - Returns: The HTTP response
    private func buildErrorResponse(for request: Request, with error: Error) async -> Response {
        // Handle different error types
        var status: HTTPStatus
        var reason: String
        var headers: HTTPHeaders = [:]
        var recoverySuggestion: String?
        
        // Handle different error types
        if let banderaError = error as? any BanderaErrorProtocol {
            status = banderaError.status
            reason = banderaError.reason
            headers = banderaError.headers
            recoverySuggestion = banderaError.recoverySuggestion
        } else if let abort = error as? AbortError {
            status = abort.status
            reason = abort.reason
            headers = abort.headers
        } else {
            status = .internalServerError
            reason = "Something went wrong."
        }
        
        // Create a response with the appropriate status
        let response = Response(status: status, headers: headers)
        
        // Get the request ID if available
        let requestId = request.headers.first(name: "X-Request-ID")
        
        // Determine the response format based on the Accept header
        let accept = request.headers[.accept].first ?? "application/json"
        
        if accept.contains("text/html") {
            // HTML response
            return await self.buildHTMLResponse(request, response, reason: reason, suggestion: recoverySuggestion, requestId: requestId, error: error)
        } else if accept.contains("application/json") {
            // JSON response
            return self.buildJSONResponse(response, reason: reason, suggestion: recoverySuggestion, requestId: requestId, error: error)
        } else {
            // Plain text response
            return self.buildTextResponse(response, reason: reason, suggestion: recoverySuggestion)
        }
    }
    
    // MARK: - Response Builders
    
    /// Builds an HTML response for an error.
    /// - Parameters:
    ///   - request: The request that caused the error
    ///   - response: The base response
    ///   - reason: The reason for the error
    ///   - suggestion: Optional recovery suggestion
    ///   - requestId: Optional request ID
    ///   - error: The original error
    /// - Returns: The HTML response
    private func buildHTMLResponse(_ request: Request, _ response: Response, reason: String, suggestion: String?, requestId: String?, error: Error) async -> Response {
        // Handle authentication errors by redirecting to login
        if error is AuthenticationError {
            let currentPath = request.url.path
            let encodedPath = currentPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return request.redirect(to: "/auth/login?returnTo=\(encodedPath)")
        }
        
        // Handle 404 errors by showing the 404 page instead of redirecting to login
        if response.status == .notFound {
            do {
                // Create base context for the 404 page
                let baseContext = BaseViewContext(
                    title: "Page Not Found",
                    isAuthenticated: request.auth.get(UserJWTPayload.self) != nil,
                    isAdmin: request.auth.get(UserJWTPayload.self)?.isAdmin ?? false,
                    user: try? await User.find(UUID(uuidString: request.auth.get(UserJWTPayload.self)?.subject.value ?? ""), on: request.db)
                )
                
                // Create error context
                let context = ErrorViewContext(
                    base: baseContext,
                    statusCode: 404,
                    reason: "The page you're looking for could not be found.",
                    recoverySuggestion: "Please check the URL and try again.",
                    returnTo: true
                )
                
                // Render the 404 page
                response.headers.contentType = .html
                return try await request.view.render("error", context).encodeResponse(for: request)
            } catch {
                // Fall back to the generic error page if rendering fails
            }
        }
        
        // Try to render the error page using Leaf
        do {
            // Get debug info in development
            let debugInfo: String?
            if self.environment == .development {
                debugInfo = String(describing: error)
            } else {
                debugInfo = nil
            }
            
            // Create base context
            let baseContext = BaseViewContext(
                title: "Error",
                isAuthenticated: request.auth.get(UserJWTPayload.self) != nil,
                isAdmin: request.auth.get(UserJWTPayload.self)?.isAdmin ?? false,
                user: try? await User.find(UUID(uuidString: request.auth.get(UserJWTPayload.self)?.subject.value ?? ""), on: request.db),
                errorMessage: reason,
                warningMessage: suggestion
            )
            
            // Create error context
            let context = ErrorViewContext(
                base: baseContext,
                statusCode: response.status.code,
                reason: reason,
                recoverySuggestion: suggestion,
                requestId: requestId,
                debugInfo: debugInfo,
                returnTo: true
            )
            
            // Render the error page
            response.headers.contentType = .html
            return try await request.view.render("error", context).encodeResponse(for: request)
        } catch {
            // If rendering fails, return a basic HTML error page
            response.headers.contentType = .html
            response.body = .init(string: """
                <!DOCTYPE html>
                <html>
                    <head>
                        <title>Error</title>
                    </head>
                    <body>
                        <h1>Error</h1>
                        <p>\(reason)</p>
                        \(suggestion.map { "<p>\($0)</p>" } ?? "")
                    </body>
                </html>
                """)
            return response
        }
    }
    
    /// Builds a JSON response for an error.
    /// - Parameters:
    ///   - response: The base response
    ///   - reason: The reason for the error
    ///   - suggestion: Optional recovery suggestion
    ///   - requestId: Optional request ID
    ///   - error: The original error
    /// - Returns: The JSON response
    private func buildJSONResponse(_ response: Response, reason: String, suggestion: String?, requestId: String?, error: Error) -> Response {
        // Create error response
        var errorResponse = ErrorResponse(
            error: true,
            reason: reason,
            statusCode: response.status.code,
            recoverySuggestion: suggestion,
            requestId: requestId
        )
        
        // Add debug info in development
        if environment == .development {
            errorResponse.debugInfo = String(describing: error)
        }
        
        // Encode the response
        do {
            response.headers.contentType = .json
            response.body = try .init(data: JSONEncoder().encode(errorResponse))
            return response
        } catch {
            // Fall back to plain text if encoding fails
            return buildTextResponse(response, reason: reason, suggestion: suggestion)
        }
    }
    
    /// Builds a plain text response for an error.
    /// - Parameters:
    ///   - response: The base response
    ///   - reason: The reason for the error
    ///   - suggestion: Optional recovery suggestion
    /// - Returns: The plain text response
    private func buildTextResponse(_ response: Response, reason: String, suggestion: String?) -> Response {
        // Create plain text message
        var message = "Error \(response.status.code): \(reason)"
        
        // Add suggestion if available
        if let suggestion = suggestion {
            message += "\n\n\(suggestion)"
        }
        
        response.body = .init(string: message)
        response.headers.contentType = .plainText
        return response
    }
    
    /// Formats a Codable decoding error into a user-friendly message.
    /// - Parameter error: The decoding error
    /// - Returns: A user-friendly error message
    private func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Required field missing: \(key.stringValue)"
        case .valueNotFound(_, let context):
            return "Required value missing at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .typeMismatch(_, let context):
            return "Invalid type at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Invalid data format: \(context.debugDescription)"
        @unknown default:
            return "Invalid data format"
        }
    }
}

/// Response structure for JSON error responses
private struct ErrorResponse: Content {
    /// Always true to indicate this is an error
    let error: Bool
    
    /// The reason for the error
    let reason: String
    
    /// The HTTP status code
    let statusCode: UInt
    
    /// Optional recovery suggestion
    var recoverySuggestion: String?
    
    /// Optional request ID for tracking
    var requestId: String?
    
    /// Debug information (only included in development)
    var debugInfo: String?
}

// MARK: - Application Extensions

extension Application {
    /// Register the custom error middleware
    func registerErrorMiddleware() {
        // Add our custom error middleware
        let errorMiddleware = BanderaErrorMiddleware(environment: self.environment)
        self.middleware.use(errorMiddleware)
    }
} 