//
//  NavigationDetector.swift
//  CalmCourier
//

import Foundation

/// Detects someone bouncing between the same two screens.
nonisolated struct NavigationDetector: Sendable {
    var swapCount = 3
    var window: TimeInterval = 10

    private struct Transition: Sendable {
        let pair: Set<String>
        let time: TimeInterval
    }

    private var currentScreen: String?
    private var transitions: [Transition] = []

    mutating func record(screen: String, at time: TimeInterval) -> [SignalEvent] {
        defer { currentScreen = screen }
        guard let currentScreen, currentScreen != screen else { return [] }

        let pair: Set<String> = [currentScreen, screen]
        transitions.append(Transition(pair: pair, time: time))
        transitions.removeAll { time - $0.time > window }

        guard transitions.filter({ $0.pair == pair }).count >= swapCount else { return [] }
        transitions.removeAll()
        return [.backAndForth]
    }

    mutating func reset() {
        transitions.removeAll()
    }
}
