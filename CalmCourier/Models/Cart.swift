//
//  Cart.swift
//  CalmCourier
//

import Foundation

nonisolated struct CartLine: Identifiable, Hashable, Sendable {
    let item: MenuItem
    var quantity: Int

    var id: String { item.id }
    var lineTotal: Decimal { item.price * Decimal(quantity) }
}

nonisolated struct Cart: Equatable, Sendable {
    private(set) var lines: [CartLine] = []
    var baseDeliveryFee: Decimal = OfferConfig.standard.baseDeliveryFee

    var isEmpty: Bool { lines.isEmpty }
    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }
    var subtotal: Decimal { lines.reduce(Decimal(0)) { $0 + $1.lineTotal } }

    func quantity(of item: MenuItem) -> Int {
        lines.first { $0.item.id == item.id }?.quantity ?? 0
    }

    mutating func add(_ item: MenuItem) {
        if let index = lines.firstIndex(where: { $0.item.id == item.id }) {
            lines[index].quantity += 1
        } else {
            lines.append(CartLine(item: item, quantity: 1))
        }
    }

    mutating func remove(_ item: MenuItem) {
        guard let index = lines.firstIndex(where: { $0.item.id == item.id }) else { return }
        lines[index].quantity -= 1
        if lines[index].quantity <= 0 {
            lines.remove(at: index)
        }
    }

    mutating func removeAll() {
        lines.removeAll()
    }
}
