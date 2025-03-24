import Vapor

/// Errors related to authorization
enum AuthorizationError: AbortError {
    /// User is not authorized to perform the requested action
    case notAuthorized(reason: String)
    
    /// User is not authenticated
    case notAuthenticated
    
    /// The HTTP status code
    var status: HTTPStatus {
        switch self {
        case .notAuthorized:
            return .forbidden
        case .notAuthenticated:
            return .unauthorized
        }
    }
    
    /// The reason for the error
    var reason: String {
        switch self {
        case .notAuthorized(let reason):
            return reason
        case .notAuthenticated:
            return "Authentication required"
        }
    }
    
    /// A description of the error
    var description: String {
        return reason
    }
} 