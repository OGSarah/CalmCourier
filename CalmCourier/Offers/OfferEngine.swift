//
//  OfferEngine.swift
//  CalmCourier
//

import Foundation

/// Maps a tier to a price. Discounts only: no path may exceed the calm baseline.
nonisolated struct OfferEngine: Sendable {
    var config: OfferConfig = .standard

    func baseline(for cart: Cart) -> PricedCart {
        PricedCart(cart: cart, deliveryFee: cart.baseDeliveryFee, discount: 0)
    }

    func offer(for tier: AgitationTier, cart: Cart) -> PricedCart {
        let base = baseline(for: cart)
        let result: PricedCart = switch tier {
        case .calm:
            base
        case .uneasy:
            base.withDeliveryFee(base.deliveryFee * config.uneasyDeliveryFeeMultiplier)
        case .frustrated:
            base.withDeliveryFee(0).withDiscount(config.frustratedDiscount)
        }
        precondition(result.total <= base.total, "Adaptive pricing must never exceed baseline")
        return result
    }
}
