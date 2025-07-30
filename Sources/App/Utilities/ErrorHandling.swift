import Vapor
import Fluent

/// Utility functions for error handling.
///
/// This namespace contains utility functions for error handling,
/// including functions for converting common errors to domain-specific errors
/// and for handling specific error scenarios.
enum ErrorHandling {
    /// Converts a database error to a domain-specific error.
    ///
    /// - Parameter error: The database error to convert
    /// - Returns: A domain-specific error
    static func handleDatabaseError(_ error: Error) -> any BanderaErrorProtocol {
        if let dbError = error as? DatabaseError {
            // Handle generic database errors
            return dbError
        } else if let fluent = error as? FluentError {
            // Handle Fluent-specific errors
            return DatabaseError.operationFailed(fluent.localizedDescription)
        } else {
            // Handle other database errors
            return DatabaseError.operationFailed(error.localizedDescription)
        }
    }
    
    /// Handles a not found error for a specific resource.
    ///
    /// - Parameters:
    ///   - id: The ID of the resource that wasn't found
    ///   - resourceName: The name of the resource type
    /// - Returns: A domain-specific error
    static func handleNotFound<T: CustomStringConvertible>(id: T, resourceName: String) -> any BanderaErrorProtocol {
        return ResourceError.notFound("\(resourceName) with ID \(id)")
    }
    
    /// Handles an access denied error for a specific resource.
    ///
    /// - Parameters:
    ///   - id: The ID of the resource that access was denied to
    ///   - resourceName: The name of the resource type
    /// - Returns: A domain-specific error
    static func handleAccessDenied<T: CustomStringConvertible>(id: T, resourceName: String) -> any BanderaErrorProtocol {
        return AuthenticationError.insufficientPermissions
    }
    
    /// Handles a validation error for a specific field.
    ///
    /// - Parameters:
    ///   - field: The name of the field that failed validation
    ///   - reason: The reason for the validation failure
    /// - Returns: A domain-specific error
    static func handleValidationError(field: String, reason: String) -> any BanderaErrorProtocol {
        return ValidationError.failed("\(field): \(reason)")
    }
    
    /// Handles a resource already exists error.
    ///
    /// - Parameters:
    ///   - key: The key or identifier of the resource
    ///   - resourceName: The name of the resource type
    /// - Returns: A domain-specific error
    static func handleResourceExists(key: String, resourceName: String) -> any BanderaErrorProtocol {
        return ResourceError.alreadyExists("\(resourceName) with key '\(key)'")
    }
    
    /// Wraps a throwing operation with error handling.
    ///
    /// This function executes the provided operation and catches any errors,
    /// converting them to domain-specific errors where appropriate.
    ///
    /// - Parameter operation: The operation to execute
    /// - Returns: The result of the operation
    /// - Throws: A domain-specific error if the operation fails
    static func withErrorHandling<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as any BanderaErrorProtocol {
            // Already a domain-specific error, just rethrow
            throw error
        } catch let error as AbortError {
            // Convert AbortError to domain-specific error
            switch error.status.code {
            case AppConstants.HTTPStatusCodes.unauthorized:
                throw AuthenticationError.authenticationRequired
            case AppConstants.HTTPStatusCodes.forbidden:
                throw AuthenticationError.insufficientPermissions
            case AppConstants.HTTPStatusCodes.notFound:
                throw ResourceError.notFound(error.reason)
            case AppConstants.HTTPStatusCodes.conflict:
                throw ResourceError.alreadyExists(error.reason)
            default:
                throw ValidationError.failed(error.reason)
            }
        } catch let error as DecodingError {
            // Handle Codable decoding errors
            switch error {
            case .keyNotFound(let key, _):
                throw ValidationError.missingRequiredField(key.stringValue)
            case .valueNotFound(_, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                throw ValidationError.missingRequiredField(path)
            case .typeMismatch(_, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                throw ValidationError.invalidFormat(path, context.debugDescription)
            case .dataCorrupted(let context):
                throw ValidationError.failed(context.debugDescription)
            @unknown default:
                throw ValidationError.failed("Invalid data format")
            }
        } catch {
            // Handle any other errors as internal server errors
            if error is DatabaseError {
                throw handleDatabaseError(error)
            } else {
                throw ServerError.internal(error.localizedDescription)
            }
        }
    }
    
    /// Handle HTTP errors
    /// - Parameter error: The HTTP error to handle
    /// - Throws: A domain-specific error
    static func handleHTTPError(_ error: AbortError) throws {
        switch error.status.code {
        case AppConstants.HTTPStatusCodes.unauthorized:
            throw AuthenticationError.authenticationRequired
        case AppConstants.HTTPStatusCodes.forbidden:
            throw AuthenticationError.insufficientPermissions
        case AppConstants.HTTPStatusCodes.notFound:
            throw ResourceError.notFound(error.reason)
        case AppConstants.HTTPStatusCodes.tooManyRequests:
            throw RateLimitError.tooManyRequests
        default:
            throw error
        }
    }
}

// MARK: - View Context Factory Methods

extension ErrorHandling {
    /// Creates a standardized BaseViewContext for error scenarios
    /// - Parameters:
    ///   - request: The current request
    ///   - title: The page title (defaults to "Error")
    ///   - errorMessage: Optional error message to include
    ///   - warningMessage: Optional warning message to include
    /// - Returns: A properly configured BaseViewContext
    static func createBaseViewContext(
        for request: Request, 
        title: String = "Error",
        errorMessage: String? = nil,
        warningMessage: String? = nil
    ) async -> BaseViewContext {
        let user: User?
        if let payload = request.auth.get(UserJWTPayload.self),
           let userId = UUID(uuidString: payload.subject.value) {
            user = try? await User.find(userId, on: request.db)
        } else {
            user = nil
        }
        
        return BaseViewContext(
            title: title,
            isAuthenticated: request.auth.get(UserJWTPayload.self) != nil,
            isAdmin: request.auth.get(UserJWTPayload.self)?.isAdmin ?? false,
            user: user,
            errorMessage: errorMessage,
            warningMessage: warningMessage
        )
    }
    
    /// Creates a standardized ErrorViewContext
    /// - Parameters:
    ///   - request: The current request
    ///   - error: The error that occurred
    ///   - statusCode: Optional custom status code (defaults to error's status)
    ///   - returnTo: Whether to show return-to functionality
    ///   - title: Optional custom page title
    /// - Returns: A properly configured ErrorViewContext
    static func createErrorViewContext(
        for request: Request,
        error: Error,
        statusCode: UInt? = nil,
        returnTo: Bool = true,
        title: String = "Error"
    ) async -> ErrorViewContext {
        let banderaError = error as? (any BanderaErrorProtocol)
        let abortError = error as? AbortError
        
        let errorStatusCode = statusCode ?? banderaError?.status.code ?? abortError?.status.code ?? 500
        let reason = banderaError?.reason ?? abortError?.reason ?? "An error occurred"
        let suggestion = banderaError?.recoverySuggestion
        
        let baseContext = await createBaseViewContext(
            for: request,
            title: title,
            errorMessage: reason,
            warningMessage: suggestion
        )
        
        return ErrorViewContext(
            base: baseContext,
            statusCode: errorStatusCode,
            reason: reason,
            recoverySuggestion: suggestion,
            returnTo: returnTo
        )
    }
    
    /// Creates a standardized error response for web forms
    /// - Parameters:
    ///   - request: The current request
    ///   - template: The template to render
    ///   - error: The error that occurred
    ///   - contextFactory: A closure that creates the view context with error info
    /// - Returns: A Response with the rendered error template
    static func createFormErrorResponse<T: Content>(
        for request: Request,
        template: String,
        error: Error,
        contextFactory: (BaseViewContext) -> T
    ) async throws -> Response {
        let banderaError = error as? (any BanderaErrorProtocol)
        let abortError = error as? AbortError
        let errorMessage = banderaError?.reason ?? abortError?.reason ?? error.localizedDescription
        
        let baseContext = await createBaseViewContext(
            for: request,
            errorMessage: errorMessage
        )
        
        let context = contextFactory(baseContext)
        return try await request.view.render(template, context).encodeResponse(for: request)
    }
}

// MARK: - Request Extensions for Error Handling

extension Request {
    /// Creates a standardized error response view
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - statusCode: Optional custom status code
    ///   - returnTo: Whether to show return-to functionality
    ///   - title: Optional custom page title
    /// - Returns: A Response with the rendered error template
    func createErrorResponse(
        for error: Error,
        statusCode: UInt? = nil,
        returnTo: Bool = true,
        title: String = "Error"
    ) async throws -> Response {
        let context = await ErrorHandling.createErrorViewContext(
            for: self,
            error: error,
            statusCode: statusCode,
            returnTo: returnTo,
            title: title
        )
        
        return try await self.view.render("error", context).encodeResponse(for: self)
    }
    
    /// Creates a standardized base view context for the current request
    /// - Parameters:
    ///   - title: The page title
    ///   - errorMessage: Optional error message
    ///   - warningMessage: Optional warning message
    /// - Returns: A properly configured BaseViewContext
    func createBaseViewContext(
        title: String,
        errorMessage: String? = nil,
        warningMessage: String? = nil
    ) async -> BaseViewContext {
        return await ErrorHandling.createBaseViewContext(
            for: self,
            title: title,
            errorMessage: errorMessage,
            warningMessage: warningMessage
        )
    }
}

// MARK: - Error Response Factories

extension ErrorHandling {
    /// Creates a standardized JSON error response
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - status: Optional custom HTTP status
    /// - Returns: A standardized error response
    static func createAPIErrorResponse(
        for error: Error,
        status: HTTPStatus? = nil
    ) -> APIErrorResponse {
        let banderaError = error as? (any BanderaErrorProtocol)
        let abortError = error as? AbortError
        
        let errorStatus = status ?? banderaError?.status ?? abortError?.status ?? .internalServerError
        let reason = banderaError?.reason ?? abortError?.reason ?? "An error occurred"
        let suggestion = banderaError?.recoverySuggestion
        
        return APIErrorResponse(
            error: true,
            reason: reason,
            statusCode: errorStatus.code,
            recoverySuggestion: suggestion
        )
    }
}

/// Standardized error response structure for API endpoints
struct APIErrorResponse: Content {
    let error: Bool
    let reason: String
    let statusCode: UInt
    var recoverySuggestion: String?
    var requestId: String?
    var debugInfo: String?
}

 