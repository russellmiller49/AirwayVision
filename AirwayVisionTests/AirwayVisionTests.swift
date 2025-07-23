import XCTest
@testable import AirwayVision

final class AirwayVisionTests: XCTestCase {
    func testModelLoading() async throws {
        let appModel = AirwayAppModel()
        guard let model = appModel.availableModels.first else { XCTFail("No model"); return }
        do {
            try await appModel.loadModel(model)
        } catch {
            XCTFail("Model loading failed: \(error)")
        }
    }

    func testNavigationProgress() async {
        let navModel = BronchoscopyNavigationModel()
        navModel.startNavigation()
        navModel.moveForward()
        XCTAssertGreaterThanOrEqual(navModel.progress, 0)
    }

    func testAnchorPersistence() async {
        let anchorModel = SpatialAnchorModel()
        await anchorModel.createAnchor(at: [0,0,0])
        XCTAssertNotNil(anchorModel.activeAnchor)
    }
}
