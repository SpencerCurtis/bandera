import Vapor
import Logging
import NIOCore
import NIOPosix

/// Main entry point for the Bandera application.
/// This is the starting point of the application that sets up the environment,
/// configures logging, and starts the Vapor application.
@main
enum Entrypoint {
    /// The main function that bootstraps the application.
    /// This function performs the following steps:
    /// 1. Detects the environment (development, testing, production)
    /// 2. Sets up the logging system
    /// 3. Creates and configures the Vapor application
    /// 4. Starts the application and handles shutdown
    ///
    /// - Throws: An error if any part of the setup or execution fails
    static func main() async throws {
        // Detect the environment (development, testing, production)
        var env = try Environment.detect()
        
        // Bootstrap the logging system based on the environment
        try LoggingSystem.bootstrap(from: &env)
        
        // Create the Vapor application
        let app = try await Application.make(env)

        // This attempts to install NIO as the Swift Concurrency global executor.
        // You can enable it if you'd like to reduce the amount of context switching between NIO and Swift Concurrency.
        // Note: this has caused issues with some libraries that use `.wait()` and cleanly shutting down.
        // If enabled, you should be careful about calling async functions before this point as it can cause assertion failures.
        // let executorTakeoverSuccess = NIOSingletons.unsafeTryInstallSingletonPosixEventLoopGroupAsConcurrencyGlobalExecutor()
        // app.logger.debug("Tried to install SwiftNIO's EventLoopGroup as Swift's global concurrency executor", metadata: ["success": .stringConvertible(executorTakeoverSuccess)])
        
        do {
            // Configure the application with routes, middleware, and services
            try await configure(app)
        } catch {
            // Log any configuration errors
            app.logger.report(error: error)
            
            // Attempt to shut down the application gracefully
            try? await app.asyncShutdown()
            
            // Re-throw the error to terminate the application
            throw error
        }
        
        // Execute the application, which starts the server
        try await app.execute()
        
        // Shut down the application gracefully when execution completes
        try await app.asyncShutdown()
    }
}
