//
//  CartViewModel.swift
//  CalmCourier
//

import Foundation
import Observation

@Observable
final class CartViewModel {
    struct Line: Identifiable, Equatable {
        let line: CartLine

        var id: String { line.id }
        var name: String { line.item.name }
        var quantityText: String { "×\(line.quantity)" }
        var totalText: String { line.lineTotal.currencyText }
        var accessibilityLabel: String { "\(line.item.name), quantity \(line.quantity), \(line.lineTotal.currencyText)" }
        var increaseLabel: String { "Add one \(line.item.name)" }
        var decreaseLabel: String { "Remove one \(line.item.name)" }
    }

    private let environment: AppEnvironment

    /// Shown after the "Need help?" prompt is tapped.
    var isSupportPresented = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var isEmpty: Bool { environment.cart.isEmpty }
    var lines: [Line] { environment.cart.lines.map(Line.init) }

    private var priced: PricedCart { environment.pricedCart }

    var offer: OfferPresentation? {
        OfferPresentation(tier: environment.offerTier, priced: priced)
    }

    var subtotalText: String { priced.subtotal.currencyText }

    var deliveryFeeText: String {
        priced.deliveryFee == 0 ? "Free" : priced.deliveryFee.currencyText
    }

    /// The struck-through original fee, only when the fee was reduced.
    var originalDeliveryFeeText: String? {
        priced.hasReducedDeliveryFee ? priced.baseDeliveryFee.currencyText : nil
    }

    /// Spoken in full, because a strike-through is visual only.
    var deliveryFeeAccessibilityLabel: String {
        if priced.hasReducedDeliveryFee {
            "Delivery fee, was \(priced.baseDeliveryFee.currencyText), now \(deliveryFeeText)"
        } else {
            "Delivery fee, \(deliveryFeeText)"
        }
    }

    var discountText: String? {
        priced.appliedDiscount > 0 ? "−\(priced.appliedDiscount.currencyText)" : nil
    }

    var discountAccessibilityLabel: String {
        "Discount, minus \(priced.appliedDiscount.currencyText)"
    }

    var totalText: String { priced.total.currencyText }

    var checkoutButtonTitle: String { "Go to checkout · \(totalText)" }
    var checkoutButtonAccessibilityLabel: String { "Go to checkout, total \(totalText)" }

    func increase(_ line: Line) {
        environment.add(line.line.item)
    }

    func decrease(_ line: Line) {
        environment.remove(line.line.item)
    }

    func checkout() {
        environment.path.append(.checkout)
    }

    func showSupport() {
        isSupportPresented = true
    }
}
