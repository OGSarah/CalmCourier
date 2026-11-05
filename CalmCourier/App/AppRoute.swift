//
//  AppRoute.swift
//  CalmCourier
//

import Foundation

nonisolated enum AppRoute: Hashable, Sendable {
    case menu(Restaurant)
    case cart
    case checkout

    /// Stable name used by the back-and-forth navigation detector.
    var screenName: String {
        switch self {
        case .menu(let restaurant): "menu:\(restaurant.id)"
        case .cart: "cart"
        case .checkout: "checkout"
        }
    }
}
