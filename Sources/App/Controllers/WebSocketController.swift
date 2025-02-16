import Vapor
import WebSocketKit

struct WebSocketController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserAuthMiddleware())
        let ws = protected.grouped("ws")
        
        ws.get("feature-flags") { req -> Response in
            guard let upgrade = req.headers[.upgrade].first?.lowercased(), upgrade == "websocket" else {
                throw Abort(.badRequest, reason: "WebSocket upgrade required")
            }
            
            return req.webSocket { req, ws in
                let connectionId = UUID()
                req.logger.info("WebSocket connection established with ID: \(connectionId)")
                
                Task {
                    await req.application.webSocketService.add(ws, id: connectionId)
                    
                    ws.onClose.whenComplete { _ in
                        Task {
                            req.logger.info("WebSocket connection closed: \(connectionId)")
                            await req.application.webSocketService.remove(id: connectionId)
                        }
                    }
                }
            }
        }
    }
} 