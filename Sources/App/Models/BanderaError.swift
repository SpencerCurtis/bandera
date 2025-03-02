import Vapor

/// Custom error types for the Bandera application
enum BanderaError: Error, Sendable {
    // Authentication errors
    case invalidCredentials
    case authenticationRequired
    case accessDenied
    
    // Resource errors
    case resourceNotFound(String)
    case resourceAlreadyExists(String)
    
    // Validation errors
    case validationFailed(String)
    
    // Server errors
    case serverError(String)
    case internalServerError(String)
    
    // Custom error with message
    case custom(String)
}

// MARK: - AbortError Conformance
extension BanderaError: AbortError {
    var status: HTTPStatus {
        switch self {
        case .invalidCredentials:
            return .unauthorized
        case .authenticationRequired:
            return .unauthorized
        case .accessDenied:
            return .forbidden
        case .resourceNotFound:
            return .notFound
        case .resourceAlreadyExists:
            return .conflict
        case .validationFailed:
            return .badRequest
        case .serverError, .internalServerError:
            return .internalServerError
        case .custom:
            return .badRequest
        }
    }
    
    var reason: String {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials"
        case .authenticationRequired:
            return "Authentication required"
        case .accessDenied:
            return "Access denied"
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"
        case .resourceAlreadyExists(let resource):
            return "Resource already exists: \(resource)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .internalServerError(let message):
            return "Internal server error: \(message)"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - LocalizedError Conformance
extension BanderaError: LocalizedError {
    var errorDescription: String? {
        return reason
    }
} 