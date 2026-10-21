import CoreGraphics
import XCTest
@testable import HandMouse

final class PointerMappingTests: XCTestCase {
    func testFirstSampleAnchorsWithoutJumping() {
        var mapper = PointerMapper()
        let current = CGPoint(x: 400, y: 300)
        let next = mapper.nextCursorPosition(
            normalized: CGPoint(x: 0.5, y: 0.5),
            current: current,
            screen: CGRect(x: 0, y: 0, width: 1600, height: 1000)
        )
        XCTAssertEqual(next, current)
    }

    func testMovementMapsInExpectedDirectionAndClamps() {
        var mapper = PointerMapper()
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        _ = mapper.nextCursorPosition(
            normalized: CGPoint(x: 0.4, y: 0.4),
            current: CGPoint(x: 100, y: 100),
            screen: screen
        )
        let next = mapper.nextCursorPosition(
            normalized: CGPoint(x: 0.6, y: 0.6),
            current: CGPoint(x: 100, y: 100),
            screen: screen
        )
        XCTAssertGreaterThan(next.x, 100)
        XCTAssertGreaterThan(next.y, 100)
        XCTAssertLessThanOrEqual(next.x, screen.maxX)
        XCTAssertLessThanOrEqual(next.y, screen.maxY)
    }

    func testOneEuroFilterReducesSingleFrameNoise() {
        let filter = OneEuroPointFilter()
        _ = filter.filter(CGPoint(x: 0.5, y: 0.5), timestamp: 1.0)
        let output = filter.filter(CGPoint(x: 0.9, y: 0.5), timestamp: 1.033)
        XCTAssertLessThan(output.x, 0.9)
        XCTAssertGreaterThan(output.x, 0.5)
    }
}
