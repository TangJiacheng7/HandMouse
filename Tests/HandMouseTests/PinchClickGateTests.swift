import XCTest
@testable import HandMouse

final class PinchClickGateTests: XCTestCase {
    func testPressRequiresStablePinch() {
        var gate = PinchClickGate()
        XCTAssertEqual(gate.update(ratio: 0.30, at: 1.000), .none)
        XCTAssertEqual(gate.update(ratio: 0.30, at: 1.030), .none)
        XCTAssertEqual(gate.update(ratio: 0.30, at: 1.060), .down)
        XCTAssertTrue(gate.isDown)
    }

    func testReleaseHysteresisPreventsDoubleClickChatter() {
        var gate = PinchClickGate()
        _ = gate.update(ratio: 0.30, at: 1.0)
        XCTAssertEqual(gate.update(ratio: 0.30, at: 1.1), .down)
        XCTAssertEqual(gate.update(ratio: 0.50, at: 1.2), .none)
        XCTAssertTrue(gate.isDown)
        XCTAssertEqual(gate.update(ratio: 0.60, at: 1.3), .up)
        XCTAssertFalse(gate.isDown)
    }

    func testReleasedPinchCannotPressWithoutStayingBelowThreshold() {
        var gate = PinchClickGate()
        _ = gate.update(ratio: 0.30, at: 1.0)
        XCTAssertEqual(gate.update(ratio: 0.60, at: 1.1), .none)
        XCTAssertEqual(gate.update(ratio: 0.30, at: 1.2), .none)
    }
}
