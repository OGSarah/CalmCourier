//
//  CheckoutViewModel.swift
//  CalmCourier
//

import Foundation
import Observation

@Observable
final class CheckoutViewModel {
    /// A message for VoiceOver to speak. The id makes repeated identical messages distinct.
    struct Announcement: Equatable {
        let id: Int
        let message: String
    }

    private let environment: AppEnvironment

    /// Feeds the typing detector so backspace bursts are noticed.
    var promoCode = "" {
        didSet { environment.collector.textDidChange(from: oldValue, to: promoCode) }
    }

    private(set) var promoError: String?
    private(set) var paymentError: String?
    private(set) var confirmedTotal: Decimal?
    private(set) var announcement: Announcement?

    /// Shown after the "Need help?" prompt is tapped.
    var isSupportPresented = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var totalText: String { environment.pricedCart.total.currencyText }
    var canPay: Bool { !environment.cart.isEmpty && confirmedTotal == nil }
    var isOrderPlaced: Bool { confirmedTotal != nil }

    var payButtonTitle: String { "Pay \(totalText)" }

    var confirmationMessage: String? {
        confirmedTotal.map { "Order placed. You paid \($0.currencyText). This is a mock order and nothing will be delivered." }
    }

    var offer: OfferPresentation? {
        OfferPresentation(tier: environment.offerTier, priced: environment.pricedCart)
    }

    /// Mock promo codes are never valid, which gives the demo a promo failure to trigger.
    func applyPromo() {
        let code = promoCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            promoError = "Enter a promo code first."
            return
        }
        promoError = "The code \(code.uppercased()) isn't recognized."
        announce(promoError)
        environment.collector.recordCheckoutFailure()
    }

    func pay() {
        switch environment.placeOrder() {
        case .placed(let total):
            paymentError = nil
            confirmedTotal = total
            announce(confirmationMessage)
        case .paymentFailed:
            paymentError = "Payment didn't go through. Nothing was charged. Please try again."
            announce(paymentError)
        }
    }

    func showSupport() {
        isSupportPresented = true
    }

    func finish() {
        environment.path.removeAll()
    }

    private func announce(_ message: String?) {
        guard let message else { return }
        announcement = Announcement(id: (announcement?.id ?? 0) + 1, message: message)
    }
}
