//
//  OfferCooldown.swift
//  CalmCourier
//

import Foundation

/// Allows at most one agitation offer per session, and keeps it for a minimum time.
///
/// An offer starts when the tier first rises above Calm. It can escalate (Uneasy to Frustrated)
/// but does not shrink. It stays for at least `minimumDuration` after it appears or escalates, even if
/// the score decays back to Calm sooner, so a deal doesn't vanish while someone is still looking at it. Once the tier is Calm
/// and the minimum time has passed, the offer is spent, and every later tier change gets standard
/// pricing until the session is reset.
nonisolated struct OfferCooldown: Equatable, Sendable {
    var minimumDuration: TimeInterval
    private(set) var activeTier: AgitationTier?
    private(set) var activeSince: Date?
    private(set) var isSpent = false

    init(minimumDuration: TimeInterval = OfferConfig.standard.minimumOfferDuration) {
        self.minimumDuration = minimumDuration
    }

    /// Returns the tier to price the cart at, given the scorer's current tier.
    mutating func offerTier(for tier: AgitationTier, now: Date) -> AgitationTier {
        if tier == .calm {
            guard let activeTier, let activeSince else { return .calm }
            if now.timeIntervalSince(activeSince) < minimumDuration {
                return activeTier
            }
            isSpent = true
            self.activeTier = nil
            self.activeSince = nil
            return .calm
        }

        guard !isSpent else { return .calm }
        let offered = max(activeTier ?? tier, tier)
        // A new or escalated offer starts its own hold.
        if offered != activeTier {
            activeSince = now
        }
        activeTier = offered
        return offered
    }

    /// Seconds left before an active offer may end, or nil if no offer is active.
    func remainingHold(now: Date) -> TimeInterval? {
        guard let activeSince else { return nil }
        return max(0, minimumDuration - now.timeIntervalSince(activeSince))
    }

    mutating func reset() {
        activeTier = nil
        activeSince = nil
        isSpent = false
    }
}
