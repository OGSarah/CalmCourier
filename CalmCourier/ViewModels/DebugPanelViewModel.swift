//
//  DebugPanelViewModel.swift
//  CalmCourier
//

import Foundation
import Observation

/// Exposes every input to the offer decision so any offer can be traced to the events behind it.
@Observable
final class DebugPanelViewModel {
    struct LogRow: Identifiable, Equatable {
        let id: UUID
        let name: String
        let pointsText: String
        let multiplierText: String
        let timeText: String
        var accessibilityLabel: String { "\(name), \(pointsText) points, multiplier \(multiplierText), at \(timeText)" }
    }

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        let existing = environment.battery.override
        overrideLevel = Double(existing?.level ?? 0.8)
        overrideCharging = existing?.isCharging ?? false
        overrideLowPower = existing?.lowPowerMode ?? false
    }

    // MARK: Score

    var score: Double { environment.effectiveScore }
    var scoreText: String { Self.format(score) }
    var behavioralScoreText: String { Self.format(environment.scorer.behavioralScore) }
    var batteryBaselineText: String { Self.format(environment.batteryBaseline) }
    var scoreHistory: [AppEnvironment.ScoreSample] { environment.scoreHistory }

    var scorerTier: AgitationTier { environment.scorer.tier }
    var offerTier: AgitationTier { environment.offerTier }

    var pendingTierText: String {
        guard let pending = environment.scorer.pendingTier,
              let remaining = environment.timeUntilTierChange else {
            return "No change pending"
        }
        return "\(pending.displayName) in \(Int(remaining.rounded(.up))) s"
    }

    var cooldownText: String {
        if environment.cooldown.isSpent { return "Offer used this session" }
        if let tier = environment.cooldown.activeTier { return "\(tier.displayName) offer active" }
        return "Offer available"
    }

    var touchSignalsText: String {
        let names = environment.assistiveTech.activeNames
        guard !names.isEmpty else { return "Touch signals active" }
        return "Touch signals paused (\(names.joined(separator: ", ")))"
    }

    var droppedTouchEventsText: String { "\(environment.collector.droppedTouchEventCount) dropped" }

    // MARK: Battery

    var batteryLevelText: String {
        guard let level = environment.batteryContext.level else { return "Unknown" }
        return level.formatted(.percent.precision(.fractionLength(0)))
    }

    var chargingText: String { environment.batteryContext.isCharging ? "Charging" : "Not charging" }
    var lowPowerText: String { environment.batteryContext.lowPowerMode ? "On" : "Off" }
    var multiplierText: String { "×" + environment.batteryContext.multiplier.formatted(.number.precision(.fractionLength(2))) }

    var isOverrideEnabled: Bool {
        get { environment.battery.override != nil }
        set { environment.battery.override = newValue ? overrideContext : nil }
    }

    var overrideLevel: Double { didSet { pushOverride() } }
    var overrideCharging: Bool { didSet { pushOverride() } }
    var overrideLowPower: Bool { didSet { pushOverride() } }

    var overrideLevelText: String { overrideLevel.formatted(.percent.precision(.fractionLength(0))) }

    // MARK: Log

    var logRows: [LogRow] {
        environment.eventLog.map { entry in
            LogRow(
                id: entry.id,
                name: entry.event.displayName,
                pointsText: "+" + Self.format(entry.points),
                multiplierText: "×" + entry.multiplier.formatted(.number.precision(.fractionLength(2))),
                timeText: entry.date.formatted(date: .omitted, time: .standard)
            )
        }
    }

    // MARK: Tuning

    let tunableEvents = SignalEvent.allCases

    func weight(for event: SignalEvent) -> Double {
        environment.scoringConfig.weight(for: event)
    }

    func setWeight(_ value: Double, for event: SignalEvent) {
        environment.scoringConfig.weights[event] = value.rounded()
    }

    var halfLife: Double {
        get { environment.scoringConfig.halfLife }
        set { environment.scoringConfig.halfLife = newValue.rounded() }
    }

    // MARK: Toggles

    var adaptiveOffersEnabled: Bool {
        get { environment.adaptiveOffersEnabled }
        set { environment.adaptiveOffersEnabled = newValue }
    }

    var shakeOpensPanel: Bool {
        get { environment.shakeOpensDebugPanel }
        set { environment.shakeOpensDebugPanel = newValue }
    }

    var paymentsFail: Bool {
        get { environment.paymentsFail }
        set { environment.paymentsFail = newValue }
    }

    var simulateAssistiveTech: Bool {
        get { environment.assistiveTech.simulateActive }
        set { environment.assistiveTech.simulateActive = newValue }
    }

    // MARK: Actions

    /// The events the README calls out for injection.
    let injectableEvents: [SignalEvent] = [.rageTap, .checkoutFailure, .shake]

    func inject(_ event: SignalEvent) {
        environment.collector.inject(event)
    }

    func reset() {
        environment.resetSession()
    }

    func close() {
        environment.isDebugPanelPresented = false
    }

    // MARK: Private

    private var overrideContext: BatteryContext {
        BatteryContext(level: Float(overrideLevel), isCharging: overrideCharging, lowPowerMode: overrideLowPower)
    }

    private func pushOverride() {
        if isOverrideEnabled {
            environment.battery.override = overrideContext
        }
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}
