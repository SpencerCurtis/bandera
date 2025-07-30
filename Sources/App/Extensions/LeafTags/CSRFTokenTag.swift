import Vapor
import Leaf

/// Leaf tag for generating CSRF token hidden input fields
/// Usage in templates: #csrfToken()
struct CSRFTokenTag: UnsafeUnescapedLeafTag {
    
    func render(_ ctx: LeafContext) throws -> LeafData {
        // Get the request from the context
        guard let req = ctx.request else {
            throw Abort(.internalServerError, reason: "Request not available in context")
        }
        
        // Get the CSRF token from the request
        let token = req.csrfToken
        
        // Generate the hidden input HTML
        let html = "<input type=\"hidden\" name=\"csrf_token\" value=\"\(token)\">"
        
        return LeafData.string(html)
    }
}

/// Leaf tag for getting just the CSRF token value (for AJAX requests)
/// Usage in templates: #csrfValue()
struct CSRFValueTag: LeafTag {
    
    func render(_ ctx: LeafContext) throws -> LeafData {
        // Get the request from the context
        guard let req = ctx.request else {
            throw Abort(.internalServerError, reason: "Request not available in context")
        }
        
        // Return the CSRF token value
        return LeafData.string(req.csrfToken)
    }
} 