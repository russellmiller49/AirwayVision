# AirwayVision

AirwayVision is a specialized Vision Pro application for airway visualization and virtual bronchoscopy, built upon the foundation of DcmVision. This focused application provides immersive 3D exploration of respiratory anatomy with prebuilt models and educational features.

## Features

### 🫁 **Prebuilt Airway Models**
- **High-Quality 3D Models**: Anatomically accurate airway trees from trachea to peripheral bronchi
- **Multiple Variants**: Normal, pathological, and simplified educational models
- **Optimized for Vision Pro**: USD format with LOD system for smooth performance
- **Educational Annotations**: Anatomical labels, landmarks, and clinical information

### 🎮 **Virtual Bronchoscopy**
- **Realistic Navigation**: Follow precomputed centerlines through airway tree
- **Endoscopic View**: Simulated bronchoscope camera with adjustable FOV
- **Interactive Controls**: Gesture-based navigation with speed control
- **Educational Guidance**: Waypoint system with anatomical information

### 🏗️ **Spatial Anchoring**
- **Persistent Placement**: Anchor models in physical space using ARKit
- **Smart Positioning**: Automatic detection of optimal placement locations
- **Multiple Presets**: Table-top, wall-mounted, floor-standing, and floating modes
- **Custom Anchors**: Save and recall personalized anchor configurations

### 📚 **Educational Features**
- **Guided Tours**: Pre-designed educational pathways through anatomy
- **Anatomical Information**: Real-time display of current location and structures
- **Pathology Visualization**: Highlight disease patterns and abnormalities
- **Assessment Tools**: Built-in quiz and evaluation capabilities

### 🥽 **Immersive Experience**
- **Full Immersion Mode**: Complete Vision Pro spatial experience
- **Floating Controls**: Contextual UI panels positioned in 3D space
- **Gesture Recognition**: Natural interaction with spatial tap and drag
- **Environmental Integration**: Seamless blending with physical environment

## Architecture

### Core Components

```
AirwayVision/
├── ApplicationCore/          # App initialization and coordination
├── Model/                   # Data models and business logic
│   ├── AirwayModel.swift          # Airway data structures
│   ├── BronchoscopyNavigationModel.swift  # Navigation system
│   └── SpatialAnchorModel.swift   # Anchoring and positioning
├── UserInterface/           # SwiftUI views and RealityKit content
│   ├── AirwayMainView.swift       # Main window interface
│   ├── AirwayRealityView.swift    # 3D visualization
│   └── AirwayImmersiveView.swift  # Immersive experience
├── PrebuiltModels/          # Asset repository
│   ├── Meshes/                    # USD 3D models
│   ├── Centerlines/               # Navigation paths (JSON)
│   ├── Annotations/               # Educational content (JSON)
│   └── Textures/                  # Visual materials
└── Toolkits/               # Shared utilities from DcmVision
```

### Data Flow

1. **Model Loading**: Prebuilt USD models loaded from bundle
2. **Centerline Processing**: JSON centerline data parsed for navigation
3. **Spatial Anchoring**: ARKit integration for persistent placement
4. **Navigation**: Real-time position tracking along centerlines
5. **Educational Content**: Context-aware information display

## Getting Started

### Prerequisites
- Apple Vision Pro with visionOS 2.0+
- Xcode 16+
- Basic understanding of respiratory anatomy (for educational use)

### Installation
1. Clone the repository
2. Open `AirwayVision.xcodeproj` in Xcode
3. Build and run on Vision Pro simulator or device
4. Grant camera and spatial permission when prompted

### First Use
1. **Launch Application**: Open AirwayVision on Vision Pro
2. **Select Model**: Choose from prebuilt airway models
3. **Position Model**: Use auto-anchoring or manual placement
4. **Start Exploration**: Begin virtual bronchoscopy navigation
5. **Educational Mode**: Enable guided tours and annotations

## Usage Workflows

### Basic Airway Exploration
```swift
// 1. Load normal adult model
let model = appModel.availableModels.first { $0.id == "normal_adult" }
await appModel.loadModel(model)

// 2. Auto-anchor in space
await anchorModel.anchorAirwayModel(entity)

// 3. Start navigation
navigationModel.startNavigation()
```

### Educational Tour
```swift
// 1. Load educational tour
let tour = EducationalTour.respiratoryBasics
await navigationModel.startTour(tour)

// 2. Follow waypoints
for waypoint in tour.waypoints {
    await navigationModel.navigateToWaypoint(waypoint)
}
```

### Pathology Visualization
```swift
// 1. Load pathological model
let copdModel = appModel.availableModels.first { $0.id == "pathological_copd" }
await appModel.loadModel(copdModel)

// 2. Enable pathology highlighting
appModel.visualizationMode = .pathological
```

## Model Library

### Included Models

#### Normal Adult Airway
- **Generations**: 0-6 (Trachea to subsegmental bronchi)
- **Features**: Complete anatomy, all major landmarks
- **Use Case**: Comprehensive education and navigation training
- **File Size**: ~15MB USD, ~2MB centerline data

#### Simplified Adult Airway  
- **Generations**: 0-3 (Trachea to lobar bronchi)
- **Features**: Main airways only, reduced complexity
- **Use Case**: Basic education, performance-critical scenarios
- **File Size**: ~5MB USD, ~1MB centerline data

