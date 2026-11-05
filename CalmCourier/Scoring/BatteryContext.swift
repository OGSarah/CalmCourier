//
//  BatteryContext.swift
//  CalmCourier
//

import Foundation

/// Device battery state. It shapes how events are weighted but is never an event itself.
nonisolated struct BatteryContext: Equatable, Sendable {
    /// 0...1, or nil when unknown (Simulator reports -1).
    var level: Float?
    var isCharging: Bool
    var lowPowerMode: Bool

    static let unknown = BatteryContext(level: nil, isCharging: false, lowPowerMode: false)

    /// Amplifies behavioral events while the battery is low and unplugged.
    var multiplier: Double {
        guard let level, !isCharging else { return 1.0 }
        if level <= 0.10 { return 1.5 }
        if level <= 0.20 { return 1.25 }
        return 1.0
    }

    /// Points added on top of the behavioral score, capped so battery alone never reaches Uneasy.
    func baseline(cap: Double = ScoringConfig.standard.batteryBaselineCap) -> Double {
        var points = 0.0
        if let level, !isCharging {
            if level <= 0.10 {
                points += 15
            } else if level <= 0.20 {
                points += 10
            }
        }
        if lowPowerMode { points += 5 }
        return min(points, cap)
    }
}
