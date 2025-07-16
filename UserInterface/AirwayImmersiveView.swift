//
//  AirwayImmersiveView.swift
//  AirwayVision
//
//  Immersive view for full Vision Pro airway exploration experience
//

import SwiftUI
import RealityKit
import ARKit

struct AirwayImmersiveView: View {
    @EnvironmentObject private var appModel: AirwayAppModel
    @EnvironmentObject private var navigationModel: BronchoscopyNavigationModel
    @EnvironmentObject private var anchorModel: SpatialAnchorModel
    
    @State private var showingFloatingControls = true
    @State private var endoscopeMode = false
    @State private var immersiveContent: RealityViewContent?
    
    var body: some View {
        RealityView { content in
            await setupImmersiveContent(content)
            immersiveContent = content
            
        } update: { content in
            await updateImmersiveContent(content)
            
        } attachments: {
            // Floating control panel
            if showingFloatingControls {
                Attachment(id: "controls") {
                    FloatingControlPanel(endoscopeMode: $endoscopeMode)
                        .frame(width: 400, height: 200)
                        .background(.regularMaterial, in: .rect(cornerRadius: 20))
                }
            }
            
            // Endoscopic view overlay
            if endoscopeMode {
                Attachment(id: "endoscope") {
                    EndoscopeOverlay()
                        .frame(width: 600, height: 400)
                        .background(.black.opacity(0.9), in: .rect(cornerRadius: 30))
                }
            }
            
            // Educational information panel
            if let eduInfo = navigationModel.currentEducationalInfo {
                Attachment(id: "education") {
                    EducationalInfoPanel(info: eduInfo)
                        .frame(width: 350, height: 250)
                        .background(.regularMaterial, in: .rect(cornerRadius: 15))
                }
            }
        }
        .gesture(immersiveGestures)
    }
    
    // MARK: - Immersive Gestures
    
    private var immersiveGestures: some Gesture {
        // Spatial gesture support for Vision Pro
        SpatialTapGesture()
            .onEnded { value in
                handleSpatialTap(at: value.location3D)
            }
            .simultaneously(with:
                DragGesture()
                    .onChanged { value in
                        if navigationModel.navigationState == .navigating {
                            handleNavigationDrag(value)
                        }
                    }
            )
    }
    
    // MARK: - Content Setup
    
    @MainActor
    private func setupImmersiveContent(_ content: RealityViewContent) async {
        // Setup immersive environment
        setupImmersiveEnvironment(content)
        
        // Load airway model in immersive space
        if let currentModel = appModel.currentModel {
            await loadImmersiveAirwayModel(currentModel, into: content)
        }
        
        // Setup spatial anchoring
        await setupSpatialAnchoring(content)
        
        // Position floating attachments
        positionFloatingAttachments(content)
    }
    
    @MainActor
    private func updateImmersiveContent(_ content: RealityViewContent) async {
        // Update navigation visualization
        updateImmersiveNavigation(content)
        
        // Update endoscope mode if active
        if endoscopeMode {
            updateEndoscopeView(content)
        }
        
        // Update attachment positions
        updateAttachmentPositions(content)
    }
    
    private func setupImmersiveEnvironment(_ content: RealityViewContent) {
        // Create immersive medical environment
        let environment = Entity()
        environment.name = "ImmersiveEnvironment"
        
        // Add subtle ambient lighting suitable for medical visualization
        let ambientLight = Entity()
        let ambientComponent = ImageBasedLight(
            source: .single(try! .load(named: "medical_environment", in: Bundle.main)),
            intensityExponent: 0.2
        )
        ambientLight.components.set(ambientComponent)
        environment.addChild(ambientLight)
        
        // Add procedural ground plane for depth reference
        let groundPlane = Entity()
        let groundMesh = MeshResource.generatePlane(width: 10, depth: 10)
        let groundMaterial = SimpleMaterial(
            color: .gray.withAlphaComponent(0.1),
            isMetallic: false
        )
        groundPlane.components.set(ModelComponent(mesh: groundMesh, materials: [groundMaterial]))
        groundPlane.position.y = -0.5
        environment.addChild(groundPlane)
        
        content.add(environment)
    }
    
