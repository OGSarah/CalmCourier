//
//  ScrollDetector.swift
//  CalmCourier
//

import CoreGraphics
import Foundation

/// Detects rapid scroll reversals and high-velocity flicks that are not followed by a tap.
///
/// Uses real timestamps rather than frame counts, because ProMotion displays refresh at variable rates.
nonisolated struct ScrollDetector: Sendable {
    var reversalCount = 3
    var reversalWindow: TimeInterval = 2
    /// Offsets that move less than this are treated as jitter, not a direction.
    var minimumMovement: CGFloat = 4
    var flickMultiplier: Double = 2
    var flickTapGrace: TimeInterval = 3
    /// The first ~30 seconds of scrolling teach the detector what "fast" means for this person.
    var learningWindow: TimeInterval = 30
    var smoothing: Double = 0.3

    /// Used until enough samples exist to learn a personal baseline, in points per second.
    static let defaultBaselineVelocity: Double = 1200

    private(set) var baselineVelocity: Double = ScrollDetector.defaultBaselineVelocity
    private(set) var smoothedVelocity: Double = 0

    private var lastOffset: CGFloat?
    private var lastTime: TimeInterval?
    private var lastDirection: Int = 0
    private var reversalTimes: [TimeInterval] = []
    private var learningStart: TimeInterval?
    private var learningSamples: [Double] = []
    private var pendingFlickTime: TimeInterval?

    mutating func record(offset: CGFloat, at time: TimeInterval) -> [SignalEvent] {
        defer {
            lastOffset = offset
            lastTime = time
        }
        guard let lastOffset, let lastTime, time > lastTime else { return [] }

        let delta = offset - lastOffset
        let velocity = Double(abs(delta)) / (time - lastTime)
        smoothedVelocity = smoothing * velocity + (1 - smoothing) * smoothedVelocity
        learn(velocity: smoothedVelocity, at: time)

        var events: [SignalEvent] = []

        if abs(delta) >= minimumMovement {
            let direction = delta > 0 ? 1 : -1
            if lastDirection != 0, direction != lastDirection {
                reversalTimes.append(time)
            }
            lastDirection = direction
        }
        reversalTimes.removeAll { time - $0 > reversalWindow }
        if reversalTimes.count >= reversalCount {
            events.append(.scrollReversal)
            reversalTimes.removeAll()
        }

        if pendingFlickTime == nil, smoothedVelocity > baselineVelocity * flickMultiplier {
            pendingFlickTime = time
        }

        return events
    }

    /// A tap after a flick means the person found what they were looking for.
    mutating func recordTap(at time: TimeInterval) {
        pendingFlickTime = nil
    }

    /// Resolves a pending flick once its grace period has passed with no tap.
    mutating func flush(now: TimeInterval) -> [SignalEvent] {
        guard let pendingFlickTime, now - pendingFlickTime >= flickTapGrace else { return [] }
        self.pendingFlickTime = nil
        return [.flick]
    }

    mutating func reset() {
        self = ScrollDetector(reversalCount: reversalCount, reversalWindow: reversalWindow,
                              minimumMovement: minimumMovement, flickMultiplier: flickMultiplier,
                              flickTapGrace: flickTapGrace, learningWindow: learningWindow,
                              smoothing: smoothing)
    }

    private mutating func learn(velocity: Double, at time: TimeInterval) {
        if learningStart == nil { learningStart = time }
        guard let learningStart, time - learningStart <= learningWindow else { return }
        // Ignore near-stationary samples so slow drags don't drag the baseline toward zero.
        guard velocity > 100 else { return }
        learningSamples.append(velocity)
        if learningSamples.count >= 5 {
            let sorted = learningSamples.sorted()
            baselineVelocity = max(sorted[sorted.count / 2], 300)
        }
    }
}
