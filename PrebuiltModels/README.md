# AirwayVision Prebuilt Models

This directory contains prebuilt airway models, centerlines, and annotations for the AirwayVision application.

## Directory Structure

```
PrebuiltModels/
├── Meshes/           # 3D airway meshes in USD format
├── Centerlines/      # Navigation centerline data in JSON format
├── Annotations/      # Educational annotations in JSON format
└── Textures/         # Optional texture files for enhanced visualization
```

## Model Types

### Available Models

1. **normal_adult** - Healthy adult airway system
   - Complete bronchial tree from trachea to 6th generation
   - Optimized for educational use
   - Includes anatomical labels and landmarks

2. **simplified_adult** - Simplified educational model
   - Main airways only (trachea to 3rd generation)
   - Reduced complexity for better performance
   - Ideal for basic navigation training

3. **pathological_copd** - COPD pathology model
   - Shows characteristic airway changes
   - Includes inflammation and obstruction
   - Educational pathology annotations

## File Formats

### Mesh Files (.usd)
- Universal Scene Description format for RealityKit
- Optimized for Vision Pro rendering
- Multiple LOD levels included
- Physically-based materials

### Centerline Files (.json)
```json
[
  {
    "id": "trachea",
    "name": "Trachea",
    "parentId": null,
    "childIds": ["right_main", "left_main"],
    "generation": 0,
    "centerlinePoints": [
      {
        "position": [0.0, 0.0, 0.0],
        "direction": [0.0, -1.0, 0.0],
        "radius": 0.008,
        "generation": 0,
        "branchId": "trachea",
        "distanceFromStart": 0.0,
        "anatomicalLabel": "Trachea",
        "landmarks": [
          {
            "name": "Carina",
            "position": [0.0, -0.12, 0.0],
            "type": "bifurcation",
            "description": "Tracheal bifurcation point"
          }
        ]
      }
    ],
    "anatomicalInfo": {
      "standardName": "Trachea",
      "alternativeNames": ["Windpipe"],
      "clinicalRelevance": "Main airway connecting larynx to bronchi",
      "commonFindings": ["Normal cartilage rings", "Clear lumen"],
      "normalDimensions": {
        "diameterMin": 15.0,
        "diameterMax": 20.0,
        "lengthMin": 100.0,
        "lengthMax": 120.0
      }
    }
  }
]
```

### Annotation Files (.json)
```json
[
  {
    "type": "text",
    "position": [0.0, 0.05, 0.0],
    "content": "Trachea - Main airway",
    "importance": "high"
  },
  {
    "type": "arrow",
    "position": [0.0, -0.12, 0.0],
    "content": "Carina - Bifurcation point",
    "importance": "critical"
  }
]
```

## Creating New Models

### From 3D Slicer
1. Segment airways using appropriate modules
2. Export as USD using ModelIO conversion
3. Generate centerline using VMTK or similar
4. Create annotation data manually

### From DICOM
1. Use VTK pipeline for airway extraction
2. Extract centerline using distance transform
3. Convert to USD format
4. Generate educational annotations

### Optimization Guidelines
- Target 10,000-30,000 triangles for detailed models
- Use LOD system for performance
- Include proper normal data for lighting
- Optimize texture resolution for Vision Pro

## Educational Content

### Anatomical Labels
- Standard anatomical nomenclature
- Alternative naming conventions
- Clinical significance
- Normal vs abnormal findings

### Pathology Annotations
- Common disease patterns
- Visual changes and indicators
- Severity grading
- Clinical correlations

### Navigation Waypoints
- Key anatomical landmarks
- Educational stopping points
- Guided tour sequences
- Assessment checkpoints

## Usage in App

Models are automatically loaded by the AirwayVision app:

```swift
// Load model
let model = AirwayModel(
    id: "normal_adult",
    name: "Normal Adult Airway",
    description: "Healthy adult respiratory system",
    complexity: .detailed,
    anatomicalVariant: .normal
)

// Load into app
await appModel.loadModel(model)
```

## Performance Considerations

- Models are optimized for Vision Pro hardware
- Automatic LOD switching based on viewing distance
- Efficient material usage
- Spatial anchoring support

## Quality Assurance

All models should be validated for:
- Anatomical accuracy
- Educational value
- Technical performance
- Clinical relevance
- Accessibility compliance

## Licensing

Models should include appropriate licensing information:
- Educational use permissions
- Attribution requirements
- Distribution limitations
- Commercial use restrictions