import XCTest
@testable import App

final class ValidationTests: XCTestCase {
    
    // MARK: - Input Sanitization Tests
    
    func testSanitizeForXSS() throws {
        let maliciousInput = "<script>alert('XSS')</script>"
        let sanitized = ValidationUtilities.sanitizeForXSS(maliciousInput)
        
        XCTAssertEqual(sanitized, "&lt;script&gt;alert(&#x27;XSS&#x27;)&lt;/script&gt;")
        XCTAssertFalse(sanitized.contains("<script>"))
        XCTAssertFalse(sanitized.contains("alert('XSS')"))
    }
    
    func testSanitizeOrganizationName() throws {
        let maliciousName = "  My Org <script>alert('hack')</script>  "
        let sanitized = ValidationUtilities.sanitizeOrganizationName(maliciousName)
        
        XCTAssertEqual(sanitized, "My Org alert('hack')")
        XCTAssertFalse(sanitized.contains("<script>"))
        XCTAssertFalse(sanitized.contains("</script>"))
        XCTAssertFalse(sanitized.hasPrefix(" "))
        XCTAssertFalse(sanitized.hasSuffix(" "))
    }
    
    func testSanitizeDescription() throws {
        let validDescription = "This is a normal description"
        let sanitized = ValidationUtilities.sanitizeDescription(validDescription)
        XCTAssertEqual(sanitized, validDescription)
        
        let maliciousDescription = "<script>alert('XSS')</script>  "
        let sanitizedMalicious = ValidationUtilities.sanitizeDescription(maliciousDescription)
        XCTAssertEqual(sanitizedMalicious, "&lt;script&gt;alert(&#x27;XSS&#x27;)&lt;/script&gt;")
        
        let emptyDescription = "   "
        let sanitizedEmpty = ValidationUtilities.sanitizeDescription(emptyDescription)
        XCTAssertNil(sanitizedEmpty)
        
        let nilDescription: String? = nil
        let sanitizedNil = ValidationUtilities.sanitizeDescription(nilDescription)
        XCTAssertNil(sanitizedNil)
    }
    
    // MARK: - Organization Name Validation Tests
    
    func testValidateOrganizationNameSuccess() throws {
        let validNames = [
            "My Organization",
            "Tech Company Inc",
            "AB", // Minimum length
            String(repeating: "A", count: 100) // Maximum length
        ]
        
        for name in validNames {
            XCTAssertNoThrow(try ValidationUtilities.validateOrganizationName(name), "Failed to validate: \(name)")
        }
    }
    
    func testValidateOrganizationNameFailure() throws {
        let invalidNames = [
            "", // Empty
            "   ", // Only whitespace
            "A", // Too short
            String(repeating: "A", count: 101), // Too long
            "Org<script>", // Contains forbidden chars
            "Org\"quote", // Contains quotes
            "Org&amp;" // Contains ampersand
        ]
        
        for name in invalidNames {
            XCTAssertThrowsError(try ValidationUtilities.validateOrganizationName(name), "Should have failed for: \(name)") { error in
                XCTAssertTrue(error is ValidationError, "Expected ValidationError for: \(name)")
            }
        }
    }
    
    // MARK: - Feature Flag Key Validation Tests
    
    func testValidateFeatureFlagKeySuccess() throws {
        let validKeys = [
            "feature_flag",
            "my-feature",
            "featureA1",
            "ab", // Minimum length
            String(repeating: "a", count: 50) // Maximum length
        ]
        
        for key in validKeys {
            XCTAssertNoThrow(try ValidationUtilities.validateFeatureFlagKey(key), "Failed to validate: \(key)")
        }
    }
    
    func testValidateFeatureFlagKeyFailure() throws {
        let invalidKeys = [
            "", // Empty
            "a", // Too short
            String(repeating: "a", count: 51), // Too long
            "123feature", // Starts with number
            "_feature", // Starts with underscore
            "feature@flag", // Contains invalid char
            "feature flag", // Contains space
            "feature.flag" // Contains period
        ]
        
        for key in invalidKeys {
            XCTAssertThrowsError(try ValidationUtilities.validateFeatureFlagKey(key), "Should have failed for: \(key)") { error in
                XCTAssertTrue(error is ValidationError, "Expected ValidationError for: \(key)")
            }
        }
    }
    
    // MARK: - Password Strength Validation Tests
    
    func testValidatePasswordStrengthSuccess() throws {
        let validPasswords = [
            "Password123!",
            "MyS3cur3P@ss",
            "1234ABCDef!@"
        ]
        
        for password in validPasswords {
            XCTAssertNoThrow(try ValidationUtilities.validatePasswordStrength(password), "Failed to validate: \(password)")
        }
    }
    
    func testValidatePasswordStrengthFailure() throws {
        let invalidPasswords = [
            "short", // Too short
            "password", // No uppercase, no number, no special char
            "PASSWORD", // No lowercase, no number, no special char
            "Password", // No number, no special char
            "Password123", // No special char
            "Password!" // No number
        ]
        
        for password in invalidPasswords {
            XCTAssertThrowsError(try ValidationUtilities.validatePasswordStrength(password), "Should have failed for: \(password)") { error in
                XCTAssertTrue(error is ValidationError, "Expected ValidationError for: \(password)")
            }
        }
    }
    
    // MARK: - Business Email Validation Tests
    
    func testValidateBusinessEmailSuccess() throws {
        let validEmails = [
            "user@example.com",
            "test.user@company.org",
            "admin@test.co.uk"
        ]
        
        for email in validEmails {
            XCTAssertNoThrow(try ValidationUtilities.validateBusinessEmail(email), "Failed to validate: \(email)")
        }
    }
    
    func testValidateBusinessEmailFailure() throws {
        let invalidEmails = [
            String(repeating: "a", count: 250) + "@example.com", // Too long
            "user@gmial.com", // Common typo
            "user@gmai.com", // Common typo
            "user@yahooo.com", // Common typo
            "user@hotmial.com" // Common typo
        ]
        
        for email in invalidEmails {
            XCTAssertThrowsError(try ValidationUtilities.validateBusinessEmail(email), "Should have failed for: \(email)") { error in
                XCTAssertTrue(error is ValidationError, "Expected ValidationError for: \(email)")
            }
        }
    }
    
    // MARK: - Organization Role Validation Tests
    
    func testValidateOrganizationRoleSuccess() throws {
        let validRoles = [
            "owner",
            "admin",
            "member",
            "OWNER", // Case insensitive
            "Admin",
            "MEMBER"
        ]
        
        for role in validRoles {
            XCTAssertNoThrow(try ValidationUtilities.validateOrganizationRole(role), "Failed to validate: \(role)")
        }
    }
    
    func testValidateOrganizationRoleFailure() throws {
        let invalidRoles = [
            "invalid",
            "user",
            "moderator",
            "",
            "owner admin" // Multiple roles
        ]
        
        for role in invalidRoles {
            XCTAssertThrowsError(try ValidationUtilities.validateOrganizationRole(role), "Should have failed for: \(role)") { error in
                XCTAssertTrue(error is ValidationError, "Expected ValidationError for: \(role)")
            }
        }
    }
    
    // MARK: - Validation Result Tests
    
    func testCreateValidationResultSuccess() throws {
        let result = ValidationUtilities.createValidationResult(errors: [])
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.suggestions.isEmpty)
    }
    
    func testCreateValidationResultFailure() throws {
        let errors = [
            "Password must contain at least one uppercase letter",
            "Email address appears to contain a typo"
        ]
        let result = ValidationUtilities.createValidationResult(errors: errors)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertFalse(result.suggestions.isEmpty)
        // Check that suggestions are relevant to the errors
        let suggestionsText = result.suggestions.joined(separator: " ").lowercased()
        XCTAssertTrue(suggestionsText.contains("password") || suggestionsText.contains("character") || suggestionsText.contains("mix"), "Expected password-related suggestion, got: \(result.suggestions)")
        XCTAssertTrue(suggestionsText.contains("email") || suggestionsText.contains("typo") || suggestionsText.contains("check"), "Expected email-related suggestion, got: \(result.suggestions)")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteValidationWorkflow() throws {
        // Test a complete validation workflow with sanitization
        let userInput = "  Valid Organization Name  "
        
        // 1. Sanitize the input
        let sanitized = ValidationUtilities.sanitizeOrganizationName(userInput)
        XCTAssertEqual(sanitized, "Valid Organization Name")
        
        // 2. Validate the sanitized input
        XCTAssertNoThrow(try ValidationUtilities.validateOrganizationName(sanitized))
    }
    
    func testXSSPreventionWorkflow() throws {
        // Test XSS prevention with sanitizeForXSS (HTML encoding)
        let scriptInput = "<script>alert('xss')</script>"
        let sanitizedScript = ValidationUtilities.sanitizeForXSS(scriptInput)
        XCTAssertFalse(sanitizedScript.contains("<script>"), "XSS not prevented for: \(scriptInput)")
        
        // Test organization name sanitization (HTML tag removal)
        let maliciousInputs = [
            "My Org <script>alert('xss')</script>",
            "Company <img src='x' onerror='alert(1)'>",
            "Test javascript:alert('hack') Company"
        ]
        
        for input in maliciousInputs {
            let sanitized = ValidationUtilities.sanitizeOrganizationName(input)
            
            // Ensure no executable content remains
            XCTAssertFalse(sanitized.contains("<script>"), "Script tag not removed for: \(input)")
            XCTAssertFalse(sanitized.contains("<img"), "Image tag not removed for: \(input)")
            XCTAssertFalse(sanitized.contains("javascript:"), "JavaScript protocol not removed for: \(input)")
        }
    }
} 