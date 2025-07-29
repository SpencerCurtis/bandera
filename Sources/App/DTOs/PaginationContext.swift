import Vapor

/// Generic struct for paginated results
struct PaginatedResult<T: Content>: Content {
    /// The paginated data
    let data: [T]
    
    /// Pagination metadata
    let pagination: PaginationContext
    
    /// Create a new paginated result
    /// - Parameters:
    ///   - data: The paginated data
    ///   - pagination: The pagination context
    init(data: [T], pagination: PaginationContext) {
        self.data = data
        self.pagination = pagination
    }
}

/// Context for pagination in views
struct PaginationContext: Content {
    /// Current page number (1-based)
    let currentPage: Int
    
    /// Total number of pages
    let totalPages: Int
    
    /// Total number of items
    let totalItems: Int
    
    /// Number of items per page
    let perPage: Int
    
    /// Base URL for pagination links
    let baseUrl: String
    
    /// Has previous page
    var hasPrevious: Bool {
        return currentPage > 1
    }
    
    /// Has next page
    var hasNext: Bool {
        return currentPage < totalPages
    }
    
    /// Previous page number
    var previousPage: Int {
        return max(1, currentPage - 1)
    }
    
    /// Next page number
    var nextPage: Int {
        return min(totalPages, currentPage + 1)
    }
    
    /// Create a new pagination context
    /// - Parameters:
    ///   - currentPage: Current page number (1-based)
    ///   - totalItems: Total number of items
    ///   - perPage: Number of items per page
    ///   - baseUrl: Base URL for pagination links
    init(currentPage: Int, totalItems: Int, perPage: Int, baseUrl: String) {
        self.currentPage = max(1, currentPage)
        self.totalItems = totalItems
        self.perPage = max(1, perPage)
        self.baseUrl = baseUrl
        
        // Calculate total pages
        self.totalPages = Int(ceil(Double(totalItems) / Double(perPage)))
    }
}

/// Pagination parameters extracted from request query
struct PaginationParams {
    /// Current page number (1-based)
    let page: Int
    
    /// Number of items per page
    let perPage: Int
    
    /// Offset for database query
    var offset: Int {
        return (page - 1) * perPage
    }
    
    /// Default per page value
    static let defaultPerPage = 25
    
    /// Maximum per page value
    static let maxPerPage = 100
    
    /// Create pagination parameters from request
    /// - Parameter req: The HTTP request containing query parameters
    /// - Returns: Validated pagination parameters
    static func from(_ req: Request) -> PaginationParams {
        let page = max(1, req.query["page"] ?? 1)
        let perPage = min(maxPerPage, max(1, req.query["per_page"] ?? defaultPerPage))
        
        return PaginationParams(page: page, perPage: perPage)
    }
    
    /// Create pagination parameters with explicit values
    /// - Parameters:
    ///   - page: Page number (1-based)
    ///   - perPage: Items per page
    init(page: Int = 1, perPage: Int = defaultPerPage) {
        self.page = max(1, page)
        self.perPage = min(Self.maxPerPage, max(1, perPage))
    }
} 