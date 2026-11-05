//
//  AppEnvironment.swift
//  CalmCourier
//

import Foundation
import Observation
import UIKit

/// Wires the signal collector, battery monitor, scorer, and offer engine together,
/// and ticks the scorer once per second. Shared by every view model.
@Observable
final class AppEnvironment {
    struct LoggedEvent: Identifiable, Equatable {
        let id = UUID()
        let event: SignalEvent
        let points: Double
        let multiplier: Double
        let date: Date
    }

    struct ScoreSample: Identifiable, Equatable {
        let id: Int
        let score: Double
    }

    enum OrderResult: Equatable {
        case placed(total: Decimal)
        case paymentFailed
    }

    let restaurants: [Restaurant]
    let battery: BatteryMonitor
    let assistiveTech: AssistiveTechMonitor
    let collector: SignalCollector
    let offerEngine = OfferEngine()

    var cart = Cart()

    var path: [AppRoute] = [] {
        didSet { collector.screenDidAppear(path.last?.screenName ?? "restaurants") }
    }

    var isDebugPanelPresented = false {
        didSet { collector.isPaused = isDebugPanelPresented }
    }

    /// The visible opt-out. Turning it off also stops battery and motion monitoring.
    var adaptiveOffersEnabled = true {
        didSet { applyAdaptiveSetting() }
    }

    /// When on, shaking the device opens the debug panel instead of counting as a signal.
    var shakeOpensDebugPanel = false {
        didSet { updateMotion() }
    }

    /// Debug control: makes the mock payment fail so checkout failures can be demonstrated.
    var paymentsFail = false

    private(set) var scorer: AgitationScorer
    private(set) var cooldown = OfferCooldown()
    /// The tier the cart is actually priced at, after the cooldown is applied.
    private(set) var offerTier: AgitationTier = .calm
    private(set) var eventLog: [LoggedEvent] = []
    private(set) var scoreHistory: [ScoreSample] = []

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let monitorsDevice: Bool
    @ObservationIgnored private let motion = MotionDetector()
    @ObservationIgnored private let touchCapture = TouchCapture()
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var sampleCounter = 0

    static let maxLoggedEvents = 50
    static let maxScoreSamples = 60

    /// - Parameter monitorsDevice: false in tests and previews, so no battery, motion, or timers start.
    init(restaurants: [Restaurant],
         now: @escaping () -> Date = { .now },
         monitorsDevice: Bool = true) {
        self.restaurants = restaurants
        self.now = now
        self.monitorsDevice = monitorsDevice
        self.scorer = AgitationScorer(now: now())
        self.battery = BatteryMonitor()
        self.assistiveTech = AssistiveTechMonitor()
        self.collector = SignalCollector(assistiveTech: assistiveTech, now: now)

        collector.onEvent = { [weak self] event in self?.record(event) }
        touchCapture.onTap = { [weak self] point, hitSystemControl in
            self?.collector.handleTap(at: point, hitSystemControl: hitSystemControl)
        }
        motion.onShake = { [weak self] in self?.handleShake() }
        collector.screenDidAppear("restaurants")
    }

    static func live() -> AppEnvironment {
        AppEnvironment(restaurants: CatalogLoader.loadBundled())
    }

    // MARK: Derived state

    /// Battery context as the scorer sees it. Unknown when adaptive offers are off.
    var batteryContext: BatteryContext {
        adaptiveOffersEnabled ? battery.current : .unknown
    }

    var effectiveScore: Double { scorer.effectiveScore(battery: batteryContext) }
    var batteryBaseline: Double { batteryContext.baseline(cap: scorer.config.batteryBaselineCap) }
    var basePricedCart: PricedCart { offerEngine.baseline(for: cart) }
    var pricedCart: PricedCart { offerEngine.offer(for: offerTier, cart: cart) }
    var timeUntilTierChange: TimeInterval? { scorer.timeUntilTierChange(now: now()) }

    var scoringConfig: ScoringConfig {
        get { scorer.config }
        set { scorer.config = newValue }
    }

    // MARK: Lifecycle

    func start() {
        guard monitorsDevice, tickTask == nil else { return }
        assistiveTech.start()
        applyAdaptiveSetting()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    func installTouchCapture(in window: UIWindow) {
        guard monitorsDevice else { return }
        touchCapture.install(in: window)
    }

    /// Decays the score, applies hysteresis and the cooldown, and resolves pending detections.
    func tick() {
        collector.tick()
        scorer.updateTier(battery: batteryContext, now: now())
        offerTier = adaptiveOffersEnabled ? cooldown.offerTier(for: scorer.tier) : .calm

        sampleCounter += 1
        scoreHistory.append(ScoreSample(id: sampleCounter, score: effectiveScore))
        if scoreHistory.count > Self.maxScoreSamples {
            scoreHistory.removeFirst(scoreHistory.count - Self.maxScoreSamples)
        }
    }

    // MARK: Signals

    func record(_ event: SignalEvent) {
        guard adaptiveOffersEnabled else { return }
        let context = batteryContext
        let points = scorer.add(event, battery: context, now: now())
        eventLog.insert(LoggedEvent(event: event, points: points, multiplier: context.multiplier, date: now()), at: 0)
        if eventLog.count > Self.maxLoggedEvents {
            eventLog.removeLast(eventLog.count - Self.maxLoggedEvents)
        }
    }

    /// Clears the score, the learned scroll baseline, the event log, and the offer cooldown.
    func resetSession() {
        scorer.reset(now: now())
        cooldown.reset()
        offerTier = .calm
        collector.reset()
        eventLog.removeAll()
        scoreHistory.removeAll()
    }

    // MARK: Cart and checkout

    func add(_ item: MenuItem) {
        cart.add(item)
    }

    func remove(_ item: MenuItem) {
        cart.remove(item)
    }

    func placeOrder() -> OrderResult {
        if paymentsFail {
            collector.recordCheckoutFailure()
            return .paymentFailed
        }
        let total = pricedCart.total
        cart.removeAll()
        return .placed(total: total)
    }

    // MARK: Private

    private func handleShake() {
        if shakeOpensDebugPanel {
            isDebugPanelPresented = true
        } else {
            collector.recordShake()
        }
    }

    private func applyAdaptiveSetting() {
        if adaptiveOffersEnabled {
            if monitorsDevice { battery.start() }
        } else {
            battery.stop()
            scorer.reset(now: now())
            offerTier = .calm
        }
        updateMotion()
    }

    private func updateMotion() {
        guard monitorsDevice else { return }
        if adaptiveOffersEnabled || shakeOpensDebugPanel {
            motion.start()
        } else {
            motion.stop()
        }
    }
}