    @MainActor
    private func loadImmersiveAirwayModel(_ model: AirwayModel, into content: RealityViewContent) async {
        do {
            // Load airway mesh with immersive scaling
            let airwayEntity = try await loadAirwayMesh(for: model)
            
            // Scale for immersive viewing - larger than window mode
            airwayEntity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
            
            // Position in front of user
            airwayEntity.position = SIMD3<Float>(0, 1.5, -2)
            
            // Apply immersive materials
            applyImmersiveMaterials(to: airwayEntity)
            
            // Add physics for interaction
            addPhysicsComponents(to: airwayEntity)
            
            // Load centerline for navigation
            let centerlineData = try await loadCenterlineData(for: model)
            let centerlineEntity = createImmersiveCenterline(from: centerlineData)
            centerlineEntity.parent = airwayEntity
            
            content.add(airwayEntity)
            
            // Update app model
            appModel.airwayEntities = [airwayEntity, centerlineEntity]
            
        } catch {
            print("Error loading immersive airway model: \(error)")
        }
    }
    
    private func setupSpatialAnchoring(_ content: RealityViewContent) async {
        // Enable spatial anchoring in immersive mode
        if let arView = content as? ARView {
            await anchorModel.initializeWithSession(arView.session)
        }
        
        // Auto-anchor the airway model if enabled
        if anchorModel.autoAnchoringEnabled,
           let airwayEntity = appModel.airwayEntities.first {
            try? await anchorModel.anchorAirwayModel(airwayEntity)
        }
    }
    
    private func positionFloatingAttachments(_ content: RealityViewContent) {
        // Position control panel attachment
        if let controlsAttachment = content.attachments["controls"] {
            controlsAttachment.position = SIMD3<Float>(-1.2, 1.8, -1.5)
            controlsAttachment.orientation = simd_quatf(angle: 0.1, axis: [0, 1, 0])
        }
        
        // Position educational panel
        if let educationAttachment = content.attachments["education"] {
            educationAttachment.position = SIMD3<Float>(1.2, 1.6, -1.8)
            educationAttachment.orientation = simd_quatf(angle: -0.1, axis: [0, 1, 0])
        }
        
        // Position endoscope overlay if active
        if let endoscopeAttachment = content.attachments["endoscope"] {
            endoscopeAttachment.position = SIMD3<Float>(0, 1.8, -1.0)
        }
    }
    
    private func updateAttachmentPositions(_ content: RealityViewContent) {
        // Keep attachments positioned relative to user
        // This would track head position and adjust accordingly
    }
    
    // MARK: - Airway Model Loading
    
    private func loadAirwayMesh(for model: AirwayModel) async throws -> Entity {
        guard let meshURL = Bundle.main.url(forResource: model.id, withExtension: "usd", subdirectory: "PrebuiltModels/Meshes") else {
            throw AirwayVisionError.modelNotFound
        }
        
        let entity = try await Entity(contentsOf: meshURL)
        entity.name = "ImmersiveAirwayMesh_\(model.id)"
        
        return entity
    }
    
    private func loadCenterlineData(for model: AirwayModel) async throws -> [CenterlinePoint] {
        guard let centerlineURL = Bundle.main.url(forResource: model.id, withExtension: "json", subdirectory: "PrebuiltModels/Centerlines") else {
            throw AirwayVisionError.centerlineNotFound
        }
        
        let data = try Data(contentsOf: centerlineURL)
        let branches = try JSONDecoder().decode([AirwayBranch].self, from: data)
        
        return branches.flatMap { $0.centerlinePoints }
    }
    
    private func createImmersiveCenterline(from points: [CenterlinePoint]) -> Entity {
        let centerlineEntity = Entity()
        centerlineEntity.name = "ImmersiveCenterline"
        
        // Create more prominent centerline for immersive viewing
        for i in 0..<(points.count - 1) {
            let startPoint = points[i]
            let endPoint = points[i + 1]
            
            let segment = createImmersiveLineSegment(from: startPoint.position, to: endPoint.position)
            centerlineEntity.addChild(segment)
        }
        
        // Add generation markers
        for point in points where point.generation <= 3 {
            let marker = createGenerationMarker(at: point)
            centerlineEntity.addChild(marker)
        }
        
        return centerlineEntity
    }
    
