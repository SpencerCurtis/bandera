import Vapor

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