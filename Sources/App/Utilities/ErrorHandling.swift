import Vapor
import Fluent

/// Utility functions for error handling.
///
/// This namespace contains utility functions for error handling,
/// including functions for converting common errors to BanderaErrors
/// and for handling specific error scenarios.
enum ErrorHandling {
    /// Converts a database error to a BanderaError.
    ///
    /// - Parameter error: The database error to convert
    /// - Returns: A BanderaError
    static func handleDatabaseError(_ error: Error) -> BanderaError {
        if let dbError = error as? DatabaseError {
            // Handle generic database errors
            return .databaseError(String(describing: dbError))
        } else {
            // Generic database error
            return .databaseError(error.localizedDescription)
        }
    }
    
    /// Handles a not found error for a specific resource.
    ///
    /// - Parameters:
    ///   - id: The ID of the resource that wasn't found
    ///   - resourceName: The name of the resource type
    /// - Returns: A BanderaError
    static func handleNotFound<T: CustomStringConvertible>(id: T, resourceName: String) -> BanderaError {
        return .resourceNotFound("\(resourceName) with ID \(id)")
    }
    
    /// Handles an access denied error for a specific resource.
    ///
    /// - Parameters:
    ///   - id: The ID of the resource that access was denied to
    ///   - resourceName: The name of the resource type
    /// - Returns: A BanderaError
    static func handleAccessDenied<T: CustomStringConvertible>(id: T, resourceName: String) -> BanderaError {
        return .accessDenied
    }
    
    /// Handles a validation error for a specific field.
    ///
    /// - Parameters:
    ///   - field: The name of the field that failed validation
    ///   - reason: The reason for the validation failure
    /// - Returns: A BanderaError
    static func handleValidationError(field: String, reason: String) -> BanderaError {
        return .validationFailed("\(field): \(reason)")
    }
    
    /// Handles a resource already exists error.
    ///
    /// - Parameters:
    ///   - key: The key or identifier of the resource
    ///   - resourceName: The name of the resource type
    /// - Returns: A BanderaError
    static func handleResourceExists(key: String, resourceName: String) -> BanderaError {
        return .resourceAlreadyExists("\(resourceName) with key '\(key)'")
    }
    
    /// Wraps a throwing operation with error handling.
    ///
    /// This function executes the provided operation and catches any errors,
    /// converting them to BanderaErrors where appropriate.
    ///
    /// - Parameter operation: The operation to execute
    /// - Returns: The result of the operation
    /// - Throws: A BanderaError if the operation fails
    static func withErrorHandling<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as BanderaError {
            // Already a BanderaError, just rethrow
            throw error
        } catch let error as AbortError {
            // Convert AbortError to BanderaError
            switch error.status.code {
            case 401:
                throw BanderaError.authenticationRequired
            case 403:
                throw BanderaError.accessDenied
            case 404:
                throw BanderaError.resourceNotFound(error.reason)
            case 409:
                throw BanderaError.resourceAlreadyExists(error.reason)
            default:
                throw BanderaError.custom(error.reason)
            }
        } catch let error as DecodingError {
            // Handle Codable decoding errors
            switch error {
            case .keyNotFound(let key, _):
                throw BanderaError.missingRequiredField(key.stringValue)
            case .valueNotFound(_, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                throw BanderaError.missingRequiredField(path)
            case .typeMismatch(_, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                throw BanderaError.invalidFormat(path, context.debugDescription)
            case .dataCorrupted(let context):
                throw BanderaError.validationFailed(context.debugDescription)
            @unknown default:
                throw BanderaError.validationFailed("Invalid data format")
            }
        } catch {
            // Handle any other errors as internal server errors
            if error is DatabaseError {
                throw handleDatabaseError(error)
            } else {
                throw BanderaError.internalServerError(error.localizedDescription)
            }
        }
    }
} 