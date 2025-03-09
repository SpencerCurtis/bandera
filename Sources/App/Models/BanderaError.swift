import Vapor

/// Protocol that all Bandera application errors must conform to.
protocol BanderaErrorProtocol: Error, AbortError, LocalizedError, CustomDebugStringConvertible, Sendable {
    var status: HTTPStatus { get }
    var reason: String { get }
    var recoverySuggestion: String? { get }
    var headers: HTTPHeaders { get }
    var domain: ErrorDomain { get }
}

/// Error domains for categorizing errors
enum ErrorDomain: String, Sendable {
    case authentication
    case resource
    case validation
    case database
    case server
    case externalService
}

// MARK: - Default Implementations

extension BanderaErrorProtocol {
    var headers: HTTPHeaders {
        return [:]
    }
    
    var recoverySuggestion: String? {
        return nil
    }
    
    var errorDescription: String? {
        return reason
    }
    
    var debugDescription: String {
        return "[\(status.code)] \(reason)"
    }
}

// MARK: - Authentication Errors

/// Errors related to authentication and authorization
enum AuthenticationError: BanderaErrorProtocol {
    case invalidCredentials
    case authenticationRequired
    case accessDenied
    case tokenExpired
    case invalidToken
    
    var domain: ErrorDomain {
        return .authentication
    }
    
    var status: HTTPStatus {
        switch self {
        case .invalidCredentials, .authenticationRequired, .tokenExpired, .invalidToken:
            return .unauthorized
        case .accessDenied:
            return .forbidden
        }
    }
    
    var reason: String {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .authenticationRequired:
            return "Authentication is required to access this resource"
        case .accessDenied:
            return "You do not have permission to access this resource"
        case .tokenExpired:
            return "Authentication token has expired"
        case .invalidToken:
            return "Invalid authentication token"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your username and password and try again"
        case .authenticationRequired:
            return "Please log in to access this resource"
        case .accessDenied:
            return "Contact an administrator if you believe you should have access"
        case .tokenExpired:
            return "Please log in again to refresh your session"
        case .invalidToken:
            return "Please log in again to obtain a valid token"
        }
    }
}

// MARK: - Resource Errors

/// Errors related to resource operations (CRUD)
enum ResourceError: BanderaErrorProtocol {
    /// Requested resource was not found
    case notFound(String)
    
    /// Resource already exists and cannot be created again
    case alreadyExists(String)
    
    /// Resource is in use and cannot be modified or deleted
    case inUse(String)
    
    /// Resource has been modified by another user
    case conflict(String)
    
    /// The error domain
    var domain: ErrorDomain {
        return .resource
    }
    
    /// Maps each error type to an appropriate HTTP status code
    var status: HTTPStatus {
        switch self {
        case .notFound:
            return .notFound
        case .alreadyExists, .conflict:
            return .conflict
        case .inUse:
            return .preconditionFailed
        }
    }
    
    /// Provides a user-friendly error message for each error type
    var reason: String {
        switch self {
        case .notFound(let resource):
            return "The requested \(resource) could not be found"
        case .alreadyExists(let resource):
            return "A \(resource) with this identifier already exists"
        case .inUse(let resource):
            return "The \(resource) is currently in use and cannot be modified or deleted"
        case .conflict(let resource):
            return "The \(resource) has been modified by another user"
        }
    }
    
    /// Provides a localized recovery suggestion
    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "Please check the identifier and try again."
        case .alreadyExists:
            return "Please use a different identifier or update the existing resource."
        case .conflict:
            return "Please refresh and try again."
        case .inUse:
            return "Please remove dependencies before attempting this operation."
        }
    }
}

// MARK: - Validation Errors

/// Errors related to input validation
enum ValidationError: BanderaErrorProtocol {
    /// Input validation failed
    case failed(String)
    
    /// Required field is missing
    case missingRequiredField(String)
    
    /// Field has invalid format
    case invalidFormat(String, String)
    
    /// The error domain
    var domain: ErrorDomain {
        return .validation
    }
    
    /// Maps each error type to an appropriate HTTP status code
    var status: HTTPStatus {
        return .badRequest
    }
    
    /// Provides a user-friendly error message for each error type
    var reason: String {
        switch self {
        case .failed(let message):
            return "Validation failed: \(message)"
        case .missingRequiredField(let field):
            return "Required field missing: \(field)"
        case .invalidFormat(let field, let format):
            return "Invalid format for \(field): should be \(format)"
        }
    }
    
    /// Provides a localized recovery suggestion
    var recoverySuggestion: String? {
        return "Please correct the errors and try again."
    }
}

// MARK: - Database Errors

/// Errors related to database operations
enum DatabaseError: BanderaErrorProtocol {
    /// Database operation failed
    case operationFailed(String)
    
    /// Database connection failed
    case connectionFailed(String)
    
    /// The error domain
    var domain: ErrorDomain {
        return .database
    }
    
    /// Maps each error type to an appropriate HTTP status code
    var status: HTTPStatus {
        return .internalServerError
    }
    
