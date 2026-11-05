//
//  ViewModelTests.swift
//  CalmCourierTests
//

import Foundation
import Testing
@testable import CalmCourier

@Suite("App environment and view models")
@MainActor
struct ViewModelTests {
    let harness = TestHarness()
    var environment: AppEnvironment { harness.environment }

    let uneasyEvents: [SignalEvent] = [.rageTap, .backAndForth, .checkoutFailure]
    let frustratedEvents: [SignalEvent] = [.rageTap, .rageTap, .rageTap, .checkoutFailure, .checkoutFailure, .backAndForth]

    // MARK: Lists and menus

    @Test("Restaurant rows have spoken labels")
    func restaurantRows() {
        let viewModel = RestaurantListViewModel(environment: environment)
        #expect(viewModel.rows.first?.accessibilityLabel == "Harbor Noodle House, Noodles, about 25 minutes")
        #expect(viewModel.cartAccessibilityLabel == "Cart, empty")
        viewModel.open(viewModel.rows[0])
        #expect(environment.path == [.menu(Fixtures.noodleHouse)])
    }

    @Test("Menu add and remove update quantities and labels")
    func menuQuantities() throws {
        let viewModel = MenuViewModel(environment: environment, restaurant: Fixtures.noodleHouse)
        let ramen = try #require(viewModel.rows.first)
        viewModel.add(ramen)
        viewModel.add(ramen)
        #expect(viewModel.rows.first?.quantity == 2)
        #expect(viewModel.rows.first?.accessibilityValue == "2 in cart")
        #expect(viewModel.rows.first?.addLabel == "Add Shoyu ramen to cart")
        viewModel.remove(ramen)
        #expect(environment.cart.itemCount == 1)
        #expect(RestaurantListViewModel(environment: environment).cartAccessibilityLabel == "Cart, 1 item")
    }

    // MARK: Cart pricing

    @Test("Calm cart shows standard pricing")
    func calmCart() {
        environment.add(Fixtures.ramen)
        let viewModel = CartViewModel(environment: environment)
        #expect(viewModel.subtotalText == Decimal(string: "14.50")!.currencyText)
        #expect(viewModel.deliveryFeeText == Decimal(string: "4.99")!.currencyText)
        #expect(viewModel.originalDeliveryFeeText == nil)
        #expect(viewModel.totalText == Decimal(string: "19.49")!.currencyText)
        #expect(viewModel.checkoutButtonAccessibilityLabel == "Go to checkout, total \(viewModel.totalText)")
        #expect(viewModel.offer == nil)
    }

    @Test("Uneasy offer halves the fee and speaks the old and new price")
    func uneasyCart() {
        environment.add(Fixtures.ramen)
        harness.drive(uneasyEvents)
        #expect(environment.offerTier == .uneasy)

        let viewModel = CartViewModel(environment: environment)
        let was = Decimal(string: "4.99")!.currencyText
        let now = Decimal(string: "2.50")!.currencyText
        #expect(viewModel.deliveryFeeAccessibilityLabel == "Delivery fee, was \(was), now \(now)")
        #expect(viewModel.offer?.headline == "Here's a deal on us")
        #expect(viewModel.offer?.showsSupportPrompt == false)
    }

    @Test("Frustrated offer gives free delivery, a discount, and a support prompt")
    func frustratedCart() {
        environment.add(Fixtures.ramen)
        harness.drive(frustratedEvents)
        #expect(environment.offerTier == .frustrated)

        let viewModel = CartViewModel(environment: environment)
        #expect(viewModel.deliveryFeeText == "Free")
        #expect(viewModel.discountText != nil)
        #expect(viewModel.offer?.showsSupportPrompt == true)
        viewModel.showSupport()
        #expect(viewModel.isSupportPresented)
    }

    @Test("A low battery alone never changes the tier")
    func batteryAloneStaysCalm() {
        environment.battery.override = BatteryContext(level: 0.02, isCharging: false, lowPowerMode: true)
        harness.tick(seconds: 60)
        #expect(environment.batteryBaseline == 15)
        #expect(environment.offerTier == .calm)
    }

    @Test("Only one agitation offer per session, held for the minimum duration")
    func cooldownThroughEnvironment() {
        harness.drive(uneasyEvents)
        #expect(environment.offerTier == .uneasy)
        // The score decays to Calm within seconds, but the offer stays for a minute.
        harness.tick(seconds: 30)
        #expect(environment.scorer.tier == .calm)
        #expect(environment.offerTier == .uneasy)
        #expect(DebugPanelViewModel(environment: environment).cooldownText.hasPrefix("Uneasy offer held"))
        harness.tick(seconds: 31)
        #expect(environment.offerTier == .calm)
        harness.drive(uneasyEvents)
        #expect(environment.scorer.tier == .uneasy)
        #expect(environment.offerTier == .calm)

        environment.resetSession()
        harness.drive(uneasyEvents)
        #expect(environment.offerTier == .uneasy)
    }

