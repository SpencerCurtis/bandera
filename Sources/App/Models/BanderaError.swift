import Vapor

/// Custom error types for the Bandera application.
///
/// This enum defines all the possible error types that can occur in the application,
/// organized by domain (authentication, resources, validation, etc.).
/// Each error type maps to an appropriate HTTP status code and provides
/// a user-friendly error message.
enum BanderaError: Error, Sendable {
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
}

// MARK: - AbortError Conformance
extension BanderaError: AbortError {
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
}

// MARK: - LocalizedError Conformance
extension BanderaError: LocalizedError {
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
}

// MARK: - Debugging Support
extension BanderaError: CustomDebugStringConvertible {
    /// Provides a debug description of the error
    var debugDescription: String {
        switch self {
        case .serverError(let message), .internalServerError(let message):
            return "[\(status.code)] \(reason) - Details: \(message)"
        default:
            return "[\(status.code)] \(reason)"
        }
    }
} 