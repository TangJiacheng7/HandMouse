
import CoreGraphics
import Foundation

enum HandJoint: String, CaseIterable, Hashable {
    case wrist
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

enum GestureMode: String {
    case none
    case openPalm
    case point
    case pinch

    var title: String {
        switch self {
        case .none: "等待手势"
        case .openPalm: "五指张开 · 暂停移动"
        case .point: "食指移动 · 控制指针"
        case .pinch: "捏合 · 点击或拖动"
        }
    }

    var shortTitle: String {
        switch self {
        case .none: "未识别"
        case .openPalm: "待机"
        case .point: "移动"
        case .pinch: "按压"
        }
    }
}

struct HandPoseFrame: Equatable {
    let landmarks: [HandJoint: CGPoint]
    let confidence: Double
    let timestamp: TimeInterval

    static func syntheticOpen() -> HandPoseFrame {
        let points: [HandJoint: CGPoint] = [
            .wrist: CGPoint(x: 0.50, y: 0.20),
            .thumbCMC: CGPoint(x: 0.41, y: 0.29),
            .thumbMP: CGPoint(x: 0.34, y: 0.36),
            .thumbIP: CGPoint(x: 0.28, y: 0.42),
            .thumbTip: CGPoint(x: 0.23, y: 0.47),

            .indexMCP: CGPoint(x: 0.43, y: 0.48),
            .indexPIP: CGPoint(x: 0.39, y: 0.63),
            .indexDIP: CGPoint(x: 0.36, y: 0.76),
            .indexTip: CGPoint(x: 0.34, y: 0.88),

            .middleMCP: CGPoint(x: 0.50, y: 0.51),
            .middlePIP: CGPoint(x: 0.50, y: 0.69),
            .middleDIP: CGPoint(x: 0.50, y: 0.83),
            .middleTip: CGPoint(x: 0.50, y: 0.95),

            .ringMCP: CGPoint(x: 0.57, y: 0.49),
            .ringPIP: CGPoint(x: 0.61, y: 0.63),
            .ringDIP: CGPoint(x: 0.64, y: 0.76),
            .ringTip: CGPoint(x: 0.66, y: 0.87),

            .littleMCP: CGPoint(x: 0.64, y: 0.43),
            .littlePIP: CGPoint(x: 0.72, y: 0.53),
            .littleDIP: CGPoint(x: 0.77, y: 0.62),
            .littleTip: CGPoint(x: 0.81, y: 0.70)
        ]
        return HandPoseFrame(landmarks: points, confidence: 1, timestamp: 0)
    }

    static func syntheticPoint() -> HandPoseFrame {
        var points = syntheticOpen().landmarks
        points[.thumbTip] = CGPoint(x: 0.43, y: 0.37)
        points[.thumbIP] = CGPoint(x: 0.46, y: 0.31)
        points[.thumbMP] = CGPoint(x: 0.48, y: 0.28)
        points[.middlePIP] = CGPoint(x: 0.52, y: 0.61)
        points[.middleDIP] = CGPoint(x: 0.55, y: 0.55)
        points[.middleTip] = CGPoint(x: 0.57, y: 0.48)
        points[.ringPIP] = CGPoint(x: 0.58, y: 0.58)
        points[.ringDIP] = CGPoint(x: 0.62, y: 0.54)
        points[.ringTip] = CGPoint(x: 0.65, y: 0.51)
        points[.littlePIP] = CGPoint(x: 0.66, y: 0.49)
        points[.littleDIP] = CGPoint(x: 0.69, y: 0.47)
        points[.littleTip] = CGPoint(x: 0.72, y: 0.45)
        return HandPoseFrame(landmarks: points, confidence: 1, timestamp: 0)
    }

    static func syntheticPinch() -> HandPoseFrame {
        var points = syntheticPoint().landmarks
        points[.thumbTip] = CGPoint(x: 0.35, y: 0.855)
        points[.thumbIP] = CGPoint(x: 0.39, y: 0.78)
        points[.thumbMP] = CGPoint(x: 0.43, y: 0.69)
        return HandPoseFrame(landmarks: points, confidence: 1, timestamp: 0)
    }

