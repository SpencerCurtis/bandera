import JWT
import Vapor

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
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(7 * 86400)) // 7 days instead of 24 hours
        self.isAdmin = user.isAdmin
    }
    
    init(subject: SubjectClaim, expiration: ExpirationClaim, isAdmin: Bool) {
        self.subject = subject
        self.expiration = expiration
        self.isAdmin = isAdmin
    }
    
    func verify(using signer: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
    }
    
    // MARK: - SessionAuthenticatable
    var sessionID: String {
        subject.value
    }
} 