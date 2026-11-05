//
//  AssistiveTechMonitor.swift
//  CalmCourier
//

import Foundation
import Observation
import UIKit

/// Tracks whether an assistive technology is driving the interface.
///
/// VoiceOver, Switch Control, and AssistiveTouch produce tap and scroll patterns that look like
/// frustration, so touch-based signals are paused while any of them is running.
/// Voice Control has no public detection API, so people using it can turn adaptive offers off instead.
@Observable
final class AssistiveTechMonitor {
    private(set) var isVoiceOverRunning = false
    private(set) var isSwitchControlRunning = false
    private(set) var isAssistiveTouchRunning = false

    /// Lets the debug panel exercise the paused state on Simulator, where these features are unavailable.
    var simulateActive = false

    var isActive: Bool {
        simulateActive || isVoiceOverRunning || isSwitchControlRunning || isAssistiveTouchRunning
    }

    /// Names of the running technologies, for the debug panel.
    var activeNames: [String] {
        var names: [String] = []
        if isVoiceOverRunning { names.append("VoiceOver") }
        if isSwitchControlRunning { names.append("Switch Control") }
        if isAssistiveTouchRunning { names.append("AssistiveTouch") }
        if simulateActive { names.append("Simulated") }
        return names
    }

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        refresh()
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIAccessibility.voiceOverStatusDidChangeNotification,
            UIAccessibility.switchControlStatusDidChangeNotification,
            UIAccessibility.assistiveTouchStatusDidChangeNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    private func refresh() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
        isAssistiveTouchRunning = UIAccessibility.isAssistiveTouchRunning
    }
}
