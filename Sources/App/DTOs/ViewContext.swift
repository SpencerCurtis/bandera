import Vapor

struct ViewContext: Content {
    let title: String
    let isAuthenticated: Bool
    let error: String?
    let success: String?
    
    init(title: String, isAuthenticated: Bool = false, error: String? = nil, success: String? = nil) {
        self.title = title
        self.isAuthenticated = isAuthenticated
        self.error = error
        self.success = success
    }
}

struct DashboardContext: Content {
    let base: ViewContext
    let flags: [FeatureFlag]
    
    init(flags: [FeatureFlag], isAuthenticated: Bool = false) {
        self.base = ViewContext(
            title: "Dashboard",
            isAuthenticated: isAuthenticated
        )
        self.flags = flags
    }
}

struct FeatureFlagFormContext: Content {
    let base: ViewContext
    let flag: FeatureFlag?
    let error: String?
    
    init(flag: FeatureFlag? = nil, isAuthenticated: Bool = false, error: String? = nil) {
        self.base = ViewContext(
            title: flag == nil ? "Create Feature Flag" : "Edit Feature Flag",
            isAuthenticated: isAuthenticated,
            error: error
        )
        self.flag = flag
        self.error = error
    }
    
    init(create: FeatureFlag.Create, isAuthenticated: Bool = false, error: String? = nil) {
        self.base = ViewContext(
            title: "Create Feature Flag",
            isAuthenticated: isAuthenticated,
            error: error
        )
        self.flag = FeatureFlag(
            id: nil,
            key: create.key,
            type: create.type,
            defaultValue: create.defaultValue,
            description: create.description
        )
        self.error = error
    }
    
    init(update: FeatureFlag.Update, isAuthenticated: Bool = false, error: String? = nil) {
        self.base = ViewContext(
            title: "Edit Feature Flag",
            isAuthenticated: isAuthenticated,
            error: error
        )
        self.flag = FeatureFlag(
            id: update.id,
            key: update.key,
            type: update.type,
            defaultValue: update.defaultValue,
            description: update.description
        )
        self.error = error
    }
} 