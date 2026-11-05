//
//  MenuViewModel.swift
//  CalmCourier
//

import CoreGraphics
import Foundation
import Observation

@Observable
final class MenuViewModel {
    struct Row: Identifiable, Equatable {
        let item: MenuItem
        let quantity: Int

        var id: String { item.id }
        var name: String { item.name }
        var details: String { item.details }
        var symbolName: String { item.symbolName }
        var priceText: String { item.price.currencyText }

        var accessibilityLabel: String { "\(item.name), \(item.price.currencyText)" }
        var accessibilityValue: String { quantity > 0 ? "\(quantity) in cart" : "" }
        var addLabel: String { "Add \(item.name) to cart" }
        var removeLabel: String { "Remove one \(item.name) from cart" }
    }

    let restaurant: Restaurant
    private let environment: AppEnvironment

    init(environment: AppEnvironment, restaurant: Restaurant) {
        self.environment = environment
        self.restaurant = restaurant
    }

    var title: String { restaurant.name }
    var subtitle: String { "\(restaurant.cuisine) · about \(restaurant.etaMinutes) minutes" }
    var subtitleAccessibilityLabel: String { "\(restaurant.cuisine), about \(restaurant.etaMinutes) minutes" }

    var rows: [Row] {
        restaurant.menu.map { Row(item: $0, quantity: environment.cart.quantity(of: $0)) }
    }

    var offer: OfferPresentation? {
        OfferPresentation(tier: environment.offerTier, priced: environment.pricedCart)
    }

    var hasItemsInCart: Bool { !environment.cart.isEmpty }

    var viewCartTitle: String {
        "View cart · \(environment.pricedCart.subtotal.currencyText)"
    }

    var viewCartAccessibilityLabel: String {
        let count = environment.cart.itemCount
        let items = count == 1 ? "1 item" : "\(count) items"
        return "View cart, \(items), subtotal \(environment.pricedCart.subtotal.currencyText)"
    }

    func add(_ row: Row) {
        environment.add(row.item)
    }

    func remove(_ row: Row) {
        environment.remove(row.item)
    }

    func openCart() {
        environment.path.append(.cart)
    }

    func scrollDidChange(to offset: CGFloat) {
        environment.collector.scrollDidChange(to: offset)
    }
}