#### COPD Pathology Model
- **Features**: Airway wall thickening, lumen narrowing, inflammation
- **Annotations**: Disease indicators, severity markers
- **Use Case**: Pathology education, clinical correlation
- **File Size**: ~12MB USD, ~2MB centerline data

### Creating Custom Models

#### From Medical Imaging Data
1. **Segment Airways**: Use 3D Slicer or similar software
2. **Extract Centerline**: Apply VMTK or distance transform algorithms
3. **Convert to USD**: Use ModelIO framework for RealityKit compatibility
4. **Add Annotations**: Create educational markers and information
5. **Optimize**: Apply LOD and Vision Pro optimizations

#### From Synthetic Data
1. **Model Creation**: Use Blender or similar 3D software
2. **Anatomical Accuracy**: Validate against medical references
3. **Educational Value**: Add appropriate annotations and landmarks
4. **Performance**: Optimize for real-time rendering

## Educational Features

### Guided Tours

#### Respiratory Basics Tour
- Introduction to airway anatomy
- Major landmarks and structures
- Normal breathing mechanics
- Assessment questions

#### Advanced Bronchoscopy Tour
- Systematic examination technique
- Branch identification methodology
- Pathology recognition training
- Clinical correlation points

#### Pathology Recognition Tour
- Common disease patterns
- Visual indicators and changes
- Severity assessment
- Differential diagnosis

### Assessment System
- **Multiple Choice Questions**: Anatomical identification
- **Virtual Biopsy**: Simulated procedure training
- **Navigation Challenges**: Timed pathway completion
- **Pathology Detection**: Disease recognition exercises

## Technical Specifications

### Performance Targets
- **60 FPS**: Smooth navigation and interaction
- **<16ms latency**: Responsive gesture recognition
- **Optimized Memory**: Efficient model loading and caching
- **Thermal Management**: Sustained performance without overheating

### Hardware Requirements
- **Apple Vision Pro**: Primary platform
- **RAM**: 16GB minimum for complex models
- **Storage**: 2GB for full model library
- **Processing**: M2 chip for optimal performance

### Rendering Pipeline
- **USD Import**: Native RealityKit model loading
- **LOD System**: Automatic quality adjustment
- **Spatial Anchoring**: ARKit integration
- **Material Optimization**: PBR rendering with Vision Pro enhancements

## Development

### Building from Source
```bash
# Clone repository
git clone https://github.com/your-org/AirwayVision.git
cd AirwayVision

# Open in Xcode
open AirwayVision.xcodeproj

# Build and run
# Select Vision Pro simulator or device target
# Build and run (⌘R)
```

### Adding New Models
1. Place USD file in `PrebuiltModels/Meshes/`
2. Add centerline JSON to `PrebuiltModels/Centerlines/`
3. Create annotation file in `PrebuiltModels/Annotations/`
4. Update `AirwayAppModel.loadPrebuiltModels()` method
5. Test loading and navigation

### Customizing Navigation
```swift
// Extend BronchoscopyNavigationModel
class CustomNavigationModel: BronchoscopyNavigationModel {
    override func updatePosition() {
        super.updatePosition()
        // Add custom navigation logic
    }
}
```

## Deployment

### App Store Distribution
- Educational use classification
- Medical disclaimer requirements
- Privacy policy for spatial data
- Accessibility compliance

### Enterprise Distribution
- Institutional licensing options
- Custom model integration
- Training curriculum alignment
- Progress tracking integration

## Privacy & Security

### Data Collection
- **No Personal Data**: Application operates locally
- **Spatial Data**: Used only for anchoring, not transmitted
- **Usage Analytics**: Optional, anonymized only
- **Medical Content**: Educational use only, not diagnostic

### Compliance
- **FERPA**: Educational record protection
- **Accessibility**: VoiceOver and interaction support
- **Medical Disclaimer**: Research and education only

## Contributing

### Model Contributions
- Anatomical accuracy validation required
- Educational value assessment
- Technical quality standards
- Licensing compatibility

### Code Contributions
- Follow Swift style guidelines
- Maintain Vision Pro compatibility
- Include unit tests for navigation logic
- Documentation for new features

### Educational Content
- Medical accuracy review
- Instructional design principles
- Accessibility considerations
- Multi-language support preparation

## Support

### Documentation
- **Technical Reference**: Detailed API documentation
- **Educational Guides**: Teaching methodology resources
- **Troubleshooting**: Common issues and solutions
- **Best Practices**: Optimal usage patterns

### Community
- **Discussion Forums**: Educational use cases
- **Model Sharing**: Community-contributed content
- **Feature Requests**: User-driven development
- **Bug Reports**: Issue tracking and resolution

## License

AirwayVision is designed for educational and research use. Commercial use requires separate licensing. Prebuilt models may have additional attribution requirements.

### Third-Party Components
- **DcmVision**: Base visualization framework
- **VTK**: Medical image processing
- **RealityKit**: 3D rendering and AR
- **Educational Models**: Various medical institutions

---

**Disclaimer**: This software is for educational and research purposes only. Not intended for clinical diagnosis or treatment decisions. Always consult qualified medical professionals for clinical applications.