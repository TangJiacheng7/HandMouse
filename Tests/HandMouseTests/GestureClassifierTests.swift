import CoreGraphics
import XCTest
@testable import HandMouse

final class GestureClassifierTests: XCTestCase {
    private let classifier = GestureClassifier()

    func testOpenPalmPausesPointerControl() {
        let reading = classifier.classify(.syntheticOpen())
        XCTAssertEqual(reading.mode, .openPalm)
        XCTAssertEqual(reading.openScore, 1.0)
        XCTAssertNotNil(reading.pointer)
    }

    func testPointPoseProducesPointer() {
        let reading = classifier.classify(.syntheticPoint())
        XCTAssertEqual(reading.mode, .point)
        XCTAssertNotNil(reading.pointer)
        XCTAssertGreaterThan(reading.pinchRatio, 0.55)
    }

    func testPinchPoseCrossesPressThreshold() {
        let reading = classifier.classify(.syntheticPinch())
        XCTAssertEqual(reading.mode, .pinch)
        XCTAssertLessThan(reading.pinchRatio, 0.42)
    }

    func testClassifierUsesNormalizedPreviewCoordinates() throws {
        var pose = HandPoseFrame.syntheticPoint()
        var points = pose.landmarks
        points[.indexTip] = CGPoint(x: 0.72, y: 0.80)
        pose = HandPoseFrame(landmarks: points, confidence: 1, timestamp: 0)
        let reading = classifier.classify(pose)
        let pointer = try XCTUnwrap(reading.pointer)
        XCTAssertEqual(Double(pointer.x), 0.72, accuracy: 0.0001)
        XCTAssertEqual(Double(pointer.y), 0.80, accuracy: 0.0001)
    }

    func testClosedFistDoesNotClick() {
        let reading = classifier.classify(.syntheticFist())
        XCTAssertNotEqual(reading.mode, .pinch)
    }
}
