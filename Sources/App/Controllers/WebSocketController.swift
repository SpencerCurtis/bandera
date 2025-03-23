import Vapor
import WebSocketKit

/// Controller for handling WebSocket connections
struct WebSocketController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // WebSocket routes require authentication
        let protected = routes.grouped(JWTAuthMiddleware.api)
        
        // WebSocket endpoint for feature flag updates
        protected.webSocket("ws", "feature-flags") { req, ws in
            req.logger.info("WebSocket connection established")
            
            // Send initial feature flags
            if let userId = req.auth.get(UserJWTPayload.self)?.subject.value,
               let userIdUUID = UUID(userId) {
                Task {
                    do {
                        let flags = try await req.services.featureFlagService.getAllFlags(userId: userIdUUID)
                        let data = try JSONEncoder().encode(flags)
                        try await ws.send([UInt8](data))
                    } catch {
                        req.logger.error("Failed to send initial flags: \(error)")
                        try? await ws.send("Error: Failed to send initial flags")
                    }
                }
            }
            
            // Handle incoming messages
            ws.onText { ws, text in
                req.logger.debug("Received WebSocket message: \(text)")
            }
            
            // Handle close
            ws.onClose.whenComplete { _ in
                req.logger.info("WebSocket connection closed")
            }
        }
        
        // Add the WebSocket endpoint at flags/socket to match the client
        routes.get("flags", "socket") { req -> Response in
            guard let upgrade = req.headers[.upgrade].first?.lowercased(), upgrade == "websocket" else {
                throw ValidationError.failed("WebSocket upgrade required")
            }
            
            return req.webSocket { req, ws in
                let connectionId = UUID()
                req.logger.info("WebSocket connection established with ID: \(connectionId)")
                
                Task {
                    await req.services.webSocketService.add(ws, id: connectionId)
                    
                    ws.onClose.whenComplete { _ in
                        Task {
                            req.logger.info("WebSocket connection closed: \(connectionId)")
                            await req.services.webSocketService.remove(id: connectionId)
                        }
                    }
                }
            }
        }
        
        // Keep the existing endpoint for backward compatibility
        let ws = routes.grouped("ws")
        ws.get("feature-flags") { req -> Response in
            guard let upgrade = req.headers[.upgrade].first?.lowercased(), upgrade == "websocket" else {
                throw ValidationError.failed("WebSocket upgrade required")
            }
            
            return req.webSocket { req, ws in
                let connectionId = UUID()
                req.logger.info("WebSocket connection established with ID: \(connectionId)")
                
                Task {
                    await req.services.webSocketService.add(ws, id: connectionId)
                    
                    ws.onClose.whenComplete { _ in
                        Task {
                            req.logger.info("WebSocket connection closed: \(connectionId)")
                            await req.services.webSocketService.remove(id: connectionId)
                        }
                    }
                }
            }
        }
    }
} 