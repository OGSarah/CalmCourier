//
//  ScoringConfig.swift
//  CalmCourier
//

import Foundation

/// Every tunable number the scorer uses. The defaults are heuristic guesses, not tuned on real data.
nonisolated struct ScoringConfig: Equatable, Sendable {
    var weights: [SignalEvent: Double] = [
        .rageTap: 15,
        .deadTap: 4,
        .scrollReversal: 8,
        .flick: 5,
        .backspaceBurst: 6,
        .checkoutFailure: 12,
        .backAndForth: 10,
        .shake: 10,
    ]

    /// Seconds for the behavioral score to halve with no new events.
    var halfLife: TimeInterval = 20

    var uneasyThreshold: Double = 30
    var frustratedThreshold: Double = 60

    /// Seconds the score must stay past a threshold before the tier changes.
    var hysteresis: TimeInterval = 3

    /// Battery alone must never reach Uneasy, so this stays below `uneasyThreshold`.
    var batteryBaselineCap: Double = 15

    static let standard = ScoringConfig()

    func weight(for event: SignalEvent) -> Double {
        weights[event] ?? 0
    }
}
