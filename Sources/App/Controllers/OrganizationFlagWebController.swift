import Fluent
import Vapor

/// Controller for organization feature flag management web endpoints
struct OrganizationFlagWebController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Feature flag management routes
        routes.get(":organizationId", "flags", use: { @Sendable req in try await flagIndex(req: req) })
        routes.get(":organizationId", "flags", "create", use: { @Sendable req in try await createFlagForm(req: req) })
        routes.post(":organizationId", "flags", "create", use: { @Sendable req in try await createFlag(req: req) })
        routes.get(":organizationId", "flags", ":flagId", use: { @Sendable req in try await showFlag(req: req) })
        routes.get(":organizationId", "flags", ":flagId", "edit", use: { @Sendable req in try await editFlagForm(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "edit", use: { @Sendable req in try await updateFlag(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "delete", use: { @Sendable req in try await deleteFlag(req: req) })
        routes.post(":organizationId", "flags", ":flagId", "export", use: { @Sendable req in try await exportFlag(req: req) })
    }
    
    // MARK: - Feature Flag Management
    
    /// Show the feature flags for an organization
    @Sendable
    private func flagIndex(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is a member of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isMember(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be a member of this organization to view its feature flags")
        }
        
        // Check if user is an admin of this organization
        let isOrgAdmin = try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Get the organization's feature flags with pagination
        let featureFlagRepository = req.services.featureFlagRepository
        let paginationParams = PaginationParams.from(req)
        let paginatedFlags = try await featureFlagRepository.getAllForOrganization(
            organizationId: organizationId,
            params: paginationParams,
            baseUrl: req.url.string
        )
        let flags = paginatedFlags.data
        
        // Use standardized base context creation
        let baseContext = await req.createBaseViewContext(title: "\(organization.name) Feature Flags")
        
        // Create organization flags context with pagination
        let context = OrganizationFlagsViewContext(
            base: baseContext,
            organization: orgDTO,
            isAdmin: isOrgAdmin,
            flags: flags,
            flagsPagination: paginatedFlags.pagination
        )
        
        return try await req.view.render("organization-flags", context)
    }
    
    /// Show form to create a new feature flag
    @Sendable
    private func createFlagForm(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to create feature flags for this organization")
        }
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Use standardized base context creation
        let baseContext = await req.createBaseViewContext(title: "Create Feature Flag")
        
        // Create context
        let context = OrganizationFlagFormViewContext(
            base: baseContext,
            organization: orgDTO
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Create a new feature flag
    @Sendable
    private func createFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        // Check if user is an admin of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to create feature flags for this organization")
        }
        
        // Parse form data
        let formData = try req.content.decode(CreateFeatureFlagRequest.self)
        
        // Create the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        let flag = FeatureFlag.create(from: formData, userId: user.id!, organizationId: organizationId)
        try await featureFlagRepository.save(flag)
        
        // Redirect to the organization's feature flags list
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags")
    }
    
    /// Show feature flag details
    @Sendable
    private func showFlag(req: Request) async throws -> View {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Check if user is a member of this organization
        let organizationRepository = try req.organizationRepository()
        if !(try await organizationRepository.isMember(userId: user.id!, organizationId: organizationId)) {
            throw AuthorizationError.notAuthorized(reason: "You must be a member of this organization to view its feature flags")
        }
        
        // Check if user is an admin of this organization
        let isOrgAdmin = try await organizationRepository.isAdmin(userId: user.id!, organizationId: organizationId)
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Get the feature flag details
        let featureFlagService = req.services.featureFlagService
        let flag = try await featureFlagService.getFlagDetails(id: flagId, userId: user.id!)
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Get organization members for the override form
        let members = try await organizationRepository.getMembers(organizationId: organizationId)
        
        // Create base context
        // Use standardized base context creation
        let baseContext = await req.createBaseViewContext(title: "Feature Flag: \(flag.key)")
        
        // Create flag detail context
        let context = FlagDetailViewContext(
            base: baseContext,
            flag: flag,
            organization: orgDTO,
            canEdit: isOrgAdmin,
            members: members.map { $0.user }
        )
        
        return try await req.view.render("flag-detail", context)
    }
    
    /// Show form to edit a feature flag
    @Sendable
    private func editFlagForm(req: Request) async throws -> View {
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
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to edit feature flags for this organization")
        }
        
        // Get the organization
        let organizationService = try req.organizationService()
        let organization = try await organizationService.get(id: organizationId)
        let orgDTO = organizationService.createOrganizationDTO(from: organization)
        
        // Get the feature flag details
        let featureFlagService = req.services.featureFlagService
        let flag = try await featureFlagService.getFlagDetails(id: flagId, userId: user.id!)
        
        // Verify this flag belongs to this organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Use standardized base context creation
        let baseContext = await req.createBaseViewContext(title: "Edit Feature Flag")
        
        // Create context
        let context = OrganizationFlagFormViewContext(
            base: baseContext,
            organization: orgDTO,
            flag: flag
        )
        
        return try await req.view.render("organization-flag-form", context)
    }
    
    /// Update a feature flag
    @Sendable
    private func updateFlag(req: Request) async throws -> Response {
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
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to edit feature flags for this organization")
        }
        
        // Parse form data
        let formData = try req.content.decode(UpdateFeatureFlagRequest.self)
        
        // Get the feature flag
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        // Verify this flag belongs to the organization
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Update the flag
        flag.update(from: formData)
        try await featureFlagRepository.save(flag)
        
        // Redirect to the flag detail page
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags/\(flagId)")
    }
    
    /// Delete a feature flag
    @Sendable
    private func deleteFlag(req: Request) async throws -> Response {
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
            throw AuthorizationError.notAuthorized(reason: "You must be an admin to delete feature flags for this organization")
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
        
        // Delete the flag
        try await featureFlagRepository.delete(flag)
        
        // Redirect to the organization's feature flags list
        return req.redirect(to: "/dashboard/organizations/\(organizationId)/flags")
    }
    
    /// Export a feature flag to user's personal flags
    @Sendable
    private func exportFlag(req: Request) async throws -> Response {
        // Get the authenticated user
        let user = try req.auth.require(User.self)
        
        // Get the organization ID and flag ID
        guard let organizationId = req.parameters.get("organizationId", as: UUID.self) else {
            throw ValidationError.failed("Invalid organization ID")
        }
        
        guard let flagId = req.parameters.get("flagId", as: UUID.self) else {
            throw ValidationError.failed("Invalid flag ID")
        }
        
        // Verify the flag belongs to this organization before export
        let featureFlagRepository = req.services.featureFlagRepository
        guard let flag = try await featureFlagRepository.get(id: flagId) else {
            throw NotFoundError.featureFlag(flagId)
        }
        
        if flag.organizationId != organizationId {
            throw AuthorizationError.notAuthorized(reason: "This feature flag does not belong to this organization")
        }
        
        // Export the flag
        let featureFlagService = req.services.featureFlagService
        let exportedFlag = try await featureFlagService.exportFlagToPersonal(
            flagId: flagId,
            userId: user.id!
        )
        
        // Set success message as a flash message
        req.session.data["success"] = "Feature flag '\(exportedFlag.key)' exported to your personal flags successfully"
        
        // Redirect to the dashboard page with feature flags
        return req.redirect(to: "/dashboard")
    }
} 