//
//  OfferPresentation.swift
//  CalmCourier
//

import Foundation

/// Customer-facing description of the current offer.
///
/// Copy stays neutral: it never mentions mood, battery, or the signals behind the offer.
nonisolated struct OfferPresentation: Equatable, Sendable {
    let headline: String
    let detail: String
    let showsSupportPrompt: Bool

    /// Spoken by VoiceOver when the offer appears.
    var announcement: String { "\(headline). \(detail)" }

    /// Returns nil when there is no offer to show.
    init?(tier: AgitationTier, priced: PricedCart, config: OfferConfig = .standard) {
        switch tier {
        case .calm:
            return nil
        case .uneasy:
            headline = config.offerHeadline
            detail = "Delivery fee now \(priced.deliveryFee.currencyText), was \(priced.baseDeliveryFee.currencyText)"
            showsSupportPrompt = false
        case .frustrated:
            headline = config.offerHeadline
            detail = "Free delivery and \(config.frustratedDiscount.currencyText) off your order"
            showsSupportPrompt = true
        }
    }
}
