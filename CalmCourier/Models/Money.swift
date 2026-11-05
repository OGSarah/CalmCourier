//
//  Money.swift
//  CalmCourier
//

import Foundation

nonisolated extension Decimal {
    /// Rounds half-up to whole cents, so $4.99 × 0.5 becomes $2.50.
    func roundedToCents() -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }

    /// Mock prices are always in US dollars.
    var currencyText: String {
        formatted(.currency(code: "USD"))
    }
}
