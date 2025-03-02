import Vapor

/// Custom error handling middleware for the Bandera application
struct BanderaErrorMiddleware: AsyncMiddleware {
    /// The environment to respect when presenting errors
    let environment: Environment
    
    /// Creates a new `BanderaErrorMiddleware`.
    /// - Parameter environment: The environment to respect when presenting errors.
    init(environment: Environment) {
        self.environment = environment
    }
    
    /// See `AsyncMiddleware.respond(to:chainingTo:)`.
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            // Log the error
            request.logger.report(error: error)
            
            // Convert the error to a response
            let response = await self.buildErrorResponse(for: request, with: error)
            
            // Return the response
            return response
        }
    }
    
    /// Builds a response for an error.
    /// - Parameters:
    ///   - request: The request that caused the error.
    ///   - error: The error itself.
    /// - Returns: A response representing the error.
    private func buildErrorResponse(for request: Request, with error: Error) async -> Response {
        // Determine if this is an Abort error
        let status: HTTPStatus
        let reason: String
        let headers: HTTPHeaders
        
        switch error {
        case let abort as AbortError:
            // This is an abort error, use its status, reason, and headers
            reason = abort.reason
            status = abort.status
            headers = abort.headers
        case let banderaError as BanderaError:
            // This is a BanderaError, use its status and reason
            reason = banderaError.reason
            status = banderaError.status
            headers = [:]
        default:
            // For any other error, return a 500 Internal Server Error
            reason = self.environment.isRelease
                ? "Something went wrong"
                : String(describing: error)
            status = .internalServerError
            headers = [:]
        }
        
        // Create a Response with appropriate status
        let response = Response(status: status, headers: headers)
        
        // Determine the best response type based on the request's Accept header
        if request.headers.accept.contains(where: { $0.mediaType == .json }) {
            // Return a JSON response
            do {
                let errorResponse = ErrorResponse(
                    error: true,
                    reason: reason,
                    statusCode: status.code
                )
                response.body = try .init(data: JSONEncoder().encode(errorResponse))
                response.headers.contentType = .json
                return response
            } catch {
                // If encoding fails, fall back to a plain text response
                response.body = .init(string: reason)
                response.headers.contentType = .plainText
                return response
            }
        } else if request.headers.accept.contains(where: { $0.mediaType == .html }) {
            // For HTML requests, try to render an error page
            do {
                let errorContext = ViewContext(
                    title: "Error \(status.code)",
                    error: reason
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
                response.body = .init(string: reason)
                response.headers.contentType = .plainText
                return response
            }
        } else {
            // Default to a plain text response
            response.body = .init(string: reason)
            response.headers.contentType = .plainText
            return response
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