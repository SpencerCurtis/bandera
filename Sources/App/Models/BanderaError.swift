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
    case rateLimit
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
    case insufficientPermissions
    
    var status: HTTPStatus {
        switch self {
        case .invalidCredentials:
            return .unauthorized
        case .authenticationRequired:
            return .unauthorized
        case .insufficientPermissions:
            return .forbidden
        }
    }
    
    var reason: String {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .authenticationRequired:
            return "Authentication required"
        case .insufficientPermissions:
            return "Insufficient permissions"
        }
    }
    
    var suggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your email and password and try again"
        case .authenticationRequired:
            return "Please log in to access this resource"
        case .insufficientPermissions:
            return "Please contact an administrator if you need access to this resource"
        }
    }
    
    var domain: ErrorDomain {
        return .authentication
    }
    
    var headers: HTTPHeaders {
        return [:]
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

/// Errors related to rate limiting
enum RateLimitError: BanderaErrorProtocol {
    case tooManyRequests
    
    var status: HTTPStatus {
        switch self {
        case .tooManyRequests:
            return .tooManyRequests
        }
    }
    
    var reason: String {
        switch self {
        case .tooManyRequests:
            return "Too many requests"
        }
    }
    
    var suggestion: String? {
        switch self {
        case .tooManyRequests:
            return "Please wait a moment before trying again"
        }
    }
    
    var domain: ErrorDomain {
        return .rateLimit
    }
    
    var headers: HTTPHeaders {
        return [:]
    }
} 