import Vapor
import Fluent

/// Utilities for pagination operations
enum PaginationUtilities {
    
    /// Execute a paginated query and return results with pagination context
    /// - Parameters:
    ///   - query: The Fluent query builder
    ///   - params: Pagination parameters
    ///   - baseUrl: Base URL for pagination links
    /// - Returns: Paginated result with data and pagination context
    static func paginate<T: Model>(
        _ query: QueryBuilder<T>,
        params: PaginationParams,
        baseUrl: String
    ) async throws -> PaginatedResult<T> {
        // Get total count
        let totalItems = try await query.copy().count()
        
        // Get paginated results
        let data = try await query
            .offset(params.offset)
            .limit(params.perPage)
            .all()
        
        // Create pagination context
        let pagination = PaginationContext(
            currentPage: params.page,
            totalItems: totalItems,
            perPage: params.perPage,
            baseUrl: baseUrl
        )
        
        return PaginatedResult(data: data, pagination: pagination)
    }
    
    /// Execute a paginated query with sorting and return results with pagination context
    /// - Parameters:
    ///   - query: The Fluent query builder
    ///   - params: Pagination parameters
    ///   - sortKey: The key path to sort by
    ///   - sortDirection: The sort direction
    ///   - baseUrl: Base URL for pagination links
    /// - Returns: Paginated result with data and pagination context
    static func paginate<T: Model, Field>(
        _ query: QueryBuilder<T>,
        params: PaginationParams,
        sortBy sortKey: KeyPath<T, Field>,
        direction sortDirection: DatabaseQuery.Sort.Direction = .ascending,
        baseUrl: String
    ) async throws -> PaginatedResult<T> where Field: QueryableProperty, Field.Model == T {
        // Get total count
        let totalItems = try await query.copy().count()
        
        // Get paginated results with sorting
        let data = try await query
            .sort(sortKey, sortDirection)
            .offset(params.offset)
            .limit(params.perPage)
            .all()
        
        // Create pagination context
        let pagination = PaginationContext(
            currentPage: params.page,
            totalItems: totalItems,
            perPage: params.perPage,
            baseUrl: baseUrl
        )
        
        return PaginatedResult(data: data, pagination: pagination)
    }
    
    /// Execute a paginated query with custom transformation and return results with pagination context
    /// - Parameters:
    ///   - query: The Fluent query builder
    ///   - params: Pagination parameters
    ///   - baseUrl: Base URL for pagination links
    ///   - transform: Transformation function to apply to each item
    /// - Returns: Paginated result with transformed data and pagination context
    static func paginate<T: Model, U: Content>(
        _ query: QueryBuilder<T>,
        params: PaginationParams,
        baseUrl: String,
        transform: @escaping (T) -> U
    ) async throws -> PaginatedResult<U> {
        // Get total count
        let totalItems = try await query.copy().count()
        
        // Get paginated results
        let models = try await query
            .offset(params.offset)
            .limit(params.perPage)
            .all()
        
        // Transform the data
        let data = models.map(transform)
        
        // Create pagination context
        let pagination = PaginationContext(
            currentPage: params.page,
            totalItems: totalItems,
            perPage: params.perPage,
            baseUrl: baseUrl
        )
        
        return PaginatedResult(data: data, pagination: pagination)
    }
    
    /// Execute a paginated query with custom sorting and transformation
    /// - Parameters:
    ///   - query: The Fluent query builder
    ///   - params: Pagination parameters
    ///   - sortKey: The key path to sort by
    ///   - sortDirection: The sort direction
    ///   - baseUrl: Base URL for pagination links
    ///   - transform: Transformation function to apply to each item
    /// - Returns: Paginated result with transformed data and pagination context
    static func paginate<T: Model, Field, U: Content>(
        _ query: QueryBuilder<T>,
        params: PaginationParams,
        sortBy sortKey: KeyPath<T, Field>,
        direction sortDirection: DatabaseQuery.Sort.Direction = .ascending,
        baseUrl: String,
        transform: @escaping (T) -> U
    ) async throws -> PaginatedResult<U> where Field: QueryableProperty, Field.Model == T {
        // Get total count
        let totalItems = try await query.copy().count()
        
        // Get paginated results with sorting
        let models = try await query
            .sort(sortKey, sortDirection)
            .offset(params.offset)
            .limit(params.perPage)
            .all()
        
        // Transform the data
        let data = models.map(transform)
        
        // Create pagination context
        let pagination = PaginationContext(
            currentPage: params.page,
            totalItems: totalItems,
            perPage: params.perPage,
            baseUrl: baseUrl
        )
        
        return PaginatedResult(data: data, pagination: pagination)
    }
} 