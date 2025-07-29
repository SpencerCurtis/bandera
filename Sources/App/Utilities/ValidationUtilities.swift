import Vapor
import Foundation

/// Validation utilities for enhanced input validation and sanitization.
/// Provides helper functions for validation and input sanitization to improve security.
public struct ValidationUtilities {
    
    // MARK: - Input Sanitization
    
    /// Sanitizes string input to prevent XSS attacks
    public static func sanitizeForXSS(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "&", with: "&amp;")  // Must be first to avoid double-encoding
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#x27;")
    }
    
    /// Sanitizes input for organization names (allows most characters but escapes dangerous ones)
    public static func sanitizeOrganizationName(_ input: String) -> String {
        let cleaned = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "javascript:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "onerror=", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "onload=", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "onclick=", with: "", options: .caseInsensitive)
        
        // Remove any HTML tags including script tags
        return cleaned.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
    }
    
    /// Removes potentially dangerous content from feature flag descriptions
    public static func sanitizeDescription(_ input: String?) -> String? {
        guard let input = input else { return nil }
        let sanitized = sanitizeForXSS(input).trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? nil : sanitized
    }
    
    // MARK: - Validation Helpers
    
    /// Validates organization name with business rules
    public static func validateOrganizationName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.failed("Organization name cannot be empty")
        }
        
        guard trimmed.count >= 2 && trimmed.count <= 100 else {
            throw ValidationError.failed("Organization name must be between 2 and 100 characters")
        }
        
        let forbiddenChars = CharacterSet(charactersIn: "<>\"'&")
        guard name.rangeOfCharacter(from: forbiddenChars) == nil else {
            throw ValidationError.failed("Organization name contains invalid characters")
        }
    }
    
    /// Validates feature flag key with strict rules
    public static func validateFeatureFlagKey(_ key: String) throws {
        guard !key.isEmpty else {
            throw ValidationError.failed("Feature flag key cannot be empty")
        }
        
        guard key.count >= 2 && key.count <= 50 else {
            throw ValidationError.failed("Feature flag key must be between 2 and 50 characters")
        }
        
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard key.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else {
            throw ValidationError.failed("Feature flag key can only contain letters, numbers, underscores, and hyphens")
        }
        
        guard key.first?.isLetter == true else {
            throw ValidationError.failed("Feature flag key must start with a letter")
        }
    }
    
    /// Validates password strength
    public static func validatePasswordStrength(_ password: String) throws {
        guard password.count >= 8 else {
            throw ValidationError.failed("Password must be at least 8 characters long")
        }
        
        guard password.count <= 128 else {
            throw ValidationError.failed("Password cannot exceed 128 characters")
        }
        
        guard password.contains(where: { $0.isUppercase }) else {
            throw ValidationError.failed("Password must contain at least one uppercase letter")
        }
        
        guard password.contains(where: { $0.isLowercase }) else {
            throw ValidationError.failed("Password must contain at least one lowercase letter")
        }
        
        guard password.contains(where: { $0.isNumber }) else {
            throw ValidationError.failed("Password must contain at least one number")
        }
        
        let specialChars = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        guard password.unicodeScalars.contains(where: { specialChars.contains($0) }) else {
            throw ValidationError.failed("Password must contain at least one special character")
        }
    }
    
    /// Validates email with additional business rules (beyond standard email validation)
    public static func validateBusinessEmail(_ email: String) throws {
        // Length constraints
        guard email.count <= 254 else {
            throw ValidationError.failed("Email address is too long")
        }
        
        // Prevent common typos
        let commonTypos = ["@gmial.com", "@gmai.com", "@yahooo.com", "@hotmial.com"]
        for typo in commonTypos {
            if email.lowercased().contains(typo) {
                throw ValidationError.failed("Email address appears to contain a typo")
            }
        }
    }
    
    /// Validates organization role
    public static func validateOrganizationRole(_ role: String) throws {
        let validRoles = ["owner", "admin", "member"]
        guard validRoles.contains(role.lowercased()) else {
            throw ValidationError.failed("Role must be one of: owner, admin, member")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Creates a validation result with helpful suggestions
    public static func createValidationResult(errors: [String]) -> ValidationResult {
        if errors.isEmpty {
            return ValidationResult(isValid: true, errors: [], suggestions: [])
        }
        
        let suggestions = generateSuggestions(for: errors)
        return ValidationResult(isValid: false, errors: errors, suggestions: suggestions)
    }
    
    /// Generates helpful suggestions based on validation errors
    private static func generateSuggestions(for errors: [String]) -> [String] {
        var suggestions: [String] = []
        
        for error in errors {
            let lowercaseError = error.lowercased()
            switch lowercaseError {
            case let str where str.contains("password"):
                suggestions.append("Try using a mix of uppercase, lowercase, numbers, and special characters")
            case let str where str.contains("email"):
                suggestions.append("Check for typos in your email address")
            case let str where str.contains("organization"):
                suggestions.append("Use a descriptive name for your organization")
            case let str where str.contains("flag"):
                suggestions.append("Feature flag keys should be descriptive and use snake_case or kebab-case")
            case let str where str.contains("uppercase"):
                suggestions.append("Try using a mix of uppercase, lowercase, numbers, and special characters")
            case let str where str.contains("typo"):
                suggestions.append("Check for typos in your email address")
            default:
                suggestions.append("Please correct the highlighted errors and try again")
            }
        }
        
        return Array(Set(suggestions)) // Remove duplicates
    }
}

/// Result structure for comprehensive validation
public struct ValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let suggestions: [String]
    
    public init(isValid: Bool, errors: [String], suggestions: [String]) {
        self.isValid = isValid
        self.errors = errors
        self.suggestions = suggestions
    }
} 