//
//  CatalogLoader.swift
//  CalmCourier
//

import Foundation

nonisolated enum CatalogLoader {
    /// Loads the bundled mock restaurants, or an empty list if the file is missing or malformed.
    static func loadBundled(from bundle: Bundle = .main) -> [Restaurant] {
        guard let url = bundle.url(forResource: "restaurants", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let restaurants = try? JSONDecoder().decode([Restaurant].self, from: data)
        else {
            return []
        }
        return restaurants
    }
}
