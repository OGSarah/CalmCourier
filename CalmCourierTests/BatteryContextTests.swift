//
//  BatteryContextTests.swift
//  CalmCourierTests
//

import Foundation
import Testing
@testable import CalmCourier

@Suite("Battery context")
struct BatteryContextTests {
    static let levels: [Float?] = [nil, 0, 0.05, 0.10, 0.11, 0.15, 0.20, 0.21, 0.5, 1]

    @Test("Multiplier by level while unplugged", arguments: [
        (Float?.none, 1.0), (0.05, 1.5), (0.10, 1.5), (0.15, 1.25), (0.20, 1.25), (0.21, 1.0), (0.8, 1.0),
    ] as [(Float?, Double)])
    func multiplier(level: Float?, expected: Double) {
        let context = BatteryContext(level: level, isCharging: false, lowPowerMode: false)
        #expect(context.multiplier == expected)
    }

    @Test("Baseline by level while unplugged", arguments: [
        (Float?.none, 0.0), (0.05, 15.0), (0.10, 15.0), (0.15, 10.0), (0.20, 10.0), (0.21, 0.0),
    ] as [(Float?, Double)])
    func baseline(level: Float?, expected: Double) {
        let context = BatteryContext(level: level, isCharging: false, lowPowerMode: false)
        #expect(context.baseline() == expected)
    }

    @Test("Low Power Mode adds 5 baseline points but no multiplier")
    func lowPowerMode() {
        let context = BatteryContext(level: 0.8, isCharging: false, lowPowerMode: true)
        #expect(context.baseline() == 5)
        #expect(context.multiplier == 1)
    }

    @Test("Baseline never exceeds 15 for any combination", arguments: levels, [false, true])
    func baselineCap(level: Float?, isCharging: Bool) {
        for lowPower in [false, true] {
            let context = BatteryContext(level: level, isCharging: isCharging, lowPowerMode: lowPower)
            #expect(context.baseline() <= 15)
            #expect(context.baseline() < ScoringConfig.standard.uneasyThreshold)
        }
    }

    @Test("Charging or an unknown level contributes nothing", arguments: levels)
    func chargingContributesNothing(level: Float?) {
        let charging = BatteryContext(level: level, isCharging: true, lowPowerMode: false)
        #expect(charging.baseline() == 0)
        #expect(charging.multiplier == 1)

        let unknown = BatteryContext(level: nil, isCharging: false, lowPowerMode: false)
        #expect(unknown.baseline() == 0)
        #expect(unknown.multiplier == 1)
    }
}