    private func createImmersiveLineSegment(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Entity {
        let direction = end - start
        let length = length(direction)
        let center = (start + end) / 2
        
        let entity = Entity()
        entity.position = center
        
        // Thicker line for immersive viewing
        let mesh = MeshResource.generateCylinder(height: length, radius: 0.003)
        let material = UnlitMaterial(color: .cyan.withAlphaComponent(0.8))
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        // Orient along direction
        let up = SIMD3<Float>(0, 1, 0)
        let normalizedDirection = normalize(direction)
        let rotation = simd_quatf(from: up, to: normalizedDirection)
        entity.orientation = rotation
        
        return entity
    }
    
    private func createGenerationMarker(at point: CenterlinePoint) -> Entity {
        let entity = Entity()
        entity.position = point.position
        
        // Color-coded by generation
        let colors: [UIColor] = [.red, .orange, .yellow, .green, .blue, .purple]
        let color = colors[min(point.generation, colors.count - 1)]
        
        let mesh = MeshResource.generateSphere(radius: 0.008)
        let material = SimpleMaterial(color: color, isMetallic: false)
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        // Add glow effect
        entity.components.set(GroundingShadowComponent(castsShadow: true))
        
        return entity
    }
    
    // MARK: - Visual Enhancements
    
    private func applyImmersiveMaterials(to entity: Entity) {
        guard let modelComponent = entity.components[ModelComponent.self] else { return }
        
        // Enhanced materials for immersive viewing
        var materials: [Material] = []
        
        switch appModel.visualizationMode {
        case .anatomical:
            // Realistic tissue with subsurface scattering
            let material = SimpleMaterial(
                color: .systemPink.withAlphaComponent(0.9),
                roughness: .float(0.3),
                isMetallic: false
            )
            materials = [material]
            
        case .educational:
            // High-contrast educational material
            let material = UnlitMaterial(color: .systemBlue)
            materials = [material]
            
        case .pathological:
            // Color-coded pathology with emission
            let material = SimpleMaterial(
                color: .systemRed.withAlphaComponent(0.8),
                roughness: .float(0.2),
                isMetallic: false
            )
            materials = [material]
            
        case .transparent:
            // Glass-like transparency
            let material = SimpleMaterial(
                color: .white.withAlphaComponent(0.4),
                roughness: .float(0.1),
                isMetallic: false
            )
            materials = [material]
            
        case .crossSection:
            // Cross-section visualization
            let material = UnlitMaterial(color: .systemTeal)
            materials = [material]
        }
        
        entity.components.set(ModelComponent(mesh: modelComponent.mesh, materials: materials))
    }
    
    private func addPhysicsComponents(to entity: Entity) {
        // Add physics for interaction in immersive mode
        entity.components.set(InputTargetComponent(allowedInputTypes: .all))
        
        if let mesh = entity.model?.mesh {
            entity.components.set(CollisionComponent(shapes: [.generateConvex(from: mesh)]))
        }
        
        // Add gesture recognizers
        entity.components.set(HoverEffectComponent())
    }
    
    // MARK: - Navigation Updates
    
    private func updateImmersiveNavigation(_ content: RealityViewContent) {
        // Update navigation visualization for immersive mode
        updateNavigationPath(content)
        updateCurrentPosition(content)
        updateViewDirection(content)
    }
    
    private func updateNavigationPath(_ content: RealityViewContent) {
        // Highlight current navigation path
        if let pathEntity = content.entities.first(where: { $0.name == "NavigationPath" }) {
            content.remove(pathEntity)
        }
        
        if navigationModel.navigationState == .navigating {
            let pathEntity = createNavigationPath()
            content.add(pathEntity)
        }
    }
    
    private func createNavigationPath() -> Entity {
        let pathEntity = Entity()
        pathEntity.name = "NavigationPath"
        
        // Create glowing path from current position forward
        // This would use the current branch and progress to show where navigation is heading
        
        return pathEntity
    }
    
    private func updateCurrentPosition(_ content: RealityViewContent) {
        // Update position indicator
        if let indicator = content.entities.first(where: { $0.name == "ImmersivePositionIndicator" }) {
            content.remove(indicator)
        }
        
        if navigationModel.navigationState != .idle {
            let indicator = createImmersivePositionIndicator()
            content.add(indicator)
        }
    }
    
    private func createImmersivePositionIndicator() -> Entity {
        let entity = Entity()
        entity.name = "ImmersivePositionIndicator"
        entity.position = navigationModel.currentPosition
        
        // Pulsing indicator
        let mesh = MeshResource.generateSphere(radius: 0.015)
        let material = UnlitMaterial(color: .cyan)
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        // Add pulsing animation
        entity.addAnimationController(createPulsingAnimation())
        
        return entity
    }
    
    private func createPulsingAnimation() -> AnimationPlaybackController {
        // Create pulsing scale animation
        let scaleAnimation = FromToByAnimation(
            from: Transform(scale: SIMD3<Float>(1, 1, 1)),
            to: Transform(scale: SIMD3<Float>(1.5, 1.5, 1.5)),
            duration: 1.0,
            timing: .easeInOut,
            isAdditive: false
        )
        
        return Entity().playAnimation(scaleAnimation.repeat())
    }
    
    private func updateViewDirection(_ content: RealityViewContent) {
        // Show view direction for navigation
        if endoscopeMode {
            updateEndoscopeViewDirection(content)
        }
    }
    
    private func updateEndoscopeViewDirection(_ content: RealityViewContent) {
        // Update endoscope view direction visualization
        if let viewCone = content.entities.first(where: { $0.name == "EndoscopeViewCone" }) {
            content.remove(viewCone)
        }
        
        let viewCone = createEndoscopeViewCone()
        content.add(viewCone)
    }
    
    private func createEndoscopeViewCone() -> Entity {
        let entity = Entity()
        entity.name = "EndoscopeViewCone"
        entity.position = navigationModel.currentPosition
        
        // Create cone showing field of view
        let mesh = MeshResource.generateCone(height: 0.1, radius: 0.05)
        let material = UnlitMaterial(color: .green.withAlphaComponent(0.3))
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        // Orient in look direction
        let forward = navigationModel.lookDirection
        let up = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(from: up, to: forward)
        entity.orientation = rotation
        
        return entity
    }
    
    private func updateEndoscopeView(_ content: RealityViewContent) {
        // Update endoscope overlay content
        // This would render the view from inside the airway
    }
    
    // MARK: - Gesture Handling
    
    private func handleSpatialTap(at location: SIMD3<Float>) {
        // Handle spatial taps in immersive space
        if navigationModel.navigationState == .navigating {
            // Navigate to tapped location if on centerline
            navigateToLocation(location)
        } else {
            // Show information about tapped location
            showLocationInfo(at: location)
        }
    }
    
    private func handleNavigationDrag(_ gesture: DragGesture.Value) {
        // Handle drag gestures for navigation
        navigationModel.handleDragGesture(translation: gesture.translation)
    }
    
    private func navigateToLocation(_ location: SIMD3<Float>) {
        // Find nearest centerline point and navigate there
        // Implementation would find closest point on centerline and jump to it
    }
    
    private func showLocationInfo(at location: SIMD3<Float>) {
        // Show information panel at tapped location
        // Implementation would create temporary info panel
    }
}

// MARK: - Supporting Views

struct FloatingControlPanel: View {
    @EnvironmentObject private var navigationModel: BronchoscopyNavigationModel
    @EnvironmentObject private var appModel: AirwayAppModel
    @Binding var endoscopeMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Navigation Controls")
                    .font(.headline)
                Spacer()
                Button(endoscopeMode ? "Exit Endoscope" : "Endoscope Mode") {
                    endoscopeMode.toggle()
                }
                .buttonStyle(.bordered)
            }
            
