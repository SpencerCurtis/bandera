import Fluent
import Vapor

/// Controller for organization feature flag override management web endpoints
struct OrganizationFlagOverrideWebController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Feature flag override routes
        routes.get(":organizationId", "flags", ":flagId", "overrides", "create", use: { @Sendable req in try await createOverrideForm(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "overrides", use: { @Sendable req in try await addOverride(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "overrides", ":overrideId", "delete", use: { @Sendable req in try await deleteOverride(req: req) })
    }
    
    // MARK: - Feature Flag Overrides
    
    /// Show form to create a feature flag override
    @Sendable
    private func createOverrideForm(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to add overrides for this organization")
        }
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Get organization members for the override form
        let members = try await organizationRepository.getMembers(organizationId: organizationId)
        
        // Create base context
        let baseContext = BaseViewContext(
            title: "Add Feature Flag Override",
            isAuthenticated: true,
            isAdmin: user.isAdmin,
            user: user
        )
        
        // Create override form context
        let context = FeatureFlagOverrideFormViewContext(
            base: baseContext,
            flag: flag,
            organization: orgDTO,
            allUsers: members.map { UserResponse(user: $0.user) }
        )
        
        return try await req.view.render("feature-flag-override-form", context)
    }
    
    /// Add an override for a feature flag
    @Sendable
    private func addOverride(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to add overrides for this organization")
        }
        
        // Parse form data
        struct OverrideForm: Content {
            let userId: UUID
            let value: String
        }
        let formData = try req.content.decode(OverrideForm.self)
        
        // Verify the user is a member of this organization
        if !(try await organizationRepository.isMember(userId: formData.userId, organizationId: organizationId)) {
            req.session.flash(.error, "The selected user is not a member of this organization")
            return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags/\(flagId)")
        }
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Create or update the override
        let override = UserFeatureFlag(
            featureFlagId: flagId,
            userId: formData.userId,
            value: formData.value
        )
        try await featureFlagRepository.saveOverride(override)
        
        // Create audit log
        try await featureFlagRepository.createAuditLog(
            type: "override_created",
            message: "Created override for user \(formData.userId)",
            flagId: flagId,
            userId: user.id!
        )
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags/\(flagId)")
    }
    
    /// Delete an override for a feature flag
    @Sendable
    private func deleteOverride(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID, flag ID, and override ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        guard let overrideId = req.parameters.get("overrideId", as: UUID.self) else {
            throw ValidationError.failed("Invalid override ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to delete overrides for this organization")
        }
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Get the override
        guard let override = try await featureFlagRepository.findOverride(id: overrideId) else {
            throw ResourceError.notFound("Override with ID \(overrideId)")
        }
        
        // Verify the override belongs to this flag
        if override.$featureFlag.id != flagId {
            throw AuthorizationError.notAuthorized(reason: "This override does not belong to this feature flag")
        }
        
        // Verify the override belongs to a user in this organization
        if !(try await organizationRepository.isMember(userId: override.$user.id, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "This override does not belong to a user in this organization")
        }
        
        // Delete the override
        try await featureFlagRepository.deleteOverride(override)
        
        // Create audit log
        try await featureFlagRepository.createAuditLog(
            type: "override_deleted",
            message: "Deleted override for user \(override.$user.id)",
            flagId: flagId,
            userId: user.id!
        )
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags/\(flagId)")
    }
} 