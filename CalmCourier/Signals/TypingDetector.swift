//
//  TypingDetector.swift
//  CalmCourier
//

import Foundation

/// Detects bursts of deletions by comparing string lengths between text changes.
nonisolated struct TypingDetector: Sendable {
    var burstCount = 5
    var burstWindow: TimeInterval = 2

    private var deletionTimes: [TimeInterval] = []

    mutating func record(old: String, new: String, at time: TimeInterval) -> [SignalEvent] {
        let deleted = max(0, old.count - new.count)
        deletionTimes.append(contentsOf: repeatElement(time, count: deleted))
        deletionTimes.removeAll { time - $0 > burstWindow }
        guard deletionTimes.count >= burstCount else { return [] }
        deletionTimes.removeAll()
        return [.backspaceBurst]
    }

    mutating func reset() {
        deletionTimes.removeAll()
    }
}
