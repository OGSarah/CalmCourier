//
//  DebugPanelView.swift
//  CalmCourier
//

import Charts
import SwiftUI

struct DebugPanelView: View {
    @State private var viewModel: DebugPanelViewModel

    init(viewModel: DebugPanelViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                scoreSection
                signalsSection
                batterySection
                injectSection
                logSection
                weightsSection
                settingsSection

                Section {
                    Button(role: .destructive) {
                        viewModel.reset()
                    } label: {
                        Label("Reset session", systemImage: "arrow.counterclockwise")
                            // Match the icon to the destructive text color.
                            .foregroundStyle(.red)
                    }
                    .accessibilityHint("Clears the score, learned baseline, event log, and offer cooldown")
                }
            }
            .labeledContentStyle(.accessible)
            .navigationTitle("Debug panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark", action: viewModel.close)
                        .accessibilityIdentifier("debug-done-button")
                }
            }
        }
    }

    // MARK: Sections

    private var scoreSection: some View {
        Section {
            Gauge(value: viewModel.score, in: 0...100) {
                Text("Effective score")
            } currentValueLabel: {
                Text(viewModel.scoreText)
            }
            .gaugeStyle(.linearCapacity)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .accessibilityValue("\(viewModel.scoreText) out of 100")

            LabeledContent("Behavioral", value: viewModel.behavioralScoreText)
            LabeledContent("Battery baseline", value: viewModel.batteryBaselineText)

            LabeledContent("Scorer tier") {
                TierValue(tier: viewModel.scorerTier)
            }
            LabeledContent("Priced at") {
                TierValue(tier: viewModel.offerTier)
            }
            LabeledContent("Next tier change", value: viewModel.pendingTierText)
            LabeledContent("Cooldown", value: viewModel.cooldownText)

            ScoreSparkline(samples: viewModel.scoreHistory)
        } header: {
            SectionHeader("Score")
        }
    }

    private var signalsSection: some View {
        Section {
            LabeledContent("Status", value: viewModel.touchSignalsText)
            LabeledContent("Touch events", value: viewModel.droppedTouchEventsText)
            Toggle("Simulate assistive technology", isOn: $viewModel.simulateAssistiveTech)
        } header: {
            SectionHeader("Signals")
        } footer: {
            Text("While VoiceOver, Switch Control, or AssistiveTouch is running, tap, scroll, and flick signals are ignored. Voice Control can't be detected, so its users can turn adaptive offers off instead.")
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var batterySection: some View {
        Section {
            Toggle("Override battery", isOn: $viewModel.isOverrideEnabled)
                .accessibilityIdentifier("battery-override-toggle")

            // Overridden values are edited in place; hardware values are shown read-only.
            if viewModel.isOverrideEnabled {
                VStack(alignment: .leading) {
                    Text("Battery level: \(viewModel.overrideLevelText)")
                    Slider(value: $viewModel.overrideLevel, in: 0...1, step: 0.01) {
                        Text("Battery level")
                    }
                    .accessibilityValue(viewModel.overrideLevelText)
                    .accessibilityIdentifier("battery-level-slider")
                }
                Toggle("Charging", isOn: $viewModel.overrideCharging)
                Toggle("Low Power Mode", isOn: $viewModel.overrideLowPower)
            } else {
                LabeledContent("Level", value: viewModel.batteryLevelText)
                LabeledContent("Charging", value: viewModel.chargingText)
                LabeledContent("Low Power Mode", value: viewModel.lowPowerText)
            }

            LabeledContent("Event multiplier", value: viewModel.multiplierText)
        } header: {
            SectionHeader("Battery")
        }
    }

    private var injectSection: some View {
        Section {
            ForEach(viewModel.injectableEvents) { event in
                Button("Inject \(event.displayName.lowercased())") {
                    viewModel.inject(event)
                }
                .accessibilityIdentifier("inject-\(event.rawValue)")
            }
        } header: {
            SectionHeader("Inject events")
        } footer: {
            Text("Injected events take the same path as real signals.")
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var logSection: some View {
        Section {
            if viewModel.logRows.isEmpty {
                Text("No events yet")
                    .foregroundStyle(Color.secondaryText)
            } else {
                ForEach(viewModel.logRows) { row in
                    AdaptiveStack(spacing: 4) {
                        VStack(alignment: .leading) {
                            Text(row.name)
                            Text(row.timeText)
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.pointsText) (\(row.multiplierText))")
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.accessibilityLabel)
                }
            }
        } header: {
            SectionHeader("Event log")
        }
    }

    private var weightsSection: some View {
        Section {
            ForEach(viewModel.tunableEvents) { event in
                let weight = Binding(
                    get: { viewModel.weight(for: event) },
                    set: { viewModel.setWeight($0, for: event) }
                )
                VStack(alignment: .leading) {
                    Text("\(event.displayName): \(Int(weight.wrappedValue))")
                    Slider(value: weight, in: 0...30, step: 1) {
                        Text(event.displayName)
                    }
                    .accessibilityValue("\(Int(weight.wrappedValue)) points")
                }
            }

            VStack(alignment: .leading) {
                Text("Half-life: \(Int(viewModel.halfLife)) s")
                Slider(value: $viewModel.halfLife, in: 5...60, step: 1) {
                    Text("Half-life")
                }
                .accessibilityValue("\(Int(viewModel.halfLife)) seconds")
            }
        } header: {
            SectionHeader("Weights")
        }
    }

    private var settingsSection: some View {
        Section {
            Toggle("Adaptive offers enabled", isOn: $viewModel.adaptiveOffersEnabled)
                .accessibilityIdentifier("adaptive-offers-toggle")
            Toggle("Shake opens this panel", isOn: $viewModel.shakeOpensPanel)
            Toggle("Mock payments fail", isOn: $viewModel.paymentsFail)
                .accessibilityIdentifier("payments-fail-toggle")
        } header: {
            SectionHeader("Settings")
        } footer: {
            Text("Turning adaptive offers off also stops battery monitoring.")
                .foregroundStyle(Color.secondaryText)
        }
    }
}

/// A section header in accessible secondary text.
private struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .foregroundStyle(Color.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The tier name with its symbol, so the tier is never conveyed by color alone.
private struct TierValue: View {
    let tier: AgitationTier

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tier.symbolName)
                .accessibilityHidden(true)
            Text(tier.displayName)
        }
    }
}

/// Score history for the last minute. Swift Charts provides an Audio Graph for VoiceOver.
private struct ScoreSparkline: View {
    let samples: [AppEnvironment.ScoreSample]
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 80

    var body: some View {
        Chart(samples) { sample in
            LineMark(x: .value("Second", sample.id), y: .value("Score", sample.score))
                .foregroundStyle(.tint)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .frame(height: height)
        .accessibilityLabel("Score history")
        .accessibilityValue(summary)
    }

    private var summary: String {
        guard let first = samples.first, let last = samples.last else { return "No samples yet" }
        return "Last \(samples.count) seconds, from \(Int(first.score)) to \(Int(last.score))"
    }
}

#Preview {
    DebugPanelView(viewModel: DebugPanelViewModel(environment: .preview(tier: .uneasy)))
}
