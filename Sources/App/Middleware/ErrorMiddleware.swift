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
        
        if let abort = error as? AbortError {
            statusCode = abort.status.code
        } else if let banderaError = error as? BanderaError {
            statusCode = banderaError.status.code
        } else {
            statusCode = HTTPStatus.internalServerError.code
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
    ///   - request: The request that caused the error.
    ///   - error: The error itself.
    /// - Returns: A response representing the error.
    private func buildErrorResponse(for request: Request, with error: Error) async -> Response {
        // Determine error details
        let status: HTTPStatus
        let reason: String
        let headers: HTTPHeaders
        let recoverySuggestion: String?
        
        switch error {
        case let abort as AbortError:
            // This is an abort error, use its status, reason, and headers
            reason = abort.reason
            status = abort.status
            headers = abort.headers
            recoverySuggestion = nil
            
        case let banderaError as BanderaError:
            // This is a BanderaError, use its status, reason, and headers
            reason = banderaError.reason
            status = banderaError.status
            headers = banderaError.headers
            recoverySuggestion = banderaError.recoverySuggestion
            
        case let validationError as ValidationsError:
            // This is a validation error from Vapor's validator
            let errors = validationError.failures.map { "\($0.key): \($0.result.failureDescription ?? "Invalid value")" }
            let errorMessage = errors.joined(separator: ", ")
            reason = "Validation failed: \(errorMessage)"
            status = .badRequest
            headers = [:]
            recoverySuggestion = "Please check your input and try again."
            
        case let decodingError as DecodingError:
            // This is a decoding error from Codable
            reason = self.formatDecodingError(decodingError)
            status = .badRequest
            headers = [:]
            recoverySuggestion = "Please check your input format and try again."
            
        default:
            // For any other error, return a 500 Internal Server Error
            // In production, hide the actual error details
            reason = self.environment.isRelease
                ? "An internal server error occurred"
                : String(describing: error)
            status = .internalServerError
            headers = [:]
            recoverySuggestion = "Please try again later or contact support if the problem persists."
        }
        
        // Create a Response with appropriate status and headers
        var response = Response(status: status)
        response.headers = headers
        
        // Determine the best response type based on the request's Accept header
        if request.headers.accept.contains(where: { $0.mediaType == .json }) {
            // Return a JSON response
            return self.createJSONErrorResponse(
                status: status,
                reason: reason,
                recoverySuggestion: recoverySuggestion,
                request: request,
                error: error
            )
        } else if request.headers.accept.contains(where: { $0.mediaType == .html }) {
            // For HTML requests, try to render an error page
            return await self.createHTMLErrorResponse(
                status: status,
                reason: reason,
                recoverySuggestion: recoverySuggestion,
                request: request
            )
        } else {
            // Default to a plain text response
            return self.createPlainTextErrorResponse(
                status: status,
                reason: reason,
                recoverySuggestion: recoverySuggestion
            )
        }
    }
    
    /// Creates a JSON error response.
    /// - Parameters:
    ///   - status: The HTTP status code
    ///   - reason: The error reason
    ///   - recoverySuggestion: Optional recovery suggestion
    ///   - request: The request that caused the error
    ///   - error: The original error
    /// - Returns: A JSON response
    private func createJSONErrorResponse(
        status: HTTPStatus,
        reason: String,
        recoverySuggestion: String?,
        request: Request,
        error: Error
    ) -> Response {
        var response = Response(status: status)
        
        do {
            // Create the error response object
            var errorResponse = ErrorResponse(
                error: true,
                reason: reason,
                statusCode: status.code
            )
            
            // Add recovery suggestion if available
            if let suggestion = recoverySuggestion {
                errorResponse.recoverySuggestion = suggestion
            }
            
            // Add request ID if available
            if let requestId = request.headers.first(name: "X-Request-ID") {
                errorResponse.requestId = requestId
            }
            
            // Add stack trace in development mode
            if !self.environment.isRelease {
                errorResponse.debugInfo = String(describing: error)
            }
            
            // Encode the response
            response.body = try .init(data: JSONEncoder().encode(errorResponse))
            response.headers.contentType = .json
            return response
        } catch {
            // If encoding fails, fall back to a plain text response
            return self.createPlainTextErrorResponse(
                status: status,
                reason: reason,
                recoverySuggestion: recoverySuggestion
            )
        }
    }
    
    /// Creates an HTML error response.
    /// - Parameters:
    ///   - status: The HTTP status code
    ///   - reason: The error reason
    ///   - recoverySuggestion: Optional recovery suggestion
    ///   - request: The request that caused the error
    /// - Returns: An HTML response
    private func createHTMLErrorResponse(
        status: HTTPStatus,
        reason: String,
        recoverySuggestion: String?,
        request: Request
    ) async -> Response {
        var response = Response(status: status)
        
        do {
            // Create the error context for the template
            let errorContext = ViewContextDTOs.BaseContext(
                title: "Error \(status.code)",
                error: reason,
                recoverySuggestion: recoverySuggestion
            )
            
            // Try to render the error page
            let viewFuture = request.view.render("error", errorContext)
            response.headers.contentType = .html
            
            // Convert the view to a string and set it as the response body
            let viewString = try await viewFuture.get().data.getString(at: 0, length: viewFuture.get().data.readableBytes)
            response.body = .init(string: viewString ?? reason)
            
            return response
        } catch {
            // If rendering fails, fall back to a plain text response
            return self.createPlainTextErrorResponse(
                status: status,
                reason: reason,
                recoverySuggestion: recoverySuggestion
            )
        }
    }
    
    /// Creates a plain text error response.
    /// - Parameters:
    ///   - status: The HTTP status code
    ///   - reason: The error reason
    ///   - recoverySuggestion: Optional recovery suggestion
    /// - Returns: A plain text response
    private func createPlainTextErrorResponse(
        status: HTTPStatus,
        reason: String,
        recoverySuggestion: String?
    ) -> Response {
        var response = Response(status: status)
        
        // Build the error message
        var message = "Error \(status.code): \(reason)"
        
        // Add recovery suggestion if available
        if let suggestion = recoverySuggestion {
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