//
//  SignalEvent.swift
//  CalmCourier
//

import Foundation

/// A discrete behavioral signal produced by one of the detectors.
nonisolated enum SignalEvent: String, CaseIterable, Hashable, Sendable, Identifiable {
    case rageTap
    case deadTap
    case scrollReversal
    case flick
    case backspaceBurst
    case checkoutFailure
    case backAndForth
    case shake

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rageTap: "Rage tap"
        case .deadTap: "Dead tap"
        case .scrollReversal: "Rapid scroll reversal"
        case .flick: "Flick, no tap after"
        case .backspaceBurst: "Backspace burst"
        case .checkoutFailure: "Checkout failure"
        case .backAndForth: "Back-and-forth navigation"
        case .shake: "Device shake"
        }
    }

    /// Touch-derived signals are unreliable while an assistive technology such as
    /// VoiceOver or Switch Control is driving the interface, so they are paused then.
    var isTouchBased: Bool {
        switch self {
        case .rageTap, .deadTap, .scrollReversal, .flick: true
        case .backspaceBurst, .checkoutFailure, .backAndForth, .shake: false
        }
    }
}
