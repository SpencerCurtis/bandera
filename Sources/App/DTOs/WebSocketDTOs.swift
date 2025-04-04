import Vapor

// MARK: - Message DTOs

/// Generic WebSocket message structure
struct WebSocketMessage<T: Codable>: Codable {
    /// The event type
    let event: String
    
    /// The data payload
    let data: T
}

// MARK: - Feature Flag Event DTOs

/// Feature flag event types
enum FeatureFlagEventType: String, Codable {
    /// Event when a feature flag is created
    case created = "feature_flag.created"
    
    /// Event when a feature flag is updated
    case updated = "feature_flag.updated"
    
    /// Event when a feature flag is deleted
    case deleted = "feature_flag.deleted"
    
    /// Event when a feature flag override is created
    case overrideCreated = "feature_flag.override.created"
    
    /// Event when a feature flag override is updated
    case overrideUpdated = "feature_flag.override.updated"
    
    /// Event when a feature flag override is deleted
    case overrideDeleted = "feature_flag.override.deleted"
}

/// Feature flag data for WebSocket events
struct FeatureFlagWebSocketData: Codable {
    /// The feature flag ID
    let id: UUID
    
    /// The feature flag key
    let key: String
    
    /// The feature flag value
    let value: String
    
    /// The user ID associated with the feature flag
    let userId: UUID
    
    /// Initialize from a FeatureFlag model
    init(from featureFlag: FeatureFlag) {
        self.id = featureFlag.id!
        self.key = featureFlag.key
        self.value = featureFlag.defaultValue
        self.userId = featureFlag.userId!
    }
}

/// Feature flag event DTO for created and updated events
struct FeatureFlagEventPayload: Codable {
    /// The event type
    let event: FeatureFlagEventType
    
    /// The feature flag data
    let flag: FeatureFlagResponse
}

/// Feature flag deleted event DTO
struct FeatureFlagDeleteEventPayload: Codable {
    /// The event type
    let event: FeatureFlagEventType
    
    /// The ID of the deleted feature flag
    let flagId: UUID
    
    /// The user ID associated with the deletion
    let userId: UUID
} 