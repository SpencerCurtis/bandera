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
        return AuthenticationError.accessDenied
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
            case 401:
                throw AuthenticationError.authenticationRequired
            case 403:
                throw AuthenticationError.accessDenied
            case 404:
                throw ResourceError.notFound(error.reason)
            case 409:
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
} 