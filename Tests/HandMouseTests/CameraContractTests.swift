import XCTest
@testable import HandMouse

final class CameraContractTests: XCTestCase {
    func testCameraDiscoveryReturnsStableContractWithoutStartingCapture() {
        let cameras = CameraController.discoverCameras()
        XCTAssertEqual(Set(cameras.map(\.uniqueID)).count, cameras.count)
        XCTAssertTrue(cameras.allSatisfy { !$0.localizedName.isEmpty })
    }
}