    static func syntheticFist() -> HandPoseFrame {
        var points = syntheticOpen().landmarks
        points[.thumbTip] = CGPoint(x: 0.47, y: 0.31)
        points[.indexDIP] = CGPoint(x: 0.46, y: 0.43)
        points[.indexTip] = CGPoint(x: 0.49, y: 0.34)
        points[.middleDIP] = CGPoint(x: 0.52, y: 0.42)
        points[.middleTip] = CGPoint(x: 0.53, y: 0.34)
        points[.ringDIP] = CGPoint(x: 0.57, y: 0.41)
        points[.ringTip] = CGPoint(x: 0.57, y: 0.35)
        points[.littleDIP] = CGPoint(x: 0.62, y: 0.39)
        points[.littleTip] = CGPoint(x: 0.61, y: 0.35)
        return HandPoseFrame(landmarks: points, confidence: 1, timestamp: 0)
    }
}

struct GestureReading: Equatable {
    let mode: GestureMode
    let pointer: CGPoint?
    let pinchRatio: Double
    let openScore: Double
    let confidence: Double
}

struct GestureClassifier {
    private let joints: [HandJoint: CGPoint]
    private let pinchReleaseThreshold = 0.55

    init(joints: [HandJoint: CGPoint] = [:]) {
        self.joints = joints
    }

    func classify(_ frame: HandPoseFrame) -> GestureReading {
        let points = joints.isEmpty ? frame.landmarks : joints
        guard
            let wrist = points[.wrist],
            let indexTip = points[.indexTip],
            let thumbTip = points[.thumbTip],
            let indexPIP = points[.indexPIP],
            let middlePIP = points[.middlePIP],
            let ringPIP = points[.ringPIP],
            let littlePIP = points[.littlePIP],
            let middleTip = points[.middleTip],
            let ringTip = points[.ringTip],
            let littleTip = points[.littleTip],
            let thumbMP = points[.thumbMP],
            let thumbTipForOpen = points[.thumbTip]
        else {
            return GestureReading(
                mode: .none,
                pointer: nil,
                pinchRatio: 0,
                openScore: 0,
                confidence: 0
            )
        }

        let palmScale = max(
            distance(points[.indexMCP] ?? wrist, points[.littleMCP] ?? wrist),
            max(distance(wrist, points[.middleMCP] ?? middlePIP), 0.055)
        )
        let pinchRatio = distance(thumbTip, indexTip) / palmScale
        let indexExtended = isExtended(wrist: wrist, pip: indexPIP, tip: indexTip)
        let indexReach = distance(wrist, indexTip) / max(distance(wrist, indexPIP), 0.04)
        let middleExtended = isExtended(wrist: wrist, pip: middlePIP, tip: middleTip)
        let ringExtended = isExtended(wrist: wrist, pip: ringPIP, tip: ringTip)
        let littleExtended = isExtended(wrist: wrist, pip: littlePIP, tip: littleTip)
        let thumbSpread = distance(wrist, thumbTipForOpen) / max(distance(wrist, thumbMP), 0.04)
        let openScore = [indexExtended, middleExtended, ringExtended, littleExtended]
            .filter { $0 }.count
        let isOpen = openScore >= 4 && thumbSpread > 1.08

        let mode: GestureMode
        if pinchRatio < pinchReleaseThreshold, indexReach > 0.90 {
            mode = .pinch
        } else if isOpen {
            mode = .openPalm
        } else if indexExtended {
            mode = .point
        } else {
            mode = .none
        }

        // Keep the skeleton in preview coordinates, but invert only the
        // pointer's horizontal motion so physical left/right matches the user.
        let pointer = CGPoint(x: 1 - indexTip.x, y: indexTip.y)
        return GestureReading(
            mode: mode,
            pointer: pointer,
            pinchRatio: pinchRatio,
            openScore: Double(openScore) / 4.0,
            confidence: frame.confidence
        )
    }

    private func isExtended(wrist: CGPoint, pip: CGPoint, tip: CGPoint) -> Bool {
        distance(wrist, tip) > max(0.025, distance(wrist, pip) * 1.16)
    }
}

func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}
