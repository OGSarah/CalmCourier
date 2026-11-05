//
//  AgitationScorerTests.swift
//  CalmCourierTests
//

import Foundation
import Testing
@testable import CalmCourier

@Suite("Agitation scorer")
struct AgitationScorerTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    /// A config with effectively no decay, so hysteresis tests are about time alone.
    var noDecay: ScoringConfig {
        var config = ScoringConfig.standard
        config.halfLife = .greatestFiniteMagnitude
        return config
    }

    @Test("Each event adds its configured weight", arguments: SignalEvent.allCases)
    func expectedPoints(event: SignalEvent) {
        var scorer = AgitationScorer(now: start)
        let points = scorer.add(event, battery: .unknown, now: start)
        #expect(points == ScoringConfig.standard.weight(for: event))
        #expect(scorer.behavioralScore == ScoringConfig.standard.weight(for: event))
    }

    @Test("Low battery multiplies event points")
    func batteryMultiplier() {
        var scorer = AgitationScorer(now: start)
        let points = scorer.add(.rageTap, battery: Fixtures.lowBattery, now: start)
        #expect(points == 22.5)
    }

    @Test("Score halves after one half-life")
    func decayHalves() {
        var scorer = AgitationScorer(now: start)
        scorer.add(.rageTap, battery: .unknown, now: start)
        scorer.decay(to: start + ScoringConfig.standard.halfLife)
        #expect(abs(scorer.behavioralScore - 7.5) < 0.0001)
    }

    @Test("Score is clamped to 0...100")
    func clamping() {
        var scorer = AgitationScorer(now: start)
        for _ in 0..<20 {
            scorer.add(.rageTap, battery: Fixtures.lowBattery, now: start)
        }
        #expect(scorer.behavioralScore == 100)
        #expect(scorer.effectiveScore(battery: Fixtures.lowBattery) == 100)

        var negative = ScoringConfig.standard
        negative.weights[.deadTap] = -50
        var lowScorer = AgitationScorer(config: negative, now: start)
        lowScorer.add(.deadTap, battery: .unknown, now: start)
        #expect(lowScorer.behavioralScore == 0)
    }

    @Test("Tier changes only after the score stays past a threshold for the hysteresis window")
    func hysteresis() {
        var scorer = AgitationScorer(config: noDecay, now: start)
        scorer.add(.rageTap, battery: .unknown, now: start)
        scorer.add(.rageTap, battery: .unknown, now: start)

        #expect(scorer.updateTier(battery: .unknown, now: start) == false)
        #expect(scorer.pendingTier == .uneasy)
        #expect(scorer.updateTier(battery: .unknown, now: start + 2.9) == false)
        #expect(scorer.tier == .calm)
        #expect(scorer.updateTier(battery: .unknown, now: start + 3) == true)
        #expect(scorer.tier == .uneasy)
    }

    @Test("A brief dip below the threshold does not make the tier flicker")
    func noFlicker() {
        var scorer = AgitationScorer(now: start)
        scorer.add(.rageTap, battery: .unknown, now: start)
        scorer.add(.rageTap, battery: .unknown, now: start)
        scorer.updateTier(battery: .unknown, now: start)
        // Decay drops the score under 30 within a second, before the window passes.
        scorer.updateTier(battery: .unknown, now: start + 1)
        #expect(scorer.pendingTier == nil)
        scorer.updateTier(battery: .unknown, now: start + 5)
        #expect(scorer.tier == .calm)
    }

    @Test("Reset clears score, tier, and pending change")
    func reset() {
        var scorer = AgitationScorer(config: noDecay, now: start)
        scorer.add(.rageTap, battery: .unknown, now: start)
        scorer.add(.rageTap, battery: .unknown, now: start)
        scorer.updateTier(battery: .unknown, now: start)
        scorer.updateTier(battery: .unknown, now: start + 3)
        scorer.reset(now: start + 4)
        #expect(scorer.behavioralScore == 0)
        #expect(scorer.tier == .calm)
        #expect(scorer.pendingTier == nil)
    }
}
