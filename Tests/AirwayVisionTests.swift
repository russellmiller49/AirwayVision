import XCTest
@testable import AirwayVision

final class AirwayVisionTests: XCTestCase {
    func testModelLoading() throws {
        let model = AirwayModel(id: "normal_adult", name: "Normal", description: "", complexity: .detailed, anatomicalVariant: .normal)
        let appModel = AirwayAppModel()
        XCTAssertNoThrow(try awaitTask { try await appModel.loadModel(model) })
    }

    func testNavigationProgress() {
        let nav = BronchoscopyNavigationModel()
        nav.progress = 0.5
        XCTAssertEqual(nav.progress, 0.5)
    }

    func testAnchorPersistence() {
        let anchorModel = SpatialAnchorModel()
        XCTAssertEqual(anchorModel.anchoringState, .idle)
    }
}

func awaitTask(_ operation: @escaping () async throws -> Void) throws {
    let expectation = XCTestExpectation(description: "async")
    Task {
        do {
            try await operation()
        } catch {
            XCTFail("\(error)")
        }
        expectation.fulfill()
    }
    wait(for: [expectation], timeout: 10)
}
