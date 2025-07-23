//
//  AirwayModel.swift
//  AirwayVision
//
//  Data models for airway structures and navigation
//

import Foundation
import simd
import RealityKit

/// Represents a complete airway model with mesh, centerline, and metadata
struct AirwayModel: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let complexity: ModelComplexity
    let anatomicalVariant: AnatomicalVariant
    
    /// Optional metadata
    var metadata: ModelMetadata?
    
    /// File paths for associated data
    var meshPath: String { "PrebuiltModels/Meshes/\(id).usd" }
    var centerlinePath: String { "PrebuiltModels/Centerlines/\(id).csv" }
    var annotationPath: String { "PrebuiltModels/Annotations/\(id).json" }
    var texturePath: String? { "PrebuiltModels/Textures/\(id)_texture.jpg" }
}

/// Model complexity levels
enum ModelComplexity: String, Codable, CaseIterable {
    case simplified = "Simplified"
    case standard = "Standard" 
    case detailed = "Detailed"
    case research = "Research"
    
    /// Target triangle count for each complexity
    var targetTriangles: Int {
        switch self {
        case .simplified: return 5000
        case .standard: return 15000
        case .detailed: return 30000
        case .research: return 100000
        }
    }
}

/// Anatomical variants
enum AnatomicalVariant: String, Codable, CaseIterable {
    case normal = "Normal"
    case pathological = "Pathological"
    case pediatric = "Pediatric"
    case geriatric = "Geriatric"
    case surgical = "Post-Surgical"
}

/// Additional model metadata
struct ModelMetadata: Codable {
    let creationDate: Date
    let source: String
    let resolution: Float // mm per voxel
    let anatomicalRegions: [AnatomicalRegion]
    let clinicalNotes: String?
    let references: [String]?
}

/// Anatomical regions within the model
struct AnatomicalRegion: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let generation: Int // Airway generation (0 = trachea, 1 = main bronchi, etc.)
    let boundingBox: BoundingBox
    let clinicalSignificance: String?
}

/// 3D bounding box
struct BoundingBox: Codable {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    
    var center: SIMD3<Float> {
        (min + max) / 2
    }
    
    var size: SIMD3<Float> {
        max - min
    }
}

/// Centerline point for navigation
struct CenterlinePoint: Codable, Identifiable {
    let id = UUID()
    let position: SIMD3<Float>
    let direction: SIMD3<Float>
    let radius: Float
    let generation: Int
    let branchId: String
    let distanceFromStart: Float
    
    /// Optional metadata for educational features
    var anatomicalLabel: String?
    var pathologyInfo: PathologyInfo?
    var landmarks: [Landmark]?
}

/// Pathology information for educational purposes
struct PathologyInfo: Codable {
    let type: PathologyType
    let severity: Severity
    let description: String
    let visualChanges: [String]
}

enum PathologyType: String, Codable, CaseIterable {
    case stenosis = "Stenosis"
    case inflammation = "Inflammation"
    case obstruction = "Obstruction"
    case dilation = "Dilation"
    case wall_thickening = "Wall Thickening"
}

enum Severity: String, Codable, CaseIterable {
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
}

/// Anatomical landmarks for navigation reference
struct Landmark: Codable, Identifiable {
    let id = UUID()
    let name: String
    let position: SIMD3<Float>
    let type: LandmarkType
    let description: String
    let clinicalSignificance: String?
}

enum LandmarkType: String, Codable, CaseIterable {
    case bifurcation = "Bifurcation"
    case narrowing = "Narrowing"
    case entrance = "Entrance"
    case terminal = "Terminal"
    case lesion = "Lesion"
}

/// Branch information for airway tree navigation
struct AirwayBranch: Codable, Identifiable {
    let id: String
    let name: String
    let parentId: String?
    let childIds: [String]
    let generation: Int
    let centerlinePoints: [CenterlinePoint]
    let anatomicalInfo: BranchAnatomicalInfo
}

/// Anatomical information for each branch
struct BranchAnatomicalInfo: Codable {
    let standardName: String // e.g., "Right Main Bronchus"
    let alternativeNames: [String]
    let clinicalRelevance: String
    let commonFindings: [String]
    let normalDimensions: DimensionRange?
}

/// Dimension ranges for normal anatomy
struct DimensionRange: Codable {
    let diameterMin: Float // mm
    let diameterMax: Float // mm
    let lengthMin: Float // mm
    let lengthMax: Float // mm
}

/// Navigation waypoint for guided tours
struct NavigationWaypoint: Codable, Identifiable {
    let id = UUID()
    let position: SIMD3<Float>
    let lookDirection: SIMD3<Float>
    let title: String
    let description: String
    let duration: TimeInterval // Suggested viewing time
    let annotations: [WaypointAnnotation]
    let nextWaypoints: [String] // IDs of possible next waypoints
}

/// Annotations at specific waypoints
struct WaypointAnnotation: Codable, Identifiable {
    let id = UUID()
    let type: AnnotationType
    let position: SIMD3<Float>
    let content: String
    let importance: ImportanceLevel
}

enum AnnotationType: String, Codable, CaseIterable {
    case text = "Text"
    case arrow = "Arrow"
    case highlight = "Highlight"
    case measurement = "Measurement"
    case comparison = "Comparison"
}

enum ImportanceLevel: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

/// Educational tour definition
struct EducationalTour: Codable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let difficulty: DifficultyLevel
    let estimatedDuration: TimeInterval
    let learningObjectives: [String]
    let waypoints: [NavigationWaypoint]
    let prerequisites: [String]?
    let assessmentQuestions: [AssessmentQuestion]?
}

enum DifficultyLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
}

/// Assessment questions for educational features
struct AssessmentQuestion: Codable, Identifiable {
    let id = UUID()
    let question: String
    let options: [String]
    let correctAnswerIndex: Int
    let explanation: String
    let relatedWaypointId: String?
}

/// Model loading configuration
struct ModelLoadingConfig {
    let complexity: ModelComplexity
    let includeAnnotations: Bool
    let includePaths: Bool
    let optimizeForVisionPro: Bool
    let enablePhysics: Bool
    let materialPreset: MaterialPreset
}

enum MaterialPreset: String, CaseIterable {
    case realistic = "Realistic"
    case educational = "Educational"
    case highlight = "Highlight"
    case xray = "X-Ray"
    case transparent = "Transparent"
}