    /// Provides a user-friendly error message for each error type
    var reason: String {
        switch self {
        case .operationFailed(let message):
            return "Database operation failed: \(message)"
        case .connectionFailed(let message):
            return "Database connection failed: \(message)"
        }
    }
    
    /// Provides a localized recovery suggestion
    var recoverySuggestion: String? {
        return "Please try again later or contact support if the problem persists."
    }
}

// MARK: - Server Errors

/// Errors related to server operations
enum ServerError: BanderaErrorProtocol {
    /// Generic server error
    case generic(String)
    
    /// Internal server error
    case `internal`(String)
    
    /// Service unavailable
    case serviceUnavailable(String)
    
    /// The error domain
    var domain: ErrorDomain {
        return .server
    }
    
    /// Maps each error type to an appropriate HTTP status code
    var status: HTTPStatus {
        switch self {
        case .generic, .internal:
            return .internalServerError
        case .serviceUnavailable:
            return .serviceUnavailable
        }
    }
    
    /// Provides a user-friendly error message for each error type
    var reason: String {
        switch self {
        case .generic(let message):
            return "Server error: \(message)"
        case .internal(let message):
            return "Internal server error: \(message)"
        case .serviceUnavailable(let message):
            return "Service unavailable: \(message)"
        }
    }
    
    /// Provides a localized recovery suggestion
    var recoverySuggestion: String? {
        return "Please try again later or contact support if the problem persists."
    }
    
    /// Provides a debug description of the error with more details
    var debugDescription: String {
        switch self {
        case .generic(let message), .internal(let message), .serviceUnavailable(let message):
            return "[\(status.code)] \(reason) - Details: \(message)"
        }
    }
}

// MARK: - External Service Errors

/// Errors related to external service interactions
enum ExternalServiceError: BanderaErrorProtocol {
    /// External service request failed
    case requestFailed(String)
    
    /// External service timeout
    case timeout(String)
    
    /// The error domain
    var domain: ErrorDomain {
        return .externalService
    }
    
    /// Maps each error type to an appropriate HTTP status code
    var status: HTTPStatus {
        switch self {
        case .requestFailed:
            return .badGateway
        case .timeout:
            return .gatewayTimeout
        }
    }
    
    /// Provides a user-friendly error message for each error type
    var reason: String {
        switch self {
        case .requestFailed(let service):
            return "External service error: \(service)"
        case .timeout(let service):
            return "External service timeout: \(service)"
        }
    }
    
    /// Provides a localized recovery suggestion
    var recoverySuggestion: String? {
        return "Please try again later or contact support if the problem persists."
    }
}

// MARK: - Legacy Support

/// Legacy error type for backward compatibility
///
/// This enum provides backward compatibility with code that still uses the old BanderaError type.
/// It maps the old error cases to the new domain-specific error types.
enum LegacyBanderaError: Error, AbortError, LocalizedError, CustomDebugStringConvertible, Sendable {
    // MARK: - Authentication Errors
    
    /// Invalid username or password
    case invalidCredentials
    
    /// Authentication is required for this operation
    case authenticationRequired
    
    /// User does not have permission to perform this operation
    case accessDenied
    
    /// Token has expired
    case tokenExpired
    
    /// Token is invalid
    case invalidToken
    
    // MARK: - Resource Errors
    
    /// Requested resource was not found
    case resourceNotFound(String)
    
    /// Resource already exists and cannot be created again
    case resourceAlreadyExists(String)
    
    /// Resource is in use and cannot be modified or deleted
    case resourceInUse(String)
    
    /// Resource has been modified by another user
    case resourceConflict(String)
    
    // MARK: - Validation Errors
    
    /// Input validation failed
    case validationFailed(String)
    
    /// Required field is missing
    case missingRequiredField(String)
    
    /// Field has invalid format
    case invalidFormat(String, String)
    
    // MARK: - Database Errors
    
    /// Database operation failed
    case databaseError(String)
    
    /// Database connection failed
    case databaseConnectionFailed(String)
    
    // MARK: - Server Errors
    
    /// Generic server error
    case serverError(String)
    
    /// Internal server error
    case internalServerError(String)
    
    /// Service unavailable
    case serviceUnavailable(String)
    
    // MARK: - External Service Errors
    
    /// External service request failed
    case externalServiceError(String)
    
    /// External service timeout
    case externalServiceTimeout(String)
    
    // MARK: - Custom Error
    
    /// Custom error with message
    case custom(String)

    /// Maps each error type to an appropriate HTTP status code
    var status: HTTPStatus {
        switch self {
        // Authentication errors
        case .invalidCredentials, .authenticationRequired, .tokenExpired, .invalidToken:
            return .unauthorized
        case .accessDenied:
            return .forbidden
            
        // Resource errors
        case .resourceNotFound:
            return .notFound
        case .resourceAlreadyExists, .resourceConflict:
            return .conflict
        case .resourceInUse:
            return .preconditionFailed
            
        // Validation errors
        case .validationFailed, .missingRequiredField, .invalidFormat:
            return .badRequest
            
        // Database errors
        case .databaseError, .databaseConnectionFailed:
            return .internalServerError
            
        // Server errors
        case .serverError, .internalServerError:
            return .internalServerError
        case .serviceUnavailable:
            return .serviceUnavailable
            
        // External service errors
        case .externalServiceError:
            return .badGateway
        case .externalServiceTimeout:
            return .gatewayTimeout
            
        // Custom error
        case .custom:
            return .badRequest
        }
    }
    
