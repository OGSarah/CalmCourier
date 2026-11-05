//
//  RestaurantListViewModel.swift
//  CalmCourier
//

import CoreGraphics
import Foundation
import Observation

@Observable
final class RestaurantListViewModel {
    struct Row: Identifiable, Equatable {
        let restaurant: Restaurant
        var id: String { restaurant.id }
        var name: String { restaurant.name }
        var cuisine: String { restaurant.cuisine }
        var symbolName: String { restaurant.symbolName }
        var etaText: String { "\(restaurant.etaMinutes) min" }
        var accessibilityLabel: String {
            "\(restaurant.name), \(restaurant.cuisine), about \(restaurant.etaMinutes) minutes"
        }
    }

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var title: String { "CalmCourier" }
    var navigationTitle: String { "Restaurants" }
    var rows: [Row] { environment.restaurants.map(Row.init) }
    var isCatalogEmpty: Bool { environment.restaurants.isEmpty }

    var offer: OfferPresentation? {
        OfferPresentation(tier: environment.offerTier, priced: environment.pricedCart)
    }

    var cartItemCount: Int { environment.cart.itemCount }

    var cartAccessibilityLabel: String {
        switch cartItemCount {
        case 0: "Cart, empty"
        case 1: "Cart, 1 item"
        default: "Cart, \(cartItemCount) items"
        }
    }

    func open(_ row: Row) {
        environment.path.append(.menu(row.restaurant))
    }

    func openCart() {
        environment.path.append(.cart)
    }

    func openDebugPanel() {
        environment.isDebugPanelPresented = true
    }

    func scrollDidChange(to offset: CGFloat) {
        environment.collector.scrollDidChange(to: offset)
    }
}
