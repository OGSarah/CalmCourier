//
//  MotionDetector.swift
//  CalmCourier
//

import CoreMotion
import Foundation

/// Decides when an accelerometer reading counts as a shake.
nonisolated struct ShakeDetector: Sendable {
    /// Acceleration magnitude, in g, above which a reading counts as a shake.
    var threshold: Double = 2.2
    /// One physical shake produces several spikes, so only the first in this window counts.
    var cooldown: TimeInterval = 1

    private var lastShakeTime: TimeInterval?

    mutating func record(magnitude: Double, at time: TimeInterval) -> Bool {
        guard magnitude > threshold else { return false }
        if let lastShakeTime, time - lastShakeTime < cooldown { return false }
        lastShakeTime = time
        return true
    }
}

/// Samples the accelerometer at 30 Hz and reports shakes. Needs a physical device.
final class MotionDetector {
    var onShake: (() -> Void)?

    private let manager = CMMotionManager()
    private var detector = ShakeDetector()

    var isRunning: Bool { manager.isAccelerometerActive }

    func start() {
        guard manager.isAccelerometerAvailable, !manager.isAccelerometerActive else { return }
        manager.accelerometerUpdateInterval = 1.0 / 30
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let acceleration = data?.acceleration else { return }
            let magnitude = sqrt(acceleration.x * acceleration.x
                                 + acceleration.y * acceleration.y
                                 + acceleration.z * acceleration.z)
            // Updates are delivered on the main queue.
            MainActor.assumeIsolated {
                self?.handle(magnitude: magnitude)
            }
        }
    }

    func stop() {
        manager.stopAccelerometerUpdates()
    }

    private func handle(magnitude: Double) {
        if detector.record(magnitude: magnitude, at: Date.now.timeIntervalSinceReferenceDate) {
            onShake?()
        }
    }
}
