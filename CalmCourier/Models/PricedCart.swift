//
//  PricedCart.swift
//  CalmCourier
//

import Foundation

/// A cart with its fees and discounts resolved.
nonisolated struct PricedCart: Equatable, Sendable {
    let subtotal: Decimal
    let baseDeliveryFee: Decimal
    let deliveryFee: Decimal
    let discount: Decimal

    init(cart: Cart, deliveryFee: Decimal, discount: Decimal) {
        self.subtotal = cart.subtotal
        self.baseDeliveryFee = cart.baseDeliveryFee
        self.deliveryFee = deliveryFee
        self.discount = discount
    }

    private init(subtotal: Decimal, baseDeliveryFee: Decimal, deliveryFee: Decimal, discount: Decimal) {
        self.subtotal = subtotal
        self.baseDeliveryFee = baseDeliveryFee
        self.deliveryFee = deliveryFee
        self.discount = discount
    }

    /// A discount can never take the food subtotal below zero.
    var appliedDiscount: Decimal { min(discount, subtotal) }

    var total: Decimal { subtotal + deliveryFee - appliedDiscount }

    var hasReducedDeliveryFee: Bool { deliveryFee < baseDeliveryFee }

    func withDeliveryFee(_ fee: Decimal) -> PricedCart {
        PricedCart(subtotal: subtotal, baseDeliveryFee: baseDeliveryFee,
                   deliveryFee: max(0, fee).roundedToCents(), discount: discount)
    }

    func withDiscount(_ amount: Decimal) -> PricedCart {
        PricedCart(subtotal: subtotal, baseDeliveryFee: baseDeliveryFee,
                   deliveryFee: deliveryFee, discount: max(0, amount).roundedToCents())
    }
}
