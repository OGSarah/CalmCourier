//
//  AgitationTier.swift
//  CalmCourier
//

import Foundation

nonisolated enum AgitationTier: Int, Comparable, CaseIterable, Sendable {
    case calm
    case uneasy
    case frustrated

    init(score: Double, config: ScoringConfig) {
        if score >= config.frustratedThreshold {
            self = .frustrated
        } else if score >= config.uneasyThreshold {
            self = .uneasy
        } else {
            self = .calm
        }
    }

    static func < (lhs: AgitationTier, rhs: AgitationTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Developer-facing name. Customers never see tier names.
    var displayName: String {
        switch self {
        case .calm: "Calm"
        case .uneasy: "Uneasy"
        case .frustrated: "Frustrated"
        }
    }

    /// Paired with the name so the tier is never conveyed by color alone.
    var symbolName: String {
        switch self {
        case .calm: "leaf"
        case .uneasy: "exclamationmark.circle"
        case .frustrated: "exclamationmark.triangle"
        }
    }
}
