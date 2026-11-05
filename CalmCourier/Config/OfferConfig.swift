//
//  OfferConfig.swift
//  CalmCourier
//

import Foundation

/// Mock pricing values. Every offer can only lower the price.
nonisolated struct OfferConfig: Equatable, Sendable {
    var baseDeliveryFee: Decimal = Decimal(string: "4.99")!
    var uneasyDeliveryFeeMultiplier: Decimal = Decimal(string: "0.5")!
    var frustratedDiscount: Decimal = Decimal(string: "5.00")!

    /// Seconds an offer stays after it first appears, even if the score decays back to Calm sooner.
    var minimumOfferDuration: TimeInterval = 60

    /// Neutral wording. Never mention mood, battery, or which signals were used.
    var offerHeadline = "Here's a deal on us"

    static let standard = OfferConfig()
}
