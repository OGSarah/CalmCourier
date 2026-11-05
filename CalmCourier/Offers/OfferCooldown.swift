//
//  OfferCooldown.swift
//  CalmCourier
//

import Foundation

/// Allows at most one agitation offer per session.
///
/// An offer starts when the tier first rises above Calm. It can escalate (Uneasy to Frustrated)
/// but does not shrink until the tier returns to Calm. Once that happens the offer is spent,
/// and every later tier change gets standard pricing until the session is reset.
nonisolated struct OfferCooldown: Equatable, Sendable {
    private(set) var activeTier: AgitationTier?
    private(set) var isSpent = false

    /// Returns the tier to price the cart at, given the scorer's current tier.
    mutating func offerTier(for tier: AgitationTier) -> AgitationTier {
        if tier == .calm {
            if activeTier != nil {
                isSpent = true
                activeTier = nil
            }
            return .calm
        }
        guard !isSpent else { return .calm }
        let offered = max(activeTier ?? tier, tier)
        activeTier = offered
        return offered
    }

    mutating func reset() {
        activeTier = nil
        isSpent = false
    }
}
