import Vapor
import Leaf

/// A Leaf tag that safely counts collection items even if the collection is nil
/// Usage: #safeCount(collection)
struct SafeCountTag: LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        // Make sure there's at least one parameter
        guard ctx.parameters.count > 0 else {
            return .int(0)
        }
        
        // Get the first parameter
        let param = ctx.parameters[0]
        
        // Simplest implementation - just get the count from whatever collection type
        // or return 0 if it's not a collection or is nil
        let count = param.array?.count ?? param.dictionary?.count ?? param.string?.count ?? 0
        return .int(count)
    }
}

/// Register the SafeCountTag with Leaf
extension Application {
    func registerSafeCountTag() {
        self.leaf.tags["safeCount"] = SafeCountTag()
    }
} 