//
//  MenuItem.swift
//  CalmCourier
//

import Foundation

nonisolated struct MenuItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let details: String
    /// Stored in cents so JSON decoding never introduces floating-point error.
    let priceCents: Int
    let symbolName: String

    var price: Decimal { Decimal(priceCents) / 100 }
}
