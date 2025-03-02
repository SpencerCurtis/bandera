import Vapor

// MARK: - Legacy View Contexts (Deprecated)

@available(*, deprecated, message: "Use ViewContextDTOs.BaseContext instead")
typealias ViewContext = ViewContextDTOs.BaseContext

@available(*, deprecated, message: "Use ViewContextDTOs.DashboardContext instead")
typealias DashboardContext = ViewContextDTOs.DashboardContext

@available(*, deprecated, message: "Use ViewContextDTOs.FeatureFlagFormContext instead")
typealias FeatureFlagFormContext = ViewContextDTOs.FeatureFlagFormContext 