//
//  ScenarioTests.swift
//  CalmCourierTests
//

import CoreGraphics
import Foundation
import Testing
@testable import CalmCourier

/// Recorded event sequences and battery states fed through the scorer, as listed in the README.
@Suite("Scenarios")
struct ScenarioTests {
    /// Plays timed events into a scorer, updating the tier every half second,
    /// and returns the highest tier reached.
    func highestTier(_ events: [(time: TimeInterval, event: SignalEvent)],
                     battery: BatteryContext,
                     duration: TimeInterval = 15) -> AgitationTier {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        var scorer = AgitationScorer(now: start)
        var pending = events.sorted { $0.time < $1.time }
        var highest = AgitationTier.calm

        for step in stride(from: 0.0, through: duration, by: 0.5) {
            while let next = pending.first, next.time <= step {
                scorer.add(next.event, battery: battery, now: start + next.time)
                pending.removeFirst()
            }
            scorer.updateTier(battery: battery, now: start + step)
            highest = max(highest, scorer.tier)
        }
        return highest
    }

    /// Four taps on the same unresponsive button, run through the real tap detector.
    var fourTapsOnUnresponsiveButton: [(time: TimeInterval, event: SignalEvent)] {
        var detector = TapPatternDetector()
        var events: [(time: TimeInterval, event: SignalEvent)] = []
        for index in 0..<4 {
            let time = Double(index) * 0.2
            let tap = TapPatternDetector.Tap(point: CGPoint(x: 200, y: 400), time: time, hitInteractiveElement: false)
            events += detector.record(tap).map { (time, $0) }
        }
        return events
    }

    @Test("Normal browsing at 80% stays Calm")
    func normalBrowsing() {
        #expect(highestTier([(0, .deadTap)], battery: Fixtures.fullBattery) == .calm)
    }

    @Test("Normal browsing at 8% unplugged stays Calm: the baseline alone stays below Uneasy")
    func normalBrowsingLowBattery() {
        #expect(highestTier([(0, .deadTap)], battery: Fixtures.lowBattery) == .calm)
        #expect(highestTier([], battery: BatteryContext(level: 0.05, isCharging: false, lowPowerMode: true)) == .calm)
    }

    @Test("Four taps on an unresponsive button at 80% stay near the threshold")
    func fourTapsFullBattery() {
        let events = fourTapsOnUnresponsiveButton
        #expect(events.map(\.event).contains(.rageTap))
        #expect(highestTier(events, battery: Fixtures.fullBattery) <= .uneasy)
    }

    @Test("The same four taps at 8% unplugged reach Uneasy")
    func fourTapsLowBattery() {
        #expect(highestTier(fourTapsOnUnresponsiveButton, battery: Fixtures.lowBattery) == .uneasy)
    }

    @Test("The same four taps at 8% while charging match the 80% case")
    func fourTapsCharging() {
        let events = fourTapsOnUnresponsiveButton
        #expect(highestTier(events, battery: Fixtures.lowBatteryCharging)
                == highestTier(events, battery: Fixtures.fullBattery))
    }

    @Test("Failed promo twice, rapid back-and-forth, and rage taps reach Frustrated")
    func frustrated() {
        let events: [(time: TimeInterval, event: SignalEvent)] = [
            (0, .checkoutFailure), (0.5, .checkoutFailure), (1, .backAndForth),
            (1.5, .rageTap), (2, .rageTap), (2.5, .rageTap),
        ]
        #expect(highestTier(events, battery: Fixtures.fullBattery) == .frustrated)
    }

    @Test("Fast scrolling that ends in an add-to-cart tap stays Calm")
    func flickFollowedByEngagement() {
        var detector = ScrollDetector()
        var events: [SignalEvent] = []
        var offset: CGFloat = 0
        // Steady downward flick at ~6000 pt/s, well above twice the default baseline.
        for frame in 0..<20 {
            offset += 100
            events += detector.record(offset: offset, at: Double(frame) / 60)
        }
        detector.recordTap(at: 1)
        events += detector.flush(now: 5)

        #expect(!events.contains(.flick))
        #expect(highestTier(events.map { (0, $0) }, battery: Fixtures.fullBattery) == .calm)
    }
}
