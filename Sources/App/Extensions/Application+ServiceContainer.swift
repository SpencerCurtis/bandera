import Vapor

// Define a storage key for the service container
private struct ServiceContainerKey: StorageKey {
    typealias Value = ServiceContainer
}

extension Application {
    /// Access to the service container
    var serviceContainer: ServiceContainer {
        get {
            if let container = storage[ServiceContainerKey.self] {
                return container
            }
            
            let container = ServiceContainer(app: self)
            storage[ServiceContainerKey.self] = container
            return container
        }
        set {
            storage[ServiceContainerKey.self] = newValue
        }
    }
}

// Extending Request to access the service container
extension Request {
    /// Access to the application's service container
    var services: ServiceContainer {
        application.serviceContainer
    }
    
    /// Get the organization repository from the service container
    func organizationRepository() throws -> OrganizationRepositoryProtocol {
        return services.organizationRepository
    }
    
    /// Get the organization service from the service container
    func organizationService() throws -> OrganizationServiceProtocol {
        return services.organizationService
    }
    
    /// Get the cache service from the service container
    func cacheService() throws -> CacheServiceProtocol {
        return services.cacheService
    }
}