import Vapor
import WebSocketKit

/// Controller for handling WebSocket connections
struct WebSocketController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Handle WebSocket connections for feature flag updates
        // We now register routes directly without re-adding middleware
        // since middleware will be applied at registration time in routes.swift
        
        // WebSocket endpoint for feature flag updates 
        // This route requires authentication which should be applied in routes.swift
        routes.webSocket("ws", "feature-flags") { req, ws in
            req.logger.info("WebSocket connection established")
            
            // Send initial feature flags
            if let userId = req.auth.get(UserJWTPayload.self)?.subject.value,
               let userIdUUID = UUID(userId) {
                Task<Void, Never> {
                    do {
                        let flags = try await req.services.featureFlagService.getAllFlags(userId: userIdUUID)
                        
                        // Format the flags as JSON
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                        
                        let flagsPayload = flags.map { flag in
                            return [
                                "id": flag.id?.uuidString ?? "",
                                "key": flag.key,
                                "value": flag.defaultValue,
                                "valueType": flag.type.rawValue,
                                "updatedAt": formatter.string(from: flag.updatedAt ?? Date())
                            ]
                        }
                        
                        // Convert to JSON
                        let json = try JSONSerialization.data(withJSONObject: [
                            "type": "initialData",
                            "flagsUrl": "/api/flags",
                            "flags": flagsPayload
                        ])
                        
                        try await ws.send([UInt8](json))
                    } catch {
                        req.logger.error("Error sending initial data to WebSocket: \(error)")
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
                
                Task<Void, Never> {
                    await req.services.webSocketService.add(ws, id: connectionId)
                    
                    ws.onText { ws, text in
                        req.logger.debug("Received text message: \(text)")
                    }
                    
                    ws.onBinary { ws, binary in
                        req.logger.debug("Received binary message of \(binary.readableBytes) bytes")
                    }
                    
                    ws.onClose.whenComplete { result in
                        Task<Void, Never> {
                            await req.services.webSocketService.remove(id: connectionId)
                            req.logger.info("WebSocket connection closed with ID: \(connectionId)")
                        }
                    }
                }
            }
        }
        
        // Keep the existing endpoint for backward compatibility
        routes.get("ws", "feature-flags") { req -> Response in
            guard let upgrade = req.headers[.upgrade].first?.lowercased(), upgrade == "websocket" else {
                throw ValidationError.failed("WebSocket upgrade required")
            }
            
            return req.webSocket { req, ws in
                let connectionId = UUID()
                req.logger.info("WebSocket connection established with ID: \(connectionId)")
                
                Task<Void, Never> {
                    await req.services.webSocketService.add(ws, id: connectionId)
                    
                    ws.onText { ws, text in
                        req.logger.debug("Received text message: \(text)")
                    }
                    
                    ws.onBinary { ws, binary in
                        req.logger.debug("Received binary message of \(binary.readableBytes) bytes")
                    }
                    
                    ws.onClose.whenComplete { result in
                        Task<Void, Never> {
                            await req.services.webSocketService.remove(id: connectionId)
                            req.logger.info("WebSocket connection closed with ID: \(connectionId)")
                        }
                    }
                }
            }
        }
    }
} 