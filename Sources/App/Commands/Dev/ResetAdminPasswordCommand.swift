import Foundation
import Vapor
import Fluent

/// Command to reset the admin user's password for development purposes
struct ResetAdminPasswordCommand: Command {
    struct Signature: CommandSignature {}
    
    var help: String {
        "Reset the admin user password to 'password'"
    }
    
    // Non-async function to conform to the Command protocol
    func run(using context: CommandContext, signature: Signature) throws {
        context.console.info("Resetting admin password...")
        
        // Use Task to handle async code
        let group = DispatchGroup()
        group.enter()
        
        Task {
            do {
                // Find the admin user
                guard let adminUser = try await User.query(on: context.application.db)
                    .filter(\.$email == "admin@example.com")
                    .first() else {
                    context.console.error("Admin user not found")
                    group.leave()
                    return
                }
                
                // Update the password
                adminUser.passwordHash = try Bcrypt.hash("password")
                try await adminUser.save(on: context.application.db)
                
                context.console.success("Admin password has been reset to 'password'")
                group.leave()
            } catch {
                context.console.error("Failed to reset admin password: \(error)")
                group.leave()
            }
        }
        
        group.wait()
    }
} 