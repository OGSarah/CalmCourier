//
//  TapPatternDetector.swift
//  CalmCourier
//

import CoreGraphics
import Foundation

/// Turns individual taps into rage-tap and dead-tap events.
nonisolated struct TapPatternDetector: Sendable {
    struct Tap: Sendable {
        let point: CGPoint
        let time: TimeInterval
        let hitInteractiveElement: Bool
    }

    var rageTapCount = 4
    var rageTapRadius: CGFloat = 40
    var rageTapWindow: TimeInterval = 1
    /// Dead taps are rate limited so one burst on blank space is not counted many times over.
    var deadTapInterval: TimeInterval = 2

    private var recentTaps: [Tap] = []
    private var lastDeadTapTime: TimeInterval?

    mutating func record(_ tap: Tap) -> [SignalEvent] {
        var events: [SignalEvent] = []

        recentTaps.removeAll { tap.time - $0.time > rageTapWindow }
        recentTaps.append(tap)
        let nearby = recentTaps.filter { hypot($0.point.x - tap.point.x, $0.point.y - tap.point.y) <= rageTapRadius }
        if nearby.count >= rageTapCount {
            events.append(.rageTap)
            recentTaps.removeAll()
        }

        if !tap.hitInteractiveElement,
           lastDeadTapTime.map({ tap.time - $0 >= deadTapInterval }) ?? true {
            events.append(.deadTap)
            lastDeadTapTime = tap.time
        }

        return events
    }

    mutating func reset() {
        recentTaps.removeAll()
        lastDeadTapTime = nil
    }
}
