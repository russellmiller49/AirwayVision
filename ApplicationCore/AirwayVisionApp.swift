//
//  AirwayVisionApp.swift
//  AirwayVision
//
//  Specialized airway visualization and virtual bronchoscopy app for Vision Pro
//

import SwiftUI
import RealityKit
import CodableCSV

@main
struct AirwayVisionApp: App {
    
    @StateObject private var appModel = AirwayAppModel()
    @StateObject private var navigationModel = BronchoscopyNavigationModel()
    @StateObject private var anchorModel = SpatialAnchorModel()
    
    var body: some Scene {
        WindowGroup {
            AirwayMainView()
                .environmentObject(appModel)
                .environmentObject(navigationModel)
                .environmentObject(anchorModel)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.8, height: 0.6, depth: 0.8, in: .meters)

        ImmersiveSpace(id: "AirwayImmersiveSpace") {
            AirwayImmersiveView()
                .environmentObject(appModel)
                .environmentObject(navigationModel)
                .environmentObject(anchorModel)
        }
        .immersionStyle(selection: .constant(.progressive), in: .progressive)
    }
}

/// Main application model managing airway visualization state
@MainActor
class AirwayAppModel: ObservableObject {
    
    /// Available airway models
    @Published var availableModels: [AirwayModel] = []
    
    /// Currently loaded airway model
    @Published var currentModel: AirwayModel?
    
    /// Available visualization modes
    @Published var visualizationMode: VisualizationMode = .anatomical
    
    /// Reality content reference
    var realityContent: RealityViewContent?
    
    /// Current airway entities in the scene
    private(set) var airwayEntities: [Entity] = []
    
    /// Initialize with prebuilt models
    init() {
        loadPrebuiltModels()
    }
    
    /// Load all prebuilt airway models
    private func loadPrebuiltModels() {
        availableModels = [
            AirwayModel(
                id: "normal_adult",
                name: "Normal Adult Airway",
                description: "Healthy adult respiratory system with complete branching",
                complexity: .detailed,
                anatomicalVariant: .normal
            ),
            AirwayModel(
                id: "simplified_adult",
                name: "Simplified Adult Airway",
                description: "Educational model showing main bronchial structures",
                complexity: .simplified,
                anatomicalVariant: .normal
            ),
            AirwayModel(
                id: "pathological_copd",
                name: "COPD Airway Model",
                description: "Airways showing chronic obstructive changes",
                complexity: .detailed,
                anatomicalVariant: .pathological
            )
        ]
    }
    
    /// Load specific airway model
    func loadModel(_ model: AirwayModel) async throws {
        currentModel = model
        
        // Load airway mesh
        let meshEntity = try await loadAirwayMesh(for: model)
        
        // Load centerline data
        let centerlineData = try await loadCenterlineData(for: model)
        
        // Load annotations
        let annotationEntities = try await loadAnnotations(for: model)
        
        // Add to scene
        await MainActor.run {
            // Clear existing entities
            clearCurrentEntities()
            
            // Add new entities
            airwayEntities.append(meshEntity)
            airwayEntities.append(contentsOf: annotationEntities)
            
            // Apply visualization mode
            applyVisualizationMode()
        }
    }
    
    /// Clear current entities from scene
    private func clearCurrentEntities() {
        for entity in airwayEntities {
            realityContent?.remove(entity)
        }
        airwayEntities.removeAll()
    }
    
    /// Apply current visualization mode to entities
    private func applyVisualizationMode() {
        // Implementation will be added based on selected mode
    }
    
    /// Load airway mesh for model
    private func loadAirwayMesh(for model: AirwayModel) async throws -> Entity {
        // Implementation will load USD file from PrebuiltModels/Meshes
        let meshPath = Bundle.main.url(forResource: model.id, withExtension: "usd", subdirectory: "PrebuiltModels/Meshes")
        guard let meshPath else {
            throw AirwayVisionError.modelNotFound
        }
        
        return try await Entity(contentsOf: meshPath)
    }
    
    /// Load centerline data for navigation
    private func loadCenterlineData(for model: AirwayModel) async throws -> [CenterlinePoint] {
        // Load centerline CSV data
        let centerlinePath = Bundle.main.url(forResource: model.id, withExtension: "csv", subdirectory: "PrebuiltModels/Centerlines")
        guard let centerlinePath else {
            throw AirwayVisionError.centerlineNotFound
        }

        let data = try Data(contentsOf: centerlinePath)
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
    
    /// Load annotation entities for educational features
    private func loadAnnotations(for model: AirwayModel) async throws -> [Entity] {
        // Implementation will load annotation data and create entities
        return []
    }
}

/// Visualization modes for airway display
enum VisualizationMode: String, CaseIterable {
    case anatomical = "Anatomical"
    case educational = "Educational"
    case pathological = "Pathological"
    case transparent = "Transparent"
    case crossSection = "Cross Section"
}

/// Errors specific to AirwayVision
enum AirwayVisionError: Error {
    case modelNotFound
    case centerlineNotFound
    case invalidModelData
    case navigationError
    case anchoringFailed
}