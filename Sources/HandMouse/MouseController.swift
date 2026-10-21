import ApplicationServices
import CoreGraphics
import Foundation
import QuartzCore

struct ControlSnapshot: Equatable {
    var mode: GestureMode = .none
    var pinchRatio: Double = 0
    var confidence: Double = 0
    var isPressed = false
    var pointer = CGPoint.zero
}

enum PinchTransition: Equatable {
    case none
    case down
    case up
}

struct PinchClickGate {
    static let onThreshold = 0.42
    static let offThreshold = 0.55
    private(set) var isDown = false
    private let holdDuration: TimeInterval
    private var belowSince: TimeInterval?

    init(holdDuration: TimeInterval = 0.055) {
        self.holdDuration = holdDuration
    }

    mutating func update(ratio: Double, at now: TimeInterval) -> PinchTransition {
        if !isDown, ratio < Self.onThreshold {
            let started = belowSince ?? now
            belowSince = started
            if now - started >= holdDuration {
                isDown = true
                belowSince = nil
                return .down
            }
        } else if isDown, ratio > Self.offThreshold {
            isDown = false
            belowSince = nil
            return .up
        } else if !isDown, ratio >= Self.onThreshold {
            belowSince = nil
        }
        return .none
    }

    mutating func reset() -> Bool {
        let wasDown = isDown
        isDown = false
        belowSince = nil
        return wasDown
    }
}

final class MouseInjector {
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static var mainDisplayBounds: CGRect {
        CGDisplayBounds(CGMainDisplayID())
    }

    static var currentPointer: CGPoint {
        CGEvent(source: nil)?.location ?? CGPoint(
            x: mainDisplayBounds.midX,
            y: mainDisplayBounds.midY
        )
    }

    func move(to point: CGPoint) {
        guard Self.isAccessibilityGranted else { return }
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        event?.post(tap: .cghidEventTap)
    }

    func mouseDown(at point: CGPoint) {
        guard Self.isAccessibilityGranted else { return }
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        event?.post(tap: .cghidEventTap)
    }

    func mouseUp(at point: CGPoint) {
        guard Self.isAccessibilityGranted else { return }
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        event?.post(tap: .cghidEventTap)
    }

    func scroll(horizontalDelta: CGFloat) {
        guard Self.isAccessibilityGranted else { return }
        let bounded = max(-900, min(900, horizontalDelta * 700))
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: Int32(bounded),
            wheel3: 0
        )
        event?.post(tap: .cghidEventTap)
    }
}

final class GestureControlEngine {
    var sensitivity: Double = 1.0
    var onUpdate: ((ControlSnapshot) -> Void)?

    private let classifier = GestureClassifier()
    private let injector = MouseInjector()
    private var pointFilter = OneEuroPointFilter()
    private var pointerMapper = PointerMapper()
    private var cursorPosition = CGPoint.zero
    private var pinchGate = PinchClickGate()
    private var lastPoseTime: TimeInterval = 0
    private var lastOpenPointer: CGPoint?
    private var lastOpenTime: TimeInterval = 0
    private var swipeCooldownUntil: TimeInterval = 0
    var isRunning = false

    func begin() {
        isRunning = true
        cursorPosition = MouseInjector.currentPointer
        pointFilter.reset()
        pointerMapper.reset()
        _ = pinchGate.reset()
        lastOpenPointer = nil
    }

    func end() {
        if pinchGate.isDown {
            injector.mouseUp(at: cursorPosition)
        }
        _ = pinchGate.reset()
        isRunning = false
        pointFilter.reset()
        pointerMapper.reset()
        onUpdate?(ControlSnapshot(pointer: cursorPosition))
    }

    func recalibrate() {
        pointFilter.reset()
        pointerMapper.reset()
        cursorPosition = MouseInjector.currentPointer
        onUpdate?(ControlSnapshot(pointer: cursorPosition))
    }

    func process(frame: HandPoseFrame?, at now: TimeInterval = CACurrentMediaTime()) {
        guard isRunning else { return }
        guard let frame else {
            releaseForLostHand(at: now)
            return
        }

        lastPoseTime = now
        let reading = classifier.classify(frame)
        let filtered = reading.pointer.map { pointFilter.filter($0, timestamp: now) }

        switch reading.mode {
        case .point, .pinch:
            if let filtered {
                let next = pointerMapper.nextCursorPosition(
                    normalized: filtered,
                    current: cursorPosition,
                    screen: MouseInjector.mainDisplayBounds
                )
                if next != cursorPosition {
                    cursorPosition = next
                    injector.move(to: cursorPosition)
                }
            }
            updatePinch(reading.pinchRatio, at: now)
            lastOpenPointer = nil

        case .openPalm:
            releasePinch()
            pointerMapper.reset()
            pointFilter.reset()
            detectPalmSwipe(pointer: filtered, at: now)

        case .none:
            releasePinch()
            pointerMapper.reset()
            pointFilter.reset()
        }

        onUpdate?(
            ControlSnapshot(
                mode: reading.mode,
                pinchRatio: reading.pinchRatio,
                confidence: reading.confidence,
                isPressed: pinchGate.isDown,
                pointer: cursorPosition
            )
        )
    }

    private func updatePinch(_ ratio: Double, at now: TimeInterval) {
        switch pinchGate.update(ratio: ratio, at: now) {
        case .down:
            injector.mouseDown(at: cursorPosition)
        case .up:
            injector.mouseUp(at: cursorPosition)
        case .none:
            break
        }
    }

    private func releasePinch() {
        if pinchGate.reset() {
            injector.mouseUp(at: cursorPosition)
        }
    }

    private func detectPalmSwipe(pointer: CGPoint?, at now: TimeInterval) {
        guard let pointer, now >= swipeCooldownUntil else {
            lastOpenPointer = pointer
            lastOpenTime = now
            return
        }
        if let previous = lastOpenPointer, now - lastOpenTime < 0.38 {
            let dx = pointer.x - previous.x
            if abs(dx) > 0.16, abs(dx) > abs(pointer.y - previous.y) * 1.25 {
                injector.scroll(horizontalDelta: dx > 0 ? -1.8 : 1.8)
                swipeCooldownUntil = now + 0.75
                lastOpenPointer = nil
                return
            }
        }
        lastOpenPointer = pointer
        lastOpenTime = now
    }

    private func releaseForLostHand(at now: TimeInterval) {
        if now - lastPoseTime > 0.45 {
            releasePinch()
            pointFilter.reset()
            pointerMapper.reset()
            lastOpenPointer = nil
            onUpdate?(ControlSnapshot(pointer: cursorPosition))
        }
    }
}
