//
//  BatteryMonitor.swift
//  CalmCourier
//

import Foundation
import Observation
import UIKit

/// Reads battery level, charging state, and Low Power Mode.
///
/// Simulator has no real battery, so the debug panel can replace the hardware with `override`.
@Observable
final class BatteryMonitor {
    private(set) var context: BatteryContext = .unknown
    private(set) var isMonitoring = false

    /// Set by the debug panel. Takes precedence over the hardware reading.
    var override: BatteryContext?

    var current: BatteryContext { override ?? context }

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()

        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIDevice.batteryLevelDidChangeNotification,
            UIDevice.batteryStateDidChangeNotification,
            .NSProcessInfoPowerStateDidChange,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    /// Stops monitoring entirely. Used when adaptive offers are turned off.
    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        UIDevice.current.isBatteryMonitoringEnabled = false
        context = .unknown
    }

    private func refresh() {
        let device = UIDevice.current
        // -1 means unknown, not empty. The level is reported in coarse ~5% steps.
        let level = device.batteryLevel
        let state = device.batteryState
        context = BatteryContext(
            level: level >= 0 ? level : nil,
            isCharging: state == .charging || state == .full,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
