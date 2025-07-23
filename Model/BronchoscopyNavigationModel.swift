//
//  BronchoscopyNavigationModel.swift
//  AirwayVision
//
//  Enhanced virtual bronchoscopy navigation system with pre-built centerlines
//

import Foundation
import RealityKit
import simd
import Combine
import SwiftCSV

/// Enhanced bronchoscopy navigation model with pre-built data
@MainActor
class BronchoscopyNavigationModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current navigation state
    @Published var navigationState: NavigationState = .idle
    
    /// Current position along centerline (0.0 to 1.0)
    @Published var progress: Float = 0.0
    
    /// Current camera position in 3D space
    @Published var currentPosition: SIMD3<Float> = .zero
    
    /// Current look direction
    @Published var lookDirection: SIMD3<Float> = SIMD3<Float>(0, 0, -1)
    
    /// Current branch being navigated
    @Published var currentBranch: AirwayBranch?
    
    /// Available branches from current position
    @Published var availableBranches: [AirwayBranch] = []
    
    /// Current navigation mode
    @Published var navigationMode: NavigationMode = .automatic
    
    /// Camera field of view (degrees)
    @Published var fieldOfView: Float = 75.0
    
    /// Navigation speed multiplier
    @Published var speed: Float = 1.0
    
    /// Educational information at current position
    @Published var currentEducationalInfo: EducationalInfo?
    
    /// Whether waypoint guidance is enabled
    @Published var waypointGuidanceEnabled: Bool = true
    
    /// Current tour being followed
    @Published var activeTour: EducationalTour?
    
    // MARK: - Private Properties
    
    /// Complete airway tree structure
    private var airwayTree: AirwayTree?
    
    /// Current centerline points
    private var centerlinePoints: [CenterlinePoint] = []
    
    /// Current index in centerline
    private var currentIndex: Int = 0
    
    /// Navigation path history
    private var navigationHistory: [NavigationHistoryEntry] = []
    
    /// Waypoints along current path
    private var currentWaypoints: [NavigationWaypoint] = []
    
    /// Timer for automatic navigation
    private var navigationTimer: Timer?
    
    /// Camera entity for RealityKit
    private var cameraEntity: Entity?
    
    // MARK: - Initialization
    
    init() {
        setupDefaultConfiguration()
    }
    
    // MARK: - Public Methods
    
    /// Load airway model and initialize navigation
    func loadAirwayModel(_ model: AirwayModel) async throws {
        // Load centerline data
        let centerlineData = try await loadCenterlineData(for: model)
        
        // Build airway tree structure
        let tree = try buildAirwayTree(from: centerlineData)
        
        await MainActor.run {
            self.airwayTree = tree
            self.resetToTrachea()
        }
    }
    
    /// Start navigation from trachea
    func startNavigation() {
        guard let tree = airwayTree else { return }
        
        navigationState = .navigating
        currentBranch = tree.trachea
        centerlinePoints = tree.trachea.centerlinePoints
        currentIndex = 0
        progress = 0.0
        
        updatePosition()
        startNavigationTimer()
    }
    
    /// Stop navigation
    func stopNavigation() {
        navigationState = .idle
        stopNavigationTimer()
    }
    
    /// Navigate forward along current path
    func moveForward() {
        guard navigationState == .navigating,
              currentIndex < centerlinePoints.count - 1 else { return }
        
        let stepSize = max(1, Int(speed))
        currentIndex = min(currentIndex + stepSize, centerlinePoints.count - 1)
        
        updatePosition()
        checkForBranches()
        updateEducationalInfo()
    }
    
    /// Navigate backward along current path
    func moveBackward() {
        guard navigationState == .navigating,
              currentIndex > 0 else { return }
        
        let stepSize = max(1, Int(speed))
        currentIndex = max(currentIndex - stepSize, 0)
        
        updatePosition()
        checkForBranches()
        updateEducationalInfo()
    }
    
    /// Jump to specific progress along current branch
    func jumpToProgress(_ newProgress: Float) {
        let clampedProgress = max(0.0, min(1.0, newProgress))
        let targetIndex = Int(clampedProgress * Float(centerlinePoints.count - 1))
        
        currentIndex = targetIndex
        progress = clampedProgress
        
        updatePosition()
        checkForBranches()
        updateEducationalInfo()
    }
    
    /// Navigate to specific branch
    func navigateToBranch(_ branch: AirwayBranch) {
        // Record current position in history
        recordNavigationHistory()
        
        currentBranch = branch
        centerlinePoints = branch.centerlinePoints
        currentIndex = 0
        progress = 0.0
        
        updatePosition()
        loadWaypointsForBranch(branch)
    }
    
    /// Go back to previous navigation point
    func goBack() {
        guard let lastEntry = navigationHistory.last else { return }
        
        navigationHistory.removeLast()
        
        if let branch = airwayTree?.findBranch(id: lastEntry.branchId) {
            currentBranch = branch
            centerlinePoints = branch.centerlinePoints
            currentIndex = lastEntry.centerlineIndex
            progress = lastEntry.progress
            
            updatePosition()
        }
    }
    
    /// Reset navigation to trachea
    func resetToTrachea() {
        guard let tree = airwayTree else { return }
        
        navigationHistory.removeAll()
        currentBranch = tree.trachea
        centerlinePoints = tree.trachea.centerlinePoints
        currentIndex = 0
        progress = 0.0
        navigationState = .idle
        
        updatePosition()
        stopNavigationTimer()
    }
    
    /// Start guided educational tour
    func startTour(_ tour: EducationalTour) async {
        activeTour = tour
        navigationState = .guidedTour
        
        // Navigate to first waypoint
        if let firstWaypoint = tour.waypoints.first {
            await navigateToWaypoint(firstWaypoint)
        }
    }
    
    /// Navigate to specific waypoint
    func navigateToWaypoint(_ waypoint: NavigationWaypoint) async {
        // Find path to waypoint
        if let path = findPathToPosition(waypoint.position) {
            await animateAlongPath(path, destination: waypoint)
        }
    }
    
    /// Update field of view
    func updateFieldOfView(_ newFOV: Float) {
        fieldOfView = max(30.0, min(120.0, newFOV))
        updateCameraParameters()
    }
    
    /// Update navigation speed
    func updateSpeed(_ newSpeed: Float) {
        speed = max(0.1, min(5.0, newSpeed))
    }
    
    /// Toggle automatic vs manual navigation
    func setNavigationMode(_ mode: NavigationMode) {
        navigationMode = mode
        
        if mode == .automatic && navigationState == .navigating {
            startNavigationTimer()
        } else {
            stopNavigationTimer()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultConfiguration() {
        fieldOfView = 75.0
        speed = 1.0
        navigationMode = .automatic
    }
    
    private func loadCenterlineData(for model: AirwayModel) async throws -> [AirwayBranch] {
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

        // Wrap points into a single branch for navigation
        let info = BranchAnatomicalInfo(
            standardName: "Trachea",
            alternativeNames: [],
            clinicalRelevance: "",
            commonFindings: [],
            normalDimensions: nil
        )
        let branch = AirwayBranch(
            id: "trachea",
            name: "Trachea",
            parentId: nil,
            childIds: [],
            generation: 0,
            centerlinePoints: points,
            anatomicalInfo: info
        )
        return [branch]
    }
    
    private func buildAirwayTree(from branches: [AirwayBranch]) throws -> AirwayTree {
        // Find trachea (generation 0)
        guard let trachea = branches.first(where: { $0.generation == 0 }) else {
            throw AirwayVisionError.invalidModelData
        }
        
        // Build hierarchical tree structure
        let tree = AirwayTree(trachea: trachea)
        
        for branch in branches {
            tree.addBranch(branch)
        }
        
        return tree
    }
    
    private func updatePosition() {
        guard currentIndex < centerlinePoints.count else { return }
        
        let currentPoint = centerlinePoints[currentIndex]
        currentPosition = currentPoint.position
        lookDirection = currentPoint.direction
        
        // Update progress
        progress = Float(currentIndex) / Float(max(1, centerlinePoints.count - 1))
        
        // Update camera if available
        updateCameraTransform()
    }
    
    private func checkForBranches() {
        guard let tree = airwayTree,
              let currentBranch = currentBranch else { return }
        
        // Check if we're near the end of current branch
        let nearEndThreshold = 0.9
        if progress > nearEndThreshold {
            availableBranches = tree.getChildBranches(of: currentBranch.id)
        } else {
            availableBranches = []
        }
    }
    
    private func updateEducationalInfo() {
        guard currentIndex < centerlinePoints.count else { return }
        
        let currentPoint = centerlinePoints[currentIndex]
        
        // Create educational information for current position
        currentEducationalInfo = EducationalInfo(
            position: currentPoint.position,
            anatomicalRegion: currentPoint.anatomicalLabel ?? "Airways",
            generation: currentPoint.generation,
            diameter: currentPoint.radius * 2,
            pathologyInfo: currentPoint.pathologyInfo,
            landmarks: currentPoint.landmarks ?? []
        )
    }
    
    private func recordNavigationHistory() {
        guard let currentBranch = currentBranch else { return }
        
        let entry = NavigationHistoryEntry(
            branchId: currentBranch.id,
            centerlineIndex: currentIndex,
            progress: progress,
            timestamp: Date()
        )
        
        navigationHistory.append(entry)
        
        // Limit history size
        if navigationHistory.count > 20 {
            navigationHistory.removeFirst()
        }
    }
    
    private func loadWaypointsForBranch(_ branch: AirwayBranch) {
        // Load waypoints for educational guidance
        // This would load from PrebuiltModels/Annotations
        currentWaypoints = []
    }
    
    private func startNavigationTimer() {
        stopNavigationTimer()
        
        guard navigationMode == .automatic else { return }
        
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.moveForward()
        }
    }
    
    private func stopNavigationTimer() {
        navigationTimer?.invalidate()
        navigationTimer = nil
    }
    
    private func updateCameraTransform() {
        // Update RealityKit camera entity if available
        guard let cameraEntity = cameraEntity else { return }
        
        var transform = Transform()
        transform.translation = currentPosition
        
        // Calculate rotation from look direction
        let forward = normalize(lookDirection)
        let right = normalize(cross(SIMD3<Float>(0, 1, 0), forward))
        let up = cross(forward, right)
        
        let rotationMatrix = simd_float3x3(columns: (right, up, -forward))
        transform.rotation = simd_quatf(rotationMatrix)
        
        cameraEntity.transform = transform
    }
    
    private func updateCameraParameters() {
        // Update camera field of view and other parameters
    }
    
    private func findPathToPosition(_ targetPosition: SIMD3<Float>) -> [SIMD3<Float>]? {
        // Implement pathfinding to target position
        // This would use the airway tree to find optimal route
        return nil
    }
    
    private func animateAlongPath(_ path: [SIMD3<Float>], destination: NavigationWaypoint) async {
        // Implement smooth animation along path to waypoint
        navigationState = .animating
        
        // Animate through path points
        for position in path {
            currentPosition = position
            // Add smooth interpolation and timing
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        navigationState = .atWaypoint
        
        // Show waypoint information
        await showWaypointInfo(destination)
    }
    
    private func showWaypointInfo(_ waypoint: NavigationWaypoint) async {
        // Display educational information for this waypoint
        currentEducationalInfo = EducationalInfo(
            position: waypoint.position,
            anatomicalRegion: waypoint.title,
            generation: 0,
            diameter: 0,
            pathologyInfo: nil,
            landmarks: [],
            waypointInfo: waypoint
        )
    }
}

// MARK: - Supporting Types

enum NavigationState {
    case idle
    case navigating
    case guidedTour
    case animating
    case atWaypoint
    case paused
}

enum NavigationMode {
    case automatic
    case manual
    case guided
}

struct NavigationHistoryEntry {
    let branchId: String
    let centerlineIndex: Int
    let progress: Float
    let timestamp: Date
}

struct EducationalInfo {
    let position: SIMD3<Float>
    let anatomicalRegion: String
    let generation: Int
    let diameter: Float
    let pathologyInfo: PathologyInfo?
    let landmarks: [Landmark]
    let waypointInfo: NavigationWaypoint?
    
    init(position: SIMD3<Float>, anatomicalRegion: String, generation: Int, diameter: Float, pathologyInfo: PathologyInfo?, landmarks: [Landmark], waypointInfo: NavigationWaypoint? = nil) {
        self.position = position
        self.anatomicalRegion = anatomicalRegion
        self.generation = generation
        self.diameter = diameter
        self.pathologyInfo = pathologyInfo
        self.landmarks = landmarks
        self.waypointInfo = waypointInfo
    }
}

/// Hierarchical airway tree structure
class AirwayTree {
    let trachea: AirwayBranch
    private var branches: [String: AirwayBranch] = [:]
    private var children: [String: [String]] = [:]
    
    init(trachea: AirwayBranch) {
        self.trachea = trachea
        addBranch(trachea)
    }
    
    func addBranch(_ branch: AirwayBranch) {
        branches[branch.id] = branch
        
        if let parentId = branch.parentId {
            if children[parentId] == nil {
                children[parentId] = []
            }
            children[parentId]?.append(branch.id)
        }
    }
    
    func findBranch(id: String) -> AirwayBranch? {
        return branches[id]
    }
    
    func getChildBranches(of branchId: String) -> [AirwayBranch] {
        guard let childIds = children[branchId] else { return [] }
        return childIds.compactMap { branches[$0] }
    }
    
    func getParentBranch(of branchId: String) -> AirwayBranch? {
        guard let branch = branches[branchId],
              let parentId = branch.parentId else { return nil }
        return branches[parentId]
    }
}