            if navigationModel.navigationState == .navigating {
                VStack(spacing: 8) {
                    HStack {
                        Button("◀︎") { navigationModel.moveBackward() }
                            .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text("\(Int(navigationModel.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("▶︎") { navigationModel.moveForward() }
                            .buttonStyle(.bordered)
                    }
                    
                    Slider(value: Binding(
                        get: { navigationModel.progress },
                        set: { navigationModel.jumpToProgress($0) }
                    ), in: 0...1)
                    .tint(.blue)
                }
            } else {
                Button("Start Navigation") {
                    navigationModel.startNavigation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.currentModel == nil)
            }
        }
        .padding()
    }
}

struct EndoscopeOverlay: View {
    @EnvironmentObject private var navigationModel: BronchoscopyNavigationModel
    
    var body: some View {
        ZStack {
            // Endoscope view simulation
            Circle()
                .fill(.black)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .overlay(
                            // Crosshairs
                            Group {
                                Rectangle()
                                    .frame(width: 1, height: 100)
                                    .foregroundColor(.white.opacity(0.5))
                                Rectangle()
                                    .frame(width: 100, height: 1)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                )
                .padding(40)
            
            VStack {
                Spacer()
                HStack {
                    if let branch = navigationModel.currentBranch {
                        Text("Location: \(branch.name)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("FOV: \(Int(navigationModel.fieldOfView))°")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding()
            }
        }
        .background(.black)
    }
}

struct EducationalInfoPanel: View {
    let info: EducationalInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Educational Information")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(info.anatomicalRegion)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Generation: \(info.generation)")
                    .font(.caption)
                
                if info.diameter > 0 {
                    Text("Diameter: \(info.diameter, specifier: "%.1f")mm")
                        .font(.caption)
                }
                
                if let pathology = info.pathologyInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⚠️ Pathology Detected")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("\(pathology.type.rawValue) - \(pathology.severity.rawValue)")
                            .font(.caption)
                        
                        Text(pathology.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
    }
}

#Preview {
    AirwayImmersiveView()
        .environmentObject(AirwayAppModel())
        .environmentObject(BronchoscopyNavigationModel())
        .environmentObject(SpatialAnchorModel())
}