import Vapor
import WebSocketKit

/// Controller for handling WebSocket connections
struct WebSocketController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware.standard)
        
        // Add the WebSocket endpoint at flags/socket to match the client
        protected.get("flags", "socket") { req -> Response in
            guard let upgrade = req.headers[.upgrade].first?.lowercased(), upgrade == "websocket" else {
                throw BanderaError.validationFailed("WebSocket upgrade required")
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
        let ws = protected.grouped("ws")
        ws.get("feature-flags") { req -> Response in
            guard let upgrade = req.headers[.upgrade].first?.lowercased(), upgrade == "websocket" else {
                throw BanderaError.validationFailed("WebSocket upgrade required")
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