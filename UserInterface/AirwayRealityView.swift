//
//  AirwayRealityView.swift
//  AirwayVision
//
//  RealityKit view for 3D airway visualization
//

import SwiftUI
import RealityKit
import Accessibility
import CodableCSV
import ARKit

struct AirwayRealityView: View {
    @EnvironmentObject private var appModel: AirwayAppModel
    @EnvironmentObject private var navigationModel: BronchoscopyNavigationModel
    @EnvironmentObject private var anchorModel: SpatialAnchorModel
    
    @State private var realityViewContent: RealityViewContent?
    
    var body: some View {
        RealityView { content in
            // Setup RealityKit content
            await setupRealityContent(content)
            realityViewContent = content
            
            // Initialize anchor model with AR session if available
            if let arView = content as? ARView {
                await anchorModel.initializeWithSession(arView.session)
            }
            
        } update: { content in
            // Update content when models change
            await updateRealityContent(content)
        }
        .onAppear {
            // Set the app model's reality content reference
            appModel.realityContent = realityViewContent
        }
        .gesture(
            // Add gesture support for navigation
            navigationGestures
        )
        .compositingMode(.foveated)
    }
    
    // MARK: - Gestures
    
    private var navigationGestures: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Handle drag for virtual bronchoscopy navigation
                if navigationModel.navigationState == .navigating {
                    let translation = value.translation
                    navigationModel.handleDragGesture(translation: CGSize(
                        width: translation.x,
                        height: translation.y
                    ))
                }
            }
            .simultaneously(with:
                MagnificationGesture()
                    .onChanged { value in
                        // Handle pinch for FOV adjustment
                        navigationModel.handlePinchGesture(scale: value)
                    }
            )
    }
    
    // MARK: - Reality Content Setup
    
    @MainActor
    private func setupRealityContent(_ content: RealityViewContent) async {
        // Setup basic scene
        setupLighting(content)
        setupEnvironment(content)
        
        // Load initial model if available
        if let currentModel = appModel.currentModel {
            await loadAirwayModel(currentModel, into: content)
        }
    }
    
    @MainActor
    private func updateRealityContent(_ content: RealityViewContent) async {
        // Update when app state changes
        if let currentModel = appModel.currentModel {
            await loadAirwayModel(currentModel, into: content)
        }
        
        // Update navigation visualization
        updateNavigationVisualization(content)
        
        // Update anchoring
        updateAnchoringVisualization(content)
    }
    
    private func setupLighting(_ content: RealityViewContent) {
        // Create main directional light
        let mainLight = DirectionalLight()
        mainLight.light.intensity = 1500
        mainLight.light.isRealWorldProxy = true
        mainLight.shadow?.maximumDistance = 4.0
        mainLight.orientation = simd_quatf(angle: -.pi/4, axis: [1, 0, 0])
        
        let lightEntity = Entity()
        lightEntity.components.set(mainLight)
        lightEntity.position = [0, 2, 0]
        content.add(lightEntity)
        
        // Add ambient lighting for better visibility
        let ambientLight = Entity()
        ambientLight.components.set(ImageBasedLight(
            source: .single(try! .load(named: "studio_garden_4k", in: Bundle.main)),
            intensityExponent: 0.3
        ))
        content.add(ambientLight)
    }
    
    private func setupEnvironment(_ content: RealityViewContent) {
        // Add a subtle environment for better depth perception
        let environment = Entity()
        environment.components.set(ModelComponent(
            mesh: .generateSphere(radius: 10),
            materials: [UnlitMaterial(color: .black.withAlphaComponent(0.1))]
        ))
        environment.scale = SIMD3<Float>(-1, 1, 1) // Inside-out sphere
        content.add(environment)
    }
    
    @MainActor
    private func loadAirwayModel(_ model: AirwayModel, into content: RealityViewContent) async {
        // Remove existing airway entities
        removeExistingAirwayEntities(from: content)
        
        do {
            // Load main airway mesh
            let airwayEntity = try await loadAirwayMesh(for: model)
            
            // Apply visualization mode
            applyVisualizationMode(to: airwayEntity, mode: appModel.visualizationMode)
            
            // Load centerline data for navigation
            let centerlineData = try await loadCenterlineData(for: model)
            await navigationModel.loadAirwayModel(model)
            
            // Create centerline visualization
            let centerlineEntity = createCenterlineVisualization(from: centerlineData)
            
            // Create annotation entities
            let annotationEntities = try await loadAnnotations(for: model)
            
            // Add all entities to content
            content.add(airwayEntity)
            content.add(centerlineEntity)
            
            for annotation in annotationEntities {
                content.add(annotation)
            }
            
            // Update app model
            appModel.airwayEntities = [airwayEntity, centerlineEntity] + annotationEntities
            
        } catch {
            print("Error loading airway model: \(error)")
        }
    }
    
    private func removeExistingAirwayEntities(from content: RealityViewContent) {
        for entity in appModel.airwayEntities {
            content.remove(entity)
        }
        appModel.airwayEntities.removeAll()
    }
    
    private func loadAirwayMesh(for model: AirwayModel) async throws -> Entity {
        // Load USD model from bundle
        guard let meshURL = Bundle.main.url(forResource: model.id, withExtension: "usd", subdirectory: "PrebuiltModels/Meshes") else {
            throw AirwayVisionError.modelNotFound
        }
        
        let entity = try await Entity(contentsOf: meshURL)
        entity.name = "AirwayMesh_\(model.id)"
        
        // Scale for Vision Pro viewing
        entity.scale = SIMD3<Float>(0.5, 0.5, 0.5)
        
        // Add gesture components for interaction
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateConvex(from: entity.model!.mesh)]))
        entity.components.set(AccessibilityComponent(label: model.name, value: "Airway mesh"))
        
        return entity
    }
    
    private func loadCenterlineData(for model: AirwayModel) async throws -> [CenterlinePoint] {
        guard let centerlineURL = Bundle.main.url(forResource: model.id, withExtension: "csv", subdirectory: "PrebuiltModels/Centerlines") else {
            throw AirwayVisionError.centerlineNotFound
        }

        let data = try Data(contentsOf: centerlineURL)
        struct Row: Decodable {
            let StartPointPosition: String
            let EndPointPosition: String
            let Radius: Float
        }
        let decoder = CSVDecoder { $0.delimiters.field = "\t" }
        let rows = try decoder.decode([Row].self, from: data)
        var points: [CenterlinePoint] = []
        for row in rows {
            let start = row.StartPointPosition.split(separator: " ").compactMap { Float($0) }
            let end = row.EndPointPosition.split(separator: " ").compactMap { Float($0) }
            guard start.count == 3 && end.count == 3 else { continue }
            let s = SIMD3<Float>(start[0], start[1], start[2])
            let e = SIMD3<Float>(end[0], end[1], end[2])
            let dir = normalize(e - s)
            points.append(CenterlinePoint(position: e, direction: dir, radius: row.Radius, generation: 0, branchId: model.id, distanceFromStart: 0))
        }
        return points
    }
    
    private func createCenterlineVisualization(from points: [CenterlinePoint]) -> Entity {
        let centerlineEntity = Entity()
        centerlineEntity.name = "CenterlineVisualization"
        
        // Create line segments between points
        for i in 0..<(points.count - 1) {
            let startPoint = points[i]
            let endPoint = points[i + 1]
            
            let lineSegment = createLineSegment(from: startPoint.position, to: endPoint.position)
            centerlineEntity.addChild(lineSegment)
        }
        
        // Create markers at key points (bifurcations, etc.)
        for point in points where point.landmarks?.isEmpty == false {
            let marker = createLandmarkMarker(at: point)
            centerlineEntity.addChild(marker)
        }
        
        return centerlineEntity
    }
    
    private func createLineSegment(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Entity {
        let direction = end - start
        let length = length(direction)
        let center = (start + end) / 2
        
        let entity = Entity()
        entity.position = center
        
        // Create a thin cylinder for the line
        let mesh = MeshResource.generateCylinder(height: length, radius: 0.001)
        let material = UnlitMaterial(color: .blue.withAlphaComponent(0.6))
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        entity.components.set(AccessibilityComponent(label: "Centerline segment", value: ""))
        
        // Orient the cylinder along the direction
        let up = SIMD3<Float>(0, 1, 0)
        let normalizedDirection = normalize(direction)
        let rotation = simd_quatf(from: up, to: normalizedDirection)
        entity.orientation = rotation
        
        return entity
    }
    
    private func createLandmarkMarker(at point: CenterlinePoint) -> Entity {
        let entity = Entity()
        entity.position = point.position
        
        // Create a small sphere marker
        let mesh = MeshResource.generateSphere(radius: 0.003)
        let material = SimpleMaterial(color: .yellow, isMetallic: false)
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        entity.components.set(AccessibilityComponent(label: point.anatomicalLabel ?? "Landmark", value: "Generation \(point.generation)"))
        
        // Add text label if available
        if let label = point.anatomicalLabel {
            let textEntity = createTextLabel(label, at: point.position + SIMD3<Float>(0, 0.01, 0))
            entity.addChild(textEntity)
        }
        
        return entity
    }
    
    private func createTextLabel(_ text: String, at position: SIMD3<Float>) -> Entity {
        let entity = Entity()
        entity.position = position
        
        // Create 3D text mesh
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.01),
            containerFrame: CGRect.zero,
            alignment: .center,
            lineBreakMode: .byCharWrapping
        )
        
        let material = UnlitMaterial(color: .white)
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        return entity
    }
    
    private func loadAnnotations(for model: AirwayModel) async throws -> [Entity] {
        // Load annotation data and create entities
        guard let annotationURL = Bundle.main.url(forResource: model.id, withExtension: "json", subdirectory: "PrebuiltModels/Annotations") else {
            return [] // Annotations are optional
        }
        
        let data = try Data(contentsOf: annotationURL)
        let annotations = try JSONDecoder().decode([WaypointAnnotation].self, from: data)
        
        return annotations.map { annotation in
            createAnnotationEntity(from: annotation)
        }
    }
    
    private func createAnnotationEntity(from annotation: WaypointAnnotation) -> Entity {
        let entity = Entity()
        entity.position = annotation.position
        entity.name = "Annotation_\(annotation.id)"
        
        switch annotation.type {
        case .text:
            let textEntity = createTextLabel(annotation.content, at: .zero)
            entity.addChild(textEntity)
            
        case .arrow:
            let arrowEntity = createArrowEntity(content: annotation.content)
            entity.addChild(arrowEntity)
            
        case .highlight:
            let highlightEntity = createHighlightEntity()
            entity.addChild(highlightEntity)
            
        case .measurement:
            let measurementEntity = createMeasurementEntity(content: annotation.content)
            entity.addChild(measurementEntity)
            
        case .comparison:
            let comparisonEntity = createComparisonEntity(content: annotation.content)
            entity.addChild(comparisonEntity)
        }
        
        // Apply importance-based styling
        applyImportanceStyling(to: entity, importance: annotation.importance)
        
        return entity
    }
    
    private func createArrowEntity(content: String) -> Entity {
        let entity = Entity()
        
        // Create arrow mesh (simplified)
        let mesh = MeshResource.generateCone(height: 0.02, radius: 0.005)
        let material = SimpleMaterial(color: .red, isMetallic: false)
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        return entity
    }
    
    private func createHighlightEntity() -> Entity {
        let entity = Entity()
        
        // Create glowing sphere
        let mesh = MeshResource.generateSphere(radius: 0.008)
        let material = UnlitMaterial(color: .yellow.withAlphaComponent(0.7))
        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        return entity
    }
    
    private func createMeasurementEntity(content: String) -> Entity {
        let entity = Entity()
        
        // Create measurement visualization
        let textEntity = createTextLabel(content, at: .zero)
        entity.addChild(textEntity)
        
        return entity
    }
    
    private func createComparisonEntity(content: String) -> Entity {
        let entity = Entity()
        
        // Create comparison visualization
        let textEntity = createTextLabel(content, at: .zero)
        entity.addChild(textEntity)
        
        return entity
    }
    
    private func applyImportanceStyling(to entity: Entity, importance: ImportanceLevel) {
        // Apply visual styling based on importance
        switch importance {
        case .critical:
            entity.scale = SIMD3<Float>(1.5, 1.5, 1.5)
        case .high:
            entity.scale = SIMD3<Float>(1.2, 1.2, 1.2)
        case .medium:
            entity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
        case .low:
            entity.scale = SIMD3<Float>(0.8, 0.8, 0.8)
        }
    }
    
    private func applyVisualizationMode(to entity: Entity, mode: VisualizationMode) {
        guard let modelComponent = entity.components[ModelComponent.self] else { return }
        
        var materials: [Material] = []
        
        switch mode {
        case .anatomical:
            // Realistic tissue colors
            materials = [SimpleMaterial(color: .systemPink.withAlphaComponent(0.8), isMetallic: false)]
            
        case .educational:
            // High contrast colors for teaching
            materials = [UnlitMaterial(color: .systemBlue)]
            
        case .pathological:
            // Color-coded for pathology
            materials = [SimpleMaterial(color: .systemRed.withAlphaComponent(0.7), isMetallic: false)]
            
        case .transparent:
            // Semi-transparent for seeing internal structures
            materials = [SimpleMaterial(color: .white.withAlphaComponent(0.3), isMetallic: false)]
            
        case .crossSection:
            // Cross-sectional view
            materials = [UnlitMaterial(color: .systemTeal)]
        }
        
        entity.components.set(ModelComponent(mesh: modelComponent.mesh, materials: materials))
    }
    
    private func updateNavigationVisualization(_ content: RealityViewContent) {
        // Update virtual camera position for bronchoscopy
        if navigationModel.navigationState == .navigating {
            updateVirtualCamera(content)
        }
        
        // Highlight current position on centerline
        highlightCurrentPosition(content)
    }
    
    private func updateVirtualCamera(_ content: RealityViewContent) {
        // Create or update virtual camera entity for endoscopic view
        let cameraTransform = navigationModel.getCameraTransform()
        
        // Find or create camera entity
        let cameraEntity = findOrCreateCameraEntity(in: content)
        cameraEntity.transform = cameraTransform
        
        // Update camera parameters
        let (fov, nearPlane, farPlane) = navigationModel.getCameraParameters()
        updateCameraComponent(cameraEntity, fov: fov, near: nearPlane, far: farPlane)
    }
    
    private func findOrCreateCameraEntity(in content: RealityViewContent) -> Entity {
        // Find existing camera entity or create new one
        if let existing = content.entities.first(where: { $0.name == "VirtualCamera" }) {
            return existing
        }
        
        let cameraEntity = Entity()
        cameraEntity.name = "VirtualCamera"
        
        // Add visual indicator for camera position
        let mesh = MeshResource.generateSphere(radius: 0.005)
        let material = UnlitMaterial(color: .green)
        cameraEntity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        content.add(cameraEntity)
        return cameraEntity
    }
    
    private func updateCameraComponent(_ entity: Entity, fov: Float, near: Float, far: Float) {
        // Update camera component if needed
        // This would be used for actual camera rendering in a more complex implementation
    }
    
    private func highlightCurrentPosition(_ content: RealityViewContent) {
        // Remove previous position indicator
        if let existing = content.entities.first(where: { $0.name == "CurrentPositionIndicator" }) {
            content.remove(existing)
        }
        
        // Create new position indicator
        let indicator = Entity()
        indicator.name = "CurrentPositionIndicator"
        indicator.position = navigationModel.currentPosition
        
        let mesh = MeshResource.generateSphere(radius: 0.008)
        let material = UnlitMaterial(color: .cyan)
        indicator.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        content.add(indicator)
    }
    
    private func updateAnchoringVisualization(_ content: RealityViewContent) {
        // Show anchor visualization if active
        if let anchor = anchorModel.activeAnchor {
            showAnchorVisualization(anchor, in: content)
        } else {
            hideAnchorVisualization(in: content)
        }
    }
    
    private func showAnchorVisualization(_ anchor: SpatialAnchor, in content: RealityViewContent) {
        // Remove existing anchor visualization
        if let existing = content.entities.first(where: { $0.name == "AnchorVisualization" }) {
            content.remove(existing)
        }
        
        // Create anchor visualization
        let anchorEntity = Entity()
        anchorEntity.name = "AnchorVisualization"
        anchorEntity.position = anchor.transform.translation
        
        // Create visual indicator for anchor
        let mesh = MeshResource.generateBox(size: [0.02, 0.02, 0.02])
        let material = UnlitMaterial(color: .orange.withAlphaComponent(0.7))
        anchorEntity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        anchorEntity.components.set(AccessibilityComponent(label: "Spatial anchor", value: ""))
        
        content.add(anchorEntity)
    }
    
    private func hideAnchorVisualization(in content: RealityViewContent) {
        if let existing = content.entities.first(where: { $0.name == "AnchorVisualization" }) {
            content.remove(existing)
        }
    }
}

// MARK: - Extensions

extension BronchoscopyNavigationModel {
    func handleDragGesture(translation: CGSize) {
        guard isNavigating else { return }
        
        // Convert drag to navigation
        let forwardDelta = Float(-translation.height) * 0.001
        let newProgress = progress + forwardDelta
        
        jumpToProgress(max(0, min(1, newProgress)))
    }
    
    func handlePinchGesture(scale: CGFloat) {
        let newFOV = fieldOfView * Float(scale)
        updateFieldOfView(max(30, min(120, newFOV)))
    }
}

#Preview {
    AirwayRealityView()
        .environmentObject(AirwayAppModel())
        .environmentObject(BronchoscopyNavigationModel())
        .environmentObject(SpatialAnchorModel())
}