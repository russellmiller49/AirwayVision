//
//  AirwayVisionApp.swift
//  AirwayVision
//
//  Specialized airway visualization and virtual bronchoscopy app for Vision Pro
//

import SwiftUI
import RealityKit
import SwiftCSV

@main
struct AirwayVisionApp: App {
    
    @StateObject private var appModel = AirwayAppModel()
    @StateObject private var navigationModel = BronchoscopyNavigationModel()
    @StateObject private var anchorModel = SpatialAnchorModel()
    private let analytics = AnalyticsManager.shared
    
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
        // Load CSV centerline data
        guard let centerlineURL = Bundle.main.url(forResource: model.id, withExtension: "csv", subdirectory: "PrebuiltModels/Centerlines") else {
            throw AirwayVisionError.centerlineNotFound
        }

        let csv = try CSV(url: centerlineURL)
        var points: [CenterlinePoint] = []
        var previous: SIMD3<Float>? = nil

        for row in csv.namedRows {
            guard let posString = row["EndPointPosition"],
                  let radiusString = row["Radius"],
                  let cellId = row["CellId"],
                  let posValues = Float.split(from: posString) else { continue }

            let position = SIMD3<Float>(posValues[0], posValues[1], posValues[2])
            let direction: SIMD3<Float>
            if let prev = previous {
                direction = normalize(position - prev)
            } else {
                direction = SIMD3<Float>(0, 0, -1)
            }
            previous = position

            let point = CenterlinePoint(
                position: position,
                direction: direction,
                radius: Float(radiusString) ?? 0,
                generation: Int(cellId) ?? 0,
                branchId: cellId,
                distanceFromStart: 0,
                anatomicalLabel: nil,
                pathologyInfo: nil,
                landmarks: nil
            )
            points.append(point)
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