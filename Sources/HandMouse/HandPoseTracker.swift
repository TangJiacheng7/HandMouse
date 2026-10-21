import CoreVideo
import Foundation
import QuartzCore
import Vision

final class HandPoseTracker {
    private let request: VNDetectHumanHandPoseRequest

    init() {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        request.revision = VNDetectHumanHandPoseRequestRevision1
    }

    func detect(in sampleBuffer: CMSampleBuffer) -> HandPoseFrame? {
        do {
            let handler = VNImageRequestHandler(
                cmSampleBuffer: sampleBuffer,
                orientation: .up,
                options: [:]
            )
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            let recognized = try observation.recognizedPoints(.all)
            var landmarks: [HandJoint: CGPoint] = [:]
            var totalConfidence: Double = 0
            var count = 0

            for (visionJoint, joint) in Self.jointMap {
                guard let point = recognized[visionJoint], point.confidence >= 0.25 else {
                    continue
                }
                // Convert Vision's lower-left image coordinates to the
                // top-left coordinate space used by the preview canvas.
                // Preserve X: this camera path and preview are both unmirrored.
                landmarks[joint] = CGPoint(
                    x: point.location.x,
                    y: 1 - point.location.y
                )
                totalConfidence += Double(point.confidence)
                count += 1
            }

            guard count >= 16 else { return nil }
            return HandPoseFrame(
                landmarks: landmarks,
                confidence: totalConfidence / Double(count),
                timestamp: CACurrentMediaTime()
            )
        } catch {
            return nil
        }
    }

    private static let jointMap: [VNHumanHandPoseObservation.JointName: HandJoint] = [
        .wrist: .wrist,
        .thumbCMC: .thumbCMC,
        .thumbMP: .thumbMP,
        .thumbIP: .thumbIP,
        .thumbTip: .thumbTip,
        .indexMCP: .indexMCP,
        .indexPIP: .indexPIP,
        .indexDIP: .indexDIP,
        .indexTip: .indexTip,
        .middleMCP: .middleMCP,
        .middlePIP: .middlePIP,
        .middleDIP: .middleDIP,
        .middleTip: .middleTip,
        .ringMCP: .ringMCP,
        .ringPIP: .ringPIP,
        .ringDIP: .ringDIP,
        .ringTip: .ringTip,
        .littleMCP: .littleMCP,
        .littlePIP: .littlePIP,
        .littleDIP: .littleDIP,
        .littleTip: .littleTip
    ]
}
