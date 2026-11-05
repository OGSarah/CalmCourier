//
//  TestSupport.swift
//  CalmCourierTests
//

import Foundation
@testable import CalmCourier

/// Deterministic random numbers so property-style tests are reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum Fixtures {
    static let ramen = MenuItem(id: "ramen", name: "Shoyu ramen", details: "Soy broth", priceCents: 1450, symbolName: "fork.knife")
    static let dumplings = MenuItem(id: "dumplings", name: "Pork dumplings", details: "Six pieces", priceCents: 900, symbolName: "fork.knife")
    static let tea = MenuItem(id: "tea", name: "Iced tea", details: "Jasmine", priceCents: 400, symbolName: "cup.and.saucer")

    static let noodleHouse = Restaurant(id: "noodles", name: "Harbor Noodle House", cuisine: "Noodles",
                                        etaMinutes: 25, symbolName: "fork.knife", menu: [ramen, dumplings, tea])
    static let pizza = Restaurant(id: "pizza", name: "Little Oven Pizza", cuisine: "Pizza",
                                  etaMinutes: 30, symbolName: "flame", menu: [tea])

    static let fullBattery = BatteryContext(level: 0.8, isCharging: false, lowPowerMode: false)
    static let lowBattery = BatteryContext(level: 0.08, isCharging: false, lowPowerMode: false)
    static let lowBatteryCharging = BatteryContext(level: 0.08, isCharging: true, lowPowerMode: false)

    static func cart(_ items: MenuItem...) -> Cart {
        var cart = Cart()
        items.forEach { cart.add($0) }
        return cart
    }

    static func randomCart(using generator: inout SplitMix64) -> Cart {
        var cart = Cart()
        let menu = [ramen, dumplings, tea]
        for _ in 0..<Int.random(in: 0...6, using: &generator) {
            cart.add(menu.randomElement(using: &generator)!)
        }
        return cart
    }
}

/// An `AppEnvironment` on a manual clock with no device monitoring.
@MainActor
struct TestHarness {
    let clock = ManualClock()
    let environment: AppEnvironment

    init(restaurants: [Restaurant] = [Fixtures.noodleHouse, Fixtures.pizza]) {
        let clock = self.clock
        environment = AppEnvironment(restaurants: restaurants, now: { clock.now }, monitorsDevice: false)
    }

    /// Advances time one second per tick, the same cadence the app uses.
    func tick(seconds: Int = 1) {
        for _ in 0..<seconds {
            clock.advance(by: 1)
            environment.tick()
        }
    }

    /// Injects events and ticks past the hysteresis window.
    func drive(_ events: [SignalEvent]) {
        events.forEach(environment.collector.inject)
        environment.tick()
        tick(seconds: Int(environment.scoringConfig.hysteresis))
    }
}
