import Foundation

extension Sequence {
    /// Maps a sequence asynchronously.
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values = [T]()
        
        for element in self {
            try await values.append(transform(element))
        }
        
        return values
    }
    
    /// Filters a sequence asynchronously.
    func asyncFilter(_ isIncluded: (Element) async throws -> Bool) async throws -> [Element] {
        var values = [Element]()
        
        for element in self {
            if try await isIncluded(element) {
                values.append(element)
            }
        }
        
        return values
    }
} 