    /// Provides a user-friendly error message for each error type
    var reason: String {
        switch self {
        // Authentication errors
        case .invalidCredentials:
            return "Invalid username or password"
        case .authenticationRequired:
            return "Authentication is required to access this resource"
        case .accessDenied:
            return "You do not have permission to perform this operation"
        case .tokenExpired:
            return "Your session has expired, please log in again"
        case .invalidToken:
            return "Invalid authentication token"
            
        // Resource errors
        case .resourceNotFound(let resource):
            return "The requested \(resource) could not be found"
        case .resourceAlreadyExists(let resource):
            return "A \(resource) with this identifier already exists"
        case .resourceInUse(let resource):
            return "The \(resource) is currently in use and cannot be modified or deleted"
        case .resourceConflict(let resource):
            return "The \(resource) has been modified by another user"
            
        // Validation errors
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .missingRequiredField(let field):
            return "Required field missing: \(field)"
        case .invalidFormat(let field, let format):
            return "Invalid format for \(field): should be \(format)"
            
        // Database errors
        case .databaseError(let message):
            return "Database operation failed: \(message)"
        case .databaseConnectionFailed(let message):
            return "Database connection failed: \(message)"
            
        // Server errors
        case .serverError(let message):
            return "Server error: \(message)"
        case .internalServerError(let message):
            return "Internal server error: \(message)"
        case .serviceUnavailable(let message):
            return "Service unavailable: \(message)"
            
        // External service errors
        case .externalServiceError(let service):
            return "External service error: \(service)"
        case .externalServiceTimeout(let service):
            return "External service timeout: \(service)"
            
        // Custom error
        case .custom(let message):
            return message
        }
    }
    
    /// Default headers for the error response
    var headers: HTTPHeaders {
        // Most errors don't need custom headers
        return [:]
}

    /// Provides a localized description of the error
    var errorDescription: String? {
        return reason
    }
    
    /// Provides a localized recovery suggestion
    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your username and password and try again."
        case .authenticationRequired:
            return "Please log in to continue."
        case .tokenExpired:
            return "Please log in again to continue."
        case .resourceNotFound:
            return "Please check the identifier and try again."
        case .validationFailed:
            return "Please correct the errors and try again."
        case .databaseError, .serverError, .internalServerError:
            return "Please try again later or contact support if the problem persists."
        default:
            return nil
    }
}

    /// Provides a debug description of the error
    var debugDescription: String {
        switch self {
        case .serverError(let message), .internalServerError(let message):
            return "[\(status.code)] \(reason) - Details: \(message)"
        default:
            return "[\(status.code)] \(reason)"
        }
    }
    
    /// Convert legacy error to new domain-specific error
    func toDomainError() -> any BanderaErrorProtocol {
        switch self {
        // Authentication errors
        case .invalidCredentials:
            return AuthenticationError.invalidCredentials
        case .authenticationRequired:
            return AuthenticationError.authenticationRequired
        case .accessDenied:
            return AuthenticationError.accessDenied
        case .tokenExpired:
            return AuthenticationError.tokenExpired
        case .invalidToken:
            return AuthenticationError.invalidToken
            
        // Resource errors
        case .resourceNotFound(let resource):
            return ResourceError.notFound(resource)
        case .resourceAlreadyExists(let resource):
            return ResourceError.alreadyExists(resource)
        case .resourceInUse(let resource):
            return ResourceError.inUse(resource)
        case .resourceConflict(let resource):
            return ResourceError.conflict(resource)
            
        // Validation errors
        case .validationFailed(let message):
            return ValidationError.failed(message)
        case .missingRequiredField(let field):
            return ValidationError.missingRequiredField(field)
        case .invalidFormat(let field, let format):
            return ValidationError.invalidFormat(field, format)
            
        // Database errors
        case .databaseError(let message):
            return DatabaseError.operationFailed(message)
        case .databaseConnectionFailed(let message):
            return DatabaseError.connectionFailed(message)
            
        // Server errors
        case .serverError(let message):
            return ServerError.generic(message)
        case .internalServerError(let message):
            return ServerError.internal(message)
        case .serviceUnavailable(let message):
            return ServerError.serviceUnavailable(message)
            
        // External service errors
        case .externalServiceError(let service):
            return ExternalServiceError.requestFailed(service)
        case .externalServiceTimeout(let service):
            return ExternalServiceError.timeout(service)
            
        // Custom error
        case .custom(let message):
            return ValidationError.failed(message)
        }
    }
}

// For backward compatibility, typealias the old BanderaError to LegacyBanderaError
typealias BanderaError = LegacyBanderaError 