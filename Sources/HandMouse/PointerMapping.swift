import CoreGraphics
import Foundation

struct PointerMapper {
    var sensitivity: Double = 1.0
    private var previous: CGPoint?

    mutating func reset() {
        previous = nil
    }

    mutating func nextCursorPosition(
        normalized: CGPoint,
        current: CGPoint,
        screen: CGRect
    ) -> CGPoint {
        guard let prior = previous else {
            previous = normalized
            return current
        }

        let dx = normalized.x - prior.x
        let dy = normalized.y - prior.y
        previous = normalized
        guard abs(dx) > 0.0004 || abs(dy) > 0.0004 else {
            return current
        }

        let gain = 1.85 * sensitivity
        var target = CGPoint(
            x: current.x + dx * screen.width * gain,
            y: current.y + dy * screen.height * gain
        )
        target.x = min(max(target.x, screen.minX + 1), screen.maxX - 2)
        target.y = min(max(target.y, screen.minY + 1), screen.maxY - 2)
        return target
    }
}

final class OneEuroPointFilter {
    private let minCutoff: Double
    private let beta: Double
    private let derivativeCutoff: Double
    private var previous: CGPoint?
    private var previousDerivative: CGPoint?
    private var previousTime: TimeInterval?

    init(minCutoff: Double = 1.25, beta: Double = 0.65, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    func reset() {
        previous = nil
        previousDerivative = nil
        previousTime = nil
    }

    func filter(_ value: CGPoint, timestamp: TimeInterval) -> CGPoint {
        guard let lastValue = previous, let lastTime = previousTime else {
            previous = value
            previousTime = timestamp
            previousDerivative = .zero
            return value
        }

        let dt = max(timestamp - lastTime, 1.0 / 120.0)
        let derivative = CGPoint(
            x: (value.x - lastValue.x) / dt,
            y: (value.y - lastValue.y) / dt
        )
        let filteredDerivative = smooth(
            current: derivative,
            previous: previousDerivative ?? .zero,
            alpha: alpha(cutoff: derivativeCutoff, dt: dt)
        )
        let speed = hypot(filteredDerivative.x, filteredDerivative.y)
        let cutoff = minCutoff + beta * speed
        let filteredValue = smooth(
            current: value,
            previous: lastValue,
            alpha: alpha(cutoff: cutoff, dt: dt)
        )
        previous = filteredValue
        previousDerivative = filteredDerivative
        previousTime = timestamp
        return filteredValue
    }

    private func alpha(cutoff: Double, dt: TimeInterval) -> Double {
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }

    private func smooth(current: CGPoint, previous: CGPoint, alpha: Double) -> CGPoint {
        CGPoint(
            x: previous.x + (current.x - previous.x) * alpha,
            y: previous.y + (current.y - previous.y) * alpha
        )
    }
}
