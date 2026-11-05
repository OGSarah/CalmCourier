//
//  SignalCollector.swift
//  CalmCourier
//

import CoreGraphics
import Foundation
import Observation

/// Owns the detectors and turns raw input into `SignalEvent`s.
///
/// Every signal, real or injected from the debug panel, flows through `emit(_:)`,
/// so assistive-technology gating and pausing apply to all of them the same way.
@Observable
final class SignalCollector {
    /// Called for every event that passes gating. Set by `AppEnvironment`.
    @ObservationIgnored var onEvent: ((SignalEvent) -> Void)?

    let assistiveTech: AssistiveTechMonitor

    /// Pauses all capture, for example while the debug panel is open so its buttons
    /// don't register as rage taps.
    var isPaused = false

    /// Touch events dropped because an assistive technology was running.
    private(set) var droppedTouchEventCount = 0

    var areTouchSignalsPaused: Bool { assistiveTech.isActive }

    /// Window-coordinate frames of SwiftUI controls, used to tell dead taps from real ones.
    @ObservationIgnored private var interactiveFrames: [String: CGRect] = [:]
    @ObservationIgnored private var taps = TapPatternDetector()
    @ObservationIgnored private var scroll = ScrollDetector()
    @ObservationIgnored private var typing = TypingDetector()
    @ObservationIgnored private var navigation = NavigationDetector()
    @ObservationIgnored private let now: () -> Date

    init(assistiveTech: AssistiveTechMonitor, now: @escaping () -> Date = { .now }) {
        self.assistiveTech = assistiveTech
        self.now = now
    }

    var scrollBaselineVelocity: Double { scroll.baselineVelocity }

    // MARK: Input

    func handleTap(at point: CGPoint, hitSystemControl: Bool) {
        let hitInteractive = hitSystemControl || interactiveFrames.values.contains { $0.contains(point) }
        let time = timestamp
        scroll.recordTap(at: time)
        emit(taps.record(.init(point: point, time: time, hitInteractiveElement: hitInteractive)))
    }

    func scrollDidChange(to offset: CGFloat) {
        emit(scroll.record(offset: offset, at: timestamp))
    }

    func textDidChange(from old: String, to new: String) {
        emit(typing.record(old: old, new: new, at: timestamp))
    }

    func screenDidAppear(_ screen: String) {
        emit(navigation.record(screen: screen, at: timestamp))
    }

    func recordCheckoutFailure() {
        emit([.checkoutFailure])
    }

    func recordShake() {
        emit([.shake])
    }

    /// Debug-panel injection. Takes the same path as a real signal.
    /// Injections still respect assistive-technology gating, but not `isPaused`,
    /// since they come from the open debug panel.
    func inject(_ event: SignalEvent) {
        emit([event], ignoringPause: true)
    }

    /// Called once per second to resolve time-based detections such as flicks.
    func tick() {
        emit(scroll.flush(now: timestamp))
    }

    // MARK: Interactive frames

    func registerInteractiveFrame(_ frame: CGRect, id: String) {
        interactiveFrames[id] = frame
    }

    func unregisterInteractiveFrame(id: String) {
        interactiveFrames[id] = nil
    }

    func reset() {
        taps.reset()
        scroll.reset()
        typing.reset()
        navigation.reset()
        droppedTouchEventCount = 0
    }

    // MARK: Private

    private var timestamp: TimeInterval { now().timeIntervalSinceReferenceDate }

    private func emit(_ events: [SignalEvent], ignoringPause: Bool = false) {
        guard ignoringPause || !isPaused else { return }
        for event in events {
            if event.isTouchBased && areTouchSignalsPaused {
                droppedTouchEventCount += 1
                continue
            }
            onEvent?(event)
        }
    }
}
