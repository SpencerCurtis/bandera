import Vapor

/// Application configuration constants
struct AppConstants {
    static let authCookieName = "bandera-auth-token"
    static let jwtExpirationDays = 7
    static let minJWTSecretLength = 32
    static let minSessionSecretLength = 32
    
    // Security configuration
    static let maxRequestBodySize: ByteCount = "10mb"
    static let sessionCookieName = "bandera-session"
    static let sessionMaxAge = 24 * 60 * 60 // 24 hours
    static let csrfTokenLifetime: TimeInterval = 3600 // 1 hour
    
    // MARK: - HTTP Status Codes
    
    /// Common HTTP status codes used throughout the application
    enum HTTPStatusCodes {
        static let ok: UInt = 200
        static let created: UInt = 201
        static let badRequest: UInt = 400
        static let unauthorized: UInt = 401
        static let forbidden: UInt = 403
        static let notFound: UInt = 404
        static let conflict: UInt = 409
        static let payloadTooLarge: UInt = 413
        static let tooManyRequests: UInt = 429
        static let internalServerError: UInt = 500
    }
    
    // MARK: - Database Table Names
    
    /// Database table names used in migrations and models
    enum DatabaseTables {
        static let users = "users"
        static let featureFlags = "feature_flags"
        static let featureFlagsTemp = "feature_flags_temp"
        static let userFeatureFlags = "user_feature_flags"
        static let organizations = "organizations"
        static let organizationUsers = "organization_users"
        static let auditLogs = "audit_logs"
    }
    
    // MARK: - Error Messages
    
    /// Standardized error messages used throughout the application
    enum ErrorMessages {
        // Authentication errors
        static let authenticationRequired = "Authentication required"
        static let invalidCredentials = "Invalid email or password"
        static let insufficientPermissions = "You do not have permission to perform this action"
        static let tokenExpired = "Authentication token has expired"
        static let adminAccessRequired = "Admin access required"
        
        // Resource errors
        static let userNotFound = "User not found"
        static let featureFlagNotFound = "Feature flag not found"
        static let organizationNotFound = "Organization not found"
        static let resourceAlreadyExists = "Resource already exists"
        
        // Validation errors
        static let validationFailed = "Validation failed"
        static let missingRequiredField = "Required field missing"
        static let invalidFormat = "Invalid format"
        static let invalidEmailFormat = "Invalid email format"
        static let passwordTooWeak = "Password does not meet strength requirements"
        
        // Database errors
        static let databaseOperationFailed = "Database operation failed"
        static let constraintViolation = "Constraint violation"
        
        // Server errors
        static let internalServerError = "Internal server error"
        static let serviceUnavailable = "Service temporarily unavailable"
        
        // Rate limiting errors
        static let tooManyRequests = "Too many requests"
        static let rateLimitExceeded = "Rate limit exceeded"
        
        // Recovery suggestions
        static let checkCredentialsAndRetry = "Please check your credentials and try again"
        static let contactSupport = "Please contact support if the problem persists"
        static let tryAgainLater = "Please try again later"
        static let checkIdentifierAndRetry = "Please check the identifier and try again"
        static let correctErrorsAndRetry = "Please correct the errors and try again"
    }
    
    // MARK: - Cache Keys
    
    /// Cache key prefixes and patterns
    enum CacheKeys {
        static let featureFlag = "flag:"
        static let user = "user:"
        static let organization = "org:"
        static let userFlags = "user_flags:"
        static let orgFlags = "org_flags:"
        
        // Cache expiration times (in seconds)
        static let defaultExpiration = 3600 // 1 hour
        static let shortExpiration = 300   // 5 minutes
        static let longExpiration = 86400  // 24 hours
    }
    
    // MARK: - JWT Configuration
    
    /// JWT-related constants
    enum JWT {
        static let expirationTime: TimeInterval = 24 * 60 * 60 // 24 hours
        static let issuer = "bandera"
        static let audience = "bandera-users"
    }
    
    // MARK: - Session Configuration
    
    /// Session-related constants
    enum Session {
        static let cookieName = "bandera-session"
        static let expirationTime: TimeInterval = 24 * 60 * 60 // 24 hours
        static let csrfTokenName = "csrf-token"
        static let csrfExpirationTime: TimeInterval = 60 * 60 // 1 hour
    }
    
    // MARK: - Rate Limiting
    
    /// Rate limiting configuration
    enum RateLimit {
        static let authRequestsPerMinute = 5
        static let apiRequestsPerMinute = 100
        static let maxBodySize = 10_000_000 // 10MB
    }
    
    // MARK: - Pagination
    
    /// Pagination defaults
    enum Pagination {
        static let defaultPageSize = 25
        static let maxPageSize = 100
        static let maxUnpaginatedItems = 1000
    }
    
    // MARK: - Validation Rules
    
    /// Validation constraints
    enum Validation {
        static let minPasswordLength = 8
        static let maxPasswordLength = 128
        static let minEmailLength = 3
        static let maxEmailLength = 254
        static let minNameLength = 1
        static let maxNameLength = 255
        static let minDescriptionLength = 0
        static let maxDescriptionLength = 1000
    }
    
    // MARK: - Default Values
    
    /// Default values used throughout the application
    enum Defaults {
        static let adminEmail = "admin@example.com"
        static let adminPassword = "password"
        static let personalOrganizationPrefix = "Personal - "
        static let defaultFlagValue = "false"
        static let defaultRole = "member"
    }
    
    // MARK: - Environment Keys
    
    /// Environment variable keys
    enum Environment {
        static let jwtSecret = "JWT_SECRET"
        static let databaseUrl = "DATABASE_URL"
        static let redisUrl = "REDIS_URL"
        static let environment = "ENVIRONMENT"
        static let port = "PORT"
        static let hostname = "HOSTNAME"
    }
    
    // MARK: - Development Tools
    
    /// Development and testing constants
    enum Development {
        static let testUserEmail = "test@example.com"
        static let testUserPassword = "testpassword"
        static let testOrganizationName = "Test Organization"
        static let testFlagKey = "test-flag"
    }
} 