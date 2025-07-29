import JWT
import JWTKit
import Vapor
import Foundation

struct UserJWTPayload: JWTPayload, Authenticatable, SessionAuthenticatable {
    // Constants for claim keys
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case isAdmin = "is_admin"
    }
    
    // The user ID
    var subject: SubjectClaim
    // When the token expires
    var expiration: ExpirationClaim
    // Whether the user is an admin
    var isAdmin: Bool
    
    init(user: User) throws {
        self.subject = SubjectClaim(value: user.id?.uuidString ?? "")
        
        // Use standard JWT timestamp format (seconds since epoch)
        let expirationTime = Date().addingTimeInterval(TimeInterval(AppConstants.jwtExpirationDays * 86400))
        self.expiration = ExpirationClaim(value: expirationTime)
        
        self.isAdmin = user.isAdmin
    }
    
    init(subject: SubjectClaim, expiration: ExpirationClaim, isAdmin: Bool) {
        self.subject = subject
        self.expiration = expiration
        self.isAdmin = isAdmin
    }
    
    // Custom init from decoder to handle potential date format issues
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode subject and isAdmin normally
        self.subject = try container.decode(SubjectClaim.self, forKey: .subject)
        self.isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        
        // Try to decode expiration with error handling
        do {
            self.expiration = try container.decode(ExpirationClaim.self, forKey: .expiration)
        } catch {
            // If standard decoding fails, try to decode as a string and convert
            if let expString = try? container.decode(String.self, forKey: .expiration),
               let expDouble = Double(expString) {
                self.expiration = ExpirationClaim(value: Date(timeIntervalSince1970: expDouble))
            } else {
                // If that fails too, set expiration to a future date to avoid immediate expiration
                self.expiration = ExpirationClaim(value: Date().addingTimeInterval(86400)) // 1 day
            }
        }
    }
    
    // Add encode method to conform to Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subject, forKey: .subject)
        try container.encode(expiration, forKey: .expiration)
        try container.encode(isAdmin, forKey: .isAdmin)
    }
    
    func verify(using signer: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
    }
    
    // MARK: - SessionAuthenticatable
    var sessionID: String {
        subject.value
    }
} 