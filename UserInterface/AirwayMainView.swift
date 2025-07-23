//
//  AirwayMainView.swift
//  AirwayVision
//
//  Main interface for airway visualization and virtual bronchoscopy
//

import SwiftUI
import RealityKit

struct AirwayMainView: View {
    @EnvironmentObject private var appModel: AirwayAppModel
    @EnvironmentObject private var navigationModel: BronchoscopyNavigationModel
    @EnvironmentObject private var anchorModel: SpatialAnchorModel
    
    @State private var selectedModel: AirwayModel?
    @State private var showingModelSelector = false
    @State private var showingNavigationControls = false
    @State private var showingAnchorSettings = false
    @State private var showingEducationalTours = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with model selection and controls
            VStack(alignment: .leading, spacing: 20) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("AirwayVision"))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(LocalizedStringKey("Virtual Bronchoscopy & Airway Exploration"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Model Selection
                modelSelectionSection
                
                Divider()
                
                // Navigation Controls
                navigationControlsSection
                
                Divider()
                
                // Anchoring Controls
                anchoringControlsSection
                
                Divider()
                
                // Educational Features
                educationalSection
                
                Spacer()
                
                // Status Information
                statusSection
            }
            .padding()
            .frame(minWidth: 300)
            
        } detail: {
            // Main 3D view
            AirwayRealityView()
                .ignoresSafeArea()
        }
        .navigationTitle("AirwayVision")
        .sheet(isPresented: $showingModelSelector) {
            ModelSelectorView(selectedModel: $selectedModel)
        }
        .sheet(isPresented: $showingNavigationControls) {
            NavigationControlsView()
        }
        .sheet(isPresented: $showingAnchorSettings) {
            AnchorSettingsView()
        }
        .sheet(isPresented: $showingEducationalTours) {
            EducationalToursView()
        }
    }
    
    // MARK: - View Sections
    
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Airway Models", systemImage: "lungs.fill")
                .font(.headline)
            
            if let currentModel = appModel.currentModel {
                // Current model info
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentModel.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(currentModel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack {
                        Label(currentModel.complexity.rawValue, systemImage: "slider.horizontal.3")
                            .font(.caption)
                        
                        Spacer()
                        
                        Label(currentModel.anatomicalVariant.rawValue, systemImage: "person.fill")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text(LocalizedStringKey("No model selected"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            Button(LocalizedStringKey("Select Model")) {
                showingModelSelector = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.availableModels.isEmpty)
        }
    }
    
    private var navigationControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Virtual Bronchoscopy", systemImage: "camera.circle.fill")
                .font(.headline)
            
            if navigationModel.navigationState == .idle {
                VStack(spacing: 8) {
                    Button(LocalizedStringKey("Start Navigation")) {
                        Task {
                            navigationModel.startNavigation()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.currentModel == nil)
                    
                    Button("Navigation Settings") {
                        showingNavigationControls = true
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Active navigation controls
                activeNavigationControls
            }
        }
    }
    
    private var activeNavigationControls: some View {
        VStack(spacing: 12) {
            // Progress indicator
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(navigationModel.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: navigationModel.progress)
                    .tint(.blue)
            }
            
            // Current branch info
            if let branch = navigationModel.currentBranch {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(branch.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Generation \(branch.generation)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Navigation buttons
            HStack {
                Button("◀︎") {
                    navigationModel.moveBackward()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(navigationModel.navigationState == .navigating ? "Pause" : "Resume") {
                    if navigationModel.navigationState == .navigating {
                        navigationModel.stopNavigation()
                    } else {
                        navigationModel.startNavigation()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("▶︎") {
                    navigationModel.moveForward()
                }
                .buttonStyle(.bordered)
            }
            
            // Speed control
            VStack(alignment: .leading, spacing: 4) {
                Text("Speed: \(navigationModel.speed, specifier: "%.1f")x")
                    .font(.caption)
                
                Slider(value: Binding(
                    get: { navigationModel.speed },
                    set: { navigationModel.updateSpeed($0) }
                ), in: 0.1...3.0, step: 0.1)
            }
            
            Button(LocalizedStringKey("Stop Navigation")) {
                navigationModel.resetToTrachea()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var anchoringControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Spatial Anchoring", systemImage: "location.circle.fill")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let anchor = anchorModel.activeAnchor {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anchored: \(anchor.name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(anchor.preset.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button("Remove Anchor") {
                        Task {
                            await anchorModel.removeAnchor()
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                } else {
                    Button("Auto-Anchor") {
                        Task {
                            if let entity = appModel.currentModel {
                                // This would get the actual entity from the reality view
                                // try await anchorModel.anchorAirwayModel(entity)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.currentModel == nil)
                }
                
                Button("Anchor Settings") {
                    showingAnchorSettings = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var educationalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Educational Features", systemImage: "graduationcap.fill")
                .font(.headline)
            
            VStack(spacing: 8) {
                Button("Guided Tours") {
                    showingEducationalTours = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Anatomical Labels") {
                    // Toggle anatomical labels
                }
                .buttonStyle(.bordered)
                
                Button("Pathology Highlights") {
                    // Toggle pathology visualization
                }
                .buttonStyle(.bordered)
            }
            
            // Current educational info
            if let eduInfo = navigationModel.currentEducationalInfo {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Information")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(eduInfo.anatomicalRegion)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if eduInfo.diameter > 0 {
                        Text("Diameter: \(eduInfo.diameter, specifier: "%.1f")mm")
                            .font(.caption)
                    }
                    
                    if let pathology = eduInfo.pathologyInfo {
                        Text("⚠️ \(pathology.type.rawValue): \(pathology.severity.rawValue)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                statusRow(label: "Models", value: "\(appModel.availableModels.count)")
                statusRow(label: "Navigation", value: navigationModel.navigationState.description)
                statusRow(label: "Anchoring", value: anchorModel.anchoringState.description)
            }
        }
        .padding(.top)
    }
    
    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Extensions

extension NavigationState {
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .navigating: return "Navigating"
        case .guidedTour: return "Guided Tour"
        case .animating: return "Animating"
        case .atWaypoint: return "At Waypoint"
        case .paused: return "Paused"
        }
    }
}

extension AnchoringState {
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .ready: return "Ready"
        case .detecting: return "Detecting"
        case .anchoring: return "Anchoring"
        case .anchored: return "Anchored"
        case .removing: return "Removing"
        case .failed: return "Failed"
        }
    }
}

#Preview {
    AirwayMainView()
        .environmentObject(AirwayAppModel())
        .environmentObject(BronchoscopyNavigationModel())
        .environmentObject(SpatialAnchorModel())
}