import Foundation
import Vapor
import Fluent

/// Command to reset any user's password for development purposes
struct ResetPasswordCommand: Command {
    struct Signature: CommandSignature {
        @Argument(name: "email", help: "The email of the user to reset the password for")
        var email: String
        
        @Option(name: "password", short: "p", help: "The new password (defaults to 'password')")
        var password: String?
    }
    
    var help: String {
        "Reset a user's password"
    }
    
    // Non-async function to conform to the Command protocol
    func run(using context: CommandContext, signature: Signature) throws {
        let email = signature.email
        let password = signature.password ?? "password"
        
        context.console.info("Resetting password for user \(email) to '\(password)'...")
        
        // Use Task to handle async code
        let group = DispatchGroup()
        group.enter()
        
        Task {
            do {
                // Find the user by email
                guard let user = try await User.query(on: context.application.db)
                    .filter(\.$email == email)
                    .first() else {
                    context.console.error("User not found with email: \(email)")
                    group.leave()
                    return
                }
                
                // Update the password
                user.passwordHash = try Bcrypt.hash(password)
                try await user.save(on: context.application.db)
                
                context.console.success("Password for user \(email) has been reset to '\(password)'")
                group.leave()
            } catch {
                context.console.error("Failed to reset password: \(error)")
                group.leave()
            }
        }
        
        group.wait()
    }
} 