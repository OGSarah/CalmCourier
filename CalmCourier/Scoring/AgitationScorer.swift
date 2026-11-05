//
//  AgitationScorer.swift
//  CalmCourier
//

import Foundation

/// Rolling 0...100 agitation score with exponential decay and tier hysteresis.
///
/// Time is always passed in, so decay and hysteresis are deterministic in tests.
nonisolated struct AgitationScorer: Sendable {
    var config: ScoringConfig
    private(set) var behavioralScore: Double = 0
    private(set) var tier: AgitationTier = .calm

    /// The tier the score currently points at, while it waits out the hysteresis window.
    private(set) var pendingTier: AgitationTier?
    private(set) var pendingSince: Date?
    private var lastUpdate: Date

    init(config: ScoringConfig = .standard, now: Date) {
        self.config = config
        self.lastUpdate = now
    }

    func effectiveScore(battery: BatteryContext) -> Double {
        min(100, behavioralScore + battery.baseline(cap: config.batteryBaselineCap))
    }

    /// Adds an event's weighted points and returns how many points it contributed.
    @discardableResult
    mutating func add(_ event: SignalEvent, battery: BatteryContext, now: Date) -> Double {
        decay(to: now)
        let points = config.weight(for: event) * battery.multiplier
        let before = behavioralScore
        behavioralScore = min(100, max(0, behavioralScore + points))
        return behavioralScore - before
    }

    mutating func decay(to now: Date) {
        let elapsed = max(0, now.timeIntervalSince(lastUpdate))
        if config.halfLife > 0 {
            behavioralScore *= pow(0.5, elapsed / config.halfLife)
        }
        lastUpdate = now
    }

    /// Moves `tier` only after the score has pointed at a different tier for `config.hysteresis` seconds.
    /// Returns true when the tier changed.
    @discardableResult
    mutating func updateTier(battery: BatteryContext, now: Date) -> Bool {
        decay(to: now)
        let target = AgitationTier(score: effectiveScore(battery: battery), config: config)

        guard target != tier else {
            pendingTier = nil
            pendingSince = nil
            return false
        }

        if pendingTier != target {
            pendingTier = target
            pendingSince = now
        }

        if let pendingSince, now.timeIntervalSince(pendingSince) >= config.hysteresis {
            tier = target
            pendingTier = nil
            self.pendingSince = nil
            return true
        }
        return false
    }

    /// Seconds left before a pending tier change applies, or nil if none is pending.
    func timeUntilTierChange(now: Date) -> TimeInterval? {
        guard let pendingSince else { return nil }
        return max(0, config.hysteresis - now.timeIntervalSince(pendingSince))
    }

    mutating func reset(now: Date) {
        behavioralScore = 0
        tier = .calm
        pendingTier = nil
        pendingSince = nil
        lastUpdate = now
    }
}
