//
//  OfferEngineTests.swift
//  CalmCourierTests
//

import Foundation
import Testing
@testable import CalmCourier

@Suite("Offer engine")
struct OfferEngineTests {
    let engine = OfferEngine()

    @Test("Calm is standard pricing")
    func calm() {
        let cart = Fixtures.cart(Fixtures.ramen)
        #expect(engine.offer(for: .calm, cart: cart) == engine.baseline(for: cart))
    }

    @Test("Uneasy halves the delivery fee, rounded to cents")
    func uneasy() {
        let priced = engine.offer(for: .uneasy, cart: Fixtures.cart(Fixtures.ramen))
        #expect(priced.deliveryFee == Decimal(string: "2.50"))
        #expect(priced.discount == 0)
    }

    @Test("Frustrated gives free delivery and a flat discount")
    func frustrated() {
        let priced = engine.offer(for: .frustrated, cart: Fixtures.cart(Fixtures.ramen))
        #expect(priced.deliveryFee == 0)
        #expect(priced.appliedDiscount == 5)
        #expect(priced.total == Decimal(string: "9.50"))
    }

    @Test("Discount never takes the subtotal below zero")
    func discountCappedBySubtotal() {
        let priced = engine.offer(for: .frustrated, cart: Fixtures.cart(Fixtures.tea))
        #expect(priced.appliedDiscount == 4)
        #expect(priced.total == 0)
    }

    @Test("Total never exceeds baseline for any tier, cart, score, or battery state")
    func neverAboveBaseline() {
        var generator = SplitMix64(seed: 2026)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        for _ in 0..<1_000 {
            let cart = Fixtures.randomCart(using: &generator)
            let battery = BatteryContext(
                level: Bool.random(using: &generator) ? Float.random(in: 0...1, using: &generator) : nil,
                isCharging: Bool.random(using: &generator),
                lowPowerMode: Bool.random(using: &generator)
            )
            var scorer = AgitationScorer(now: start)
            for _ in 0..<Int.random(in: 0...10, using: &generator) {
                scorer.add(SignalEvent.allCases.randomElement(using: &generator)!, battery: battery, now: start)
            }
            let tier = AgitationTier(score: scorer.effectiveScore(battery: battery), config: .standard)

            let base = engine.baseline(for: cart)
            let offered = engine.offer(for: tier, cart: cart)
            #expect(offered.total <= base.total)
            #expect(offered.total >= 0)
        }
    }

    let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test("Cooldown blocks a second agitation offer in the same session")
    func cooldownBlocksSecondOffer() {
        var cooldown = OfferCooldown(minimumDuration: 60)
        #expect(cooldown.offerTier(for: .uneasy, now: start) == .uneasy)
        #expect(cooldown.offerTier(for: .calm, now: start + 60) == .calm)
        #expect(cooldown.isSpent)
        #expect(cooldown.offerTier(for: .uneasy, now: start + 61) == .calm)
        #expect(cooldown.offerTier(for: .frustrated, now: start + 62) == .calm)
    }

    @Test("An offer is held for the minimum duration after the score returns to Calm")
    func cooldownMinimumDuration() {
        var cooldown = OfferCooldown(minimumDuration: 60)
        #expect(cooldown.offerTier(for: .uneasy, now: start) == .uneasy)
        #expect(cooldown.offerTier(for: .calm, now: start + 10) == .uneasy)
        #expect(cooldown.remainingHold(now: start + 10) == 50)
        #expect(!cooldown.isSpent)
        #expect(cooldown.offerTier(for: .calm, now: start + 59) == .uneasy)
        #expect(cooldown.offerTier(for: .calm, now: start + 60) == .calm)
        #expect(cooldown.isSpent)
    }

    @Test("An active offer can escalate, including during the hold, but does not shrink")
    func cooldownEscalation() {
        var cooldown = OfferCooldown(minimumDuration: 60)
        #expect(cooldown.offerTier(for: .uneasy, now: start) == .uneasy)
        #expect(cooldown.offerTier(for: .calm, now: start + 20) == .uneasy)
        #expect(cooldown.offerTier(for: .frustrated, now: start + 30) == .frustrated)
        #expect(cooldown.offerTier(for: .uneasy, now: start + 31) == .frustrated)
    }

    @Test("Escalating restarts the hold, so the bigger offer gets the full minimum duration")
    func escalationRestartsHold() {
        var cooldown = OfferCooldown(minimumDuration: 60)
        _ = cooldown.offerTier(for: .uneasy, now: start)
        _ = cooldown.offerTier(for: .frustrated, now: start + 50)
        #expect(cooldown.offerTier(for: .calm, now: start + 70) == .frustrated)
        #expect(cooldown.remainingHold(now: start + 70) == 40)
        #expect(cooldown.offerTier(for: .calm, now: start + 110) == .calm)
        #expect(cooldown.isSpent)
    }

    @Test("Resetting the cooldown allows a new offer")
    func cooldownReset() {
        var cooldown = OfferCooldown(minimumDuration: 60)
        _ = cooldown.offerTier(for: .uneasy, now: start)
        _ = cooldown.offerTier(for: .calm, now: start + 60)
        cooldown.reset()
        #expect(cooldown.offerTier(for: .uneasy, now: start + 61) == .uneasy)
    }

    @Test("Offer copy stays neutral")
    func neutralCopy() throws {
        for tier in [AgitationTier.uneasy, .frustrated] {
            let offer = try #require(OfferPresentation(tier: tier, priced: engine.offer(for: tier, cart: Fixtures.cart(Fixtures.ramen))))
            let text = offer.announcement.lowercased()
            for word in ["upset", "frustrat", "battery", "noticed", "angry", "hurry"] {
                #expect(!text.contains(word))
            }
        }
        #expect(OfferPresentation(tier: .calm, priced: engine.baseline(for: Cart())) == nil)
    }
}
