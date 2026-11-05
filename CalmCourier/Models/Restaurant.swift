//
//  Restaurant.swift
//  CalmCourier
//

import Foundation

nonisolated struct Restaurant: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let cuisine: String
    let etaMinutes: Int
    let symbolName: String
    let menu: [MenuItem]
}
