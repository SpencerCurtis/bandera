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
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(60 * 60 * 24)) // 24 hours
        self.isAdmin = user.isAdmin
    }
    
    func verify(using signer: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
    }
    
    // MARK: - SessionAuthenticatable
    var sessionID: String {
        subject.value
    }
} 