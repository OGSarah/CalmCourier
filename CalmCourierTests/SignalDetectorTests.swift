//
//  SignalDetectorTests.swift
//  CalmCourierTests
//

import CoreGraphics
import Foundation
import Testing
@testable import CalmCourier

@Suite("Signal detectors")
struct SignalDetectorTests {
    func tap(_ x: CGFloat, _ y: CGFloat, at time: TimeInterval, interactive: Bool = true) -> TapPatternDetector.Tap {
        TapPatternDetector.Tap(point: CGPoint(x: x, y: y), time: time, hitInteractiveElement: interactive)
    }

    // MARK: Taps

    @Test("Four nearby taps within a second are a rage tap")
    func rageTap() {
        var detector = TapPatternDetector()
        let events = (0..<4).flatMap { detector.record(tap(100 + CGFloat($0) * 5, 100, at: Double($0) * 0.2)) }
        #expect(events == [.rageTap])
    }

    @Test("Spread-out or slow taps are not a rage tap")
    func notRageTap() {
        var spread = TapPatternDetector()
        let spreadEvents = (0..<4).flatMap { spread.record(tap(CGFloat($0) * 60, 100, at: Double($0) * 0.2)) }
        #expect(spreadEvents.isEmpty)

        var slow = TapPatternDetector()
        let slowEvents = (0..<4).flatMap { slow.record(tap(100, 100, at: Double($0) * 0.5)) }
        #expect(slowEvents.isEmpty)
    }

    @Test("Dead taps are rate limited")
    func deadTapRateLimit() {
        var detector = TapPatternDetector()
        #expect(detector.record(tap(10, 10, at: 0, interactive: false)) == [.deadTap])
        #expect(detector.record(tap(300, 300, at: 1, interactive: false)).isEmpty)
        #expect(detector.record(tap(10, 10, at: 2.5, interactive: false)) == [.deadTap])
    }

    // MARK: Scrolling

    @Test("Three direction changes within two seconds are a scroll reversal")
    func scrollReversal() {
        var detector = ScrollDetector()
        let offsets: [CGFloat] = [0, 80, 0, 80, 0]
        let events = offsets.enumerated().flatMap { detector.record(offset: $1, at: Double($0) * 0.3) }
        #expect(events == [.scrollReversal])
    }

    @Test("A fast flick with no tap afterwards is reported once the grace period ends")
    func flickWithoutTap() {
        var detector = ScrollDetector()
        var offset: CGFloat = 0
        for frame in 0..<20 {
            offset += 100
            _ = detector.record(offset: offset, at: Double(frame) / 60)
        }
        #expect(detector.flush(now: 1).isEmpty)
        #expect(detector.flush(now: 4) == [.flick])
        #expect(detector.flush(now: 8).isEmpty)
    }

    @Test("The flick baseline is learned from early scrolling and cleared by reset")
    func flickBaseline() {
        var detector = ScrollDetector()
        var offset: CGFloat = 0
        for frame in 0..<30 {
            offset += 10   // ~600 pt/s
            _ = detector.record(offset: offset, at: Double(frame) / 60)
        }
        #expect(detector.baselineVelocity < ScrollDetector.defaultBaselineVelocity)
        detector.reset()
        #expect(detector.baselineVelocity == ScrollDetector.defaultBaselineVelocity)
    }

    // MARK: Typing and navigation

    @Test("Five deletions within two seconds are a backspace burst")
    func backspaceBurst() {
        var detector = TypingDetector()
        var text = "SAVE20NOW"
        var events: [SignalEvent] = []
        for index in 0..<5 {
            let next = String(text.dropLast())
            events += detector.record(old: text, new: next, at: Double(index) * 0.2)
            text = next
        }
        #expect(events == [.backspaceBurst])
    }

    @Test("Four deletions are not a burst")
    func noBurst() {
        var detector = TypingDetector()
        #expect(detector.record(old: "ABCDE", new: "A", at: 0).isEmpty)
    }

    @Test("Bouncing between the same two screens is back-and-forth navigation")
    func backAndForth() {
        var detector = NavigationDetector()
        let screens = ["restaurants", "menu:a", "restaurants", "menu:a"]
        let events = screens.enumerated().flatMap { detector.record(screen: $1, at: Double($0)) }
        #expect(events == [.backAndForth])
    }

    @Test("Ordinary forward navigation is not back-and-forth")
    func forwardNavigation() {
        var detector = NavigationDetector()
        let screens = ["restaurants", "menu:a", "cart", "checkout"]
        let events = screens.enumerated().flatMap { detector.record(screen: $1, at: Double($0)) }
        #expect(events.isEmpty)
    }

    // MARK: Motion

    @Test("Shake detection uses a threshold and a cooldown")
    func shake() {
        var detector = ShakeDetector()
        #expect(detector.record(magnitude: 1.0, at: 0) == false)
        #expect(detector.record(magnitude: 2.5, at: 0) == true)
        #expect(detector.record(magnitude: 2.5, at: 0.5) == false)
        #expect(detector.record(magnitude: 2.5, at: 1.5) == true)
    }
}

@Suite("Signal collector gating")
@MainActor
struct SignalCollectorTests {
    func makeCollector() -> (SignalCollector, AssistiveTechMonitor, () -> [SignalEvent]) {
        let monitor = AssistiveTechMonitor()
        let collector = SignalCollector(assistiveTech: monitor)
        var received: [SignalEvent] = []
        collector.onEvent = { received.append($0) }
        return (collector, monitor, { received })
    }

    @Test("Touch signals are dropped while an assistive technology is active")
    func touchSignalsPaused() {
        let (collector, monitor, received) = makeCollector()
        monitor.simulateActive = true
        for event in SignalEvent.allCases {
            collector.inject(event)
        }
        #expect(received() == SignalEvent.allCases.filter { !$0.isTouchBased })
        #expect(collector.droppedTouchEventCount == SignalEvent.allCases.filter(\.isTouchBased).count)
    }

    @Test("All signals pass when no assistive technology is active")
    func allSignalsPass() {
        let (collector, _, received) = makeCollector()
        for event in SignalEvent.allCases {
            collector.inject(event)
        }
        #expect(received() == SignalEvent.allCases)
    }

    @Test("Pausing ignores real input, but debug injections still pass")
    func pausedCapture() {
        let (collector, _, received) = makeCollector()
        collector.isPaused = true
        collector.recordCheckoutFailure()
        collector.inject(.shake)
        #expect(received() == [.shake])
    }

    @Test("Taps on registered interactive frames are not dead taps")
    func interactiveFrames() {
        let (collector, _, received) = makeCollector()
        collector.registerInteractiveFrame(CGRect(x: 0, y: 0, width: 100, height: 44), id: "button")
        collector.handleTap(at: CGPoint(x: 50, y: 20), hitSystemControl: false)
        #expect(received().isEmpty)
        collector.handleTap(at: CGPoint(x: 300, y: 300), hitSystemControl: false)
        #expect(received() == [.deadTap])
    }
}