    @Test("Turning adaptive offers off resets pricing and ignores events")
    func optOut() {
        harness.drive(uneasyEvents)
        environment.adaptiveOffersEnabled = false
        #expect(environment.offerTier == .calm)
        harness.drive(frustratedEvents)
        #expect(environment.effectiveScore == 0)
        #expect(environment.offerTier == .calm)
    }

    // MARK: Checkout

    @Test("A failed payment records a checkout failure and announces the error")
    func paymentFailure() {
        environment.add(Fixtures.ramen)
        environment.paymentsFail = true
        let viewModel = CheckoutViewModel(environment: environment)
        viewModel.pay()
        viewModel.pay()
        #expect(viewModel.paymentError != nil)
        #expect(viewModel.announcement?.id == 2)
        #expect(environment.eventLog.filter { $0.event == .checkoutFailure }.count == 2)
        #expect(!environment.cart.isEmpty)
    }

    @Test("A successful payment empties the cart and confirms the total")
    func paymentSuccess() {
        environment.add(Fixtures.ramen)
        let viewModel = CheckoutViewModel(environment: environment)
        viewModel.pay()
        #expect(viewModel.isOrderPlaced)
        #expect(viewModel.confirmationMessage != nil)
        #expect(environment.cart.isEmpty)
        #expect(viewModel.canPay == false)
    }

    @Test("An unrecognized promo code is a checkout failure")
    func promoFailure() {
        let viewModel = CheckoutViewModel(environment: environment)
        viewModel.promoCode = "save20"
        viewModel.applyPromo()
        #expect(viewModel.promoError == "The code SAVE20 isn't recognized.")
        #expect(environment.eventLog.first?.event == .checkoutFailure)
    }

    @Test("Deleting a promo code quickly is a backspace burst")
    func promoBackspaceBurst() {
        let viewModel = CheckoutViewModel(environment: environment)
        viewModel.promoCode = "SAVE20NOW"
        for _ in 0..<5 {
            viewModel.promoCode = String(viewModel.promoCode.dropLast())
        }
        #expect(environment.eventLog.contains { $0.event == .backspaceBurst })
    }

    // MARK: Navigation and debug panel

    @Test("Bouncing between the list and a menu is back-and-forth navigation")
    func navigationBounce() {
        for _ in 0..<2 {
            environment.path = [.menu(Fixtures.noodleHouse)]
            environment.path = []
        }
        #expect(environment.eventLog.contains { $0.event == .backAndForth })
    }

    @Test("Debug injections appear in the log with their point contributions")
    func debugInjection() {
        environment.battery.override = Fixtures.lowBattery
        let viewModel = DebugPanelViewModel(environment: environment)
        viewModel.inject(.rageTap)
        #expect(viewModel.logRows.first?.name == "Rage tap")
        #expect(viewModel.logRows.first?.pointsText == "+" + 22.5.formatted(.number.precision(.fractionLength(1))))
        viewModel.reset()
        #expect(viewModel.logRows.isEmpty)
    }

    @Test("The debug battery override drives the battery context")
    func batteryOverride() {
        let viewModel = DebugPanelViewModel(environment: environment)
        viewModel.isOverrideEnabled = true
        viewModel.overrideLevel = 0.08
        #expect(environment.batteryContext.level == Float(0.08))
        #expect(environment.batteryContext.multiplier == 1.5)
        viewModel.overrideCharging = true
        #expect(environment.batteryContext.multiplier == 1)
        viewModel.isOverrideEnabled = false
        #expect(environment.batteryContext == .unknown)
    }

    @Test("The debug panel reports paused touch signals")
    func pausedTouchSignals() {
        let viewModel = DebugPanelViewModel(environment: environment)
        #expect(viewModel.touchSignalsText == "Touch signals active")
        viewModel.simulateAssistiveTech = true
        #expect(viewModel.touchSignalsText == "Touch signals paused (Simulated)")
        viewModel.inject(.rageTap)
        #expect(environment.eventLog.isEmpty)
    }

    @Test("Opening the debug panel pauses capture so its buttons aren't rage taps")
    func debugPanelPausesCapture() {
        environment.isDebugPanelPresented = true
        #expect(environment.collector.isPaused)
        DebugPanelViewModel(environment: environment).close()
        #expect(!environment.collector.isPaused)
    }
}
