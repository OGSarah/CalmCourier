# CalmCourier: Agitation-Aware Offers (Concept Model)

A local SwiftUI learning project that explores whether a food delivery app could detect signs of user frustration or urgency from interaction behavior and device context, and respond with better deals or lower delivery fees.

> ## ⚠️ Concept Only. Not for Release.
>
> This is a **concept model built for learning**. It is **not** intended to be released, distributed, submitted to the App Store, shared via TestFlight, or used with real customers, real orders, or real pricing. Inferring a person's emotional or situational state in order to adjust prices raises serious ethical, legal, and privacy questions that this project deliberately does not try to resolve.

---

## Table of Contents

1. [Concept](#concept)
2. [Goals and Non-Goals](#goals-and-non-goals)
3. [Design Principle](#design-principle)
4. [Requirements](#requirements)
5. [Architecture](#architecture)
6. [Signals](#signals)
7. [Scoring Model](#scoring-model)
8. [Offer Engine](#offer-engine)
9. [Project Structure](#project-structure)
10. [Implementation Notes](#implementation-notes)
11. [Debug Panel](#debug-panel)
12. [Testing](#testing)
13. [Demo Script](#demo-script)
14. [Ethics and Guardrails](#ethics-and-guardrails)
15. [Known Limitations](#known-limitations)

---

## Concept

Delivery apps lose customers at moments of friction: a slow-loading menu, a hard-to-find item, a checkout that keeps failing, a delivery fee that feels too high. The user rarely says anything. They just tap harder, scroll faster, and eventually leave.

This prototype passively watches interaction patterns, combines them with a little device context (battery level), and computes a rolling **agitation score** (0 to 100). That score maps to a tier of in-app offers: a reduced delivery fee, a flat discount, or a prompt to chat with support.

The battery idea: someone with a nearly dead phone may be in a hurry to finish an order before the device shuts off, so the same behavior may deserve a quicker response.

Nothing here reads emotion directly. The score is a behavioral heuristic, not a diagnosis.

## Goals and Non-Goals

**Goals**

- Learn on-device signal collection in SwiftUI (with minimal UIKit bridging)
- Learn how to read battery state and Low Power Mode
- Build a transparent, tunable scoring model
- Show a live offer change in the UI as the score moves
- Provide a debug panel so every decision is explainable
- Keep all data on-device and in memory

**Non-Goals**

- No backend, accounts, or payments
- No persistence of behavioral data between launches
- No machine learning (rule-based scoring only)
- No release, distribution, or App Store compliance work

## Design Principle

> **Agitation and urgency can only make the user's price better, never worse.**

The offer engine has a hard floor: the price a calm user with a full battery sees is the maximum any user sees. Agitation, low battery, or both can unlock discounts. They never unlock surcharges. This is enforced in code (see `OfferEngine`) and covered by a unit test. See [Ethics and Guardrails](#ethics-and-guardrails).

## Requirements

| Item | Requirement |
| --- | --- |
| OS target | iOS 27 |
| UI framework | SwiftUI |
| Language | Swift (current toolchain shipping with the iOS 27 SDK) |
| IDE | The Xcode release that includes the iOS 27 SDK |
| Devices | A physical iPhone is strongly recommended |

The simulator works for touch and scroll signals. Shake and motion signals need real hardware, and the simulator does not report a real battery level (it returns `-1`), so use the debug panel's battery override there.

**Dependencies:** none. First-party Apple frameworks only: `SwiftUI`, `UIKit` (touch capture and battery), `CoreMotion`, `Observation`.

**Note on iOS 27 APIs:** the code samples below rely on APIs that have existed since iOS 17/18 (`@Observable`, `onScrollGeometryChange`, `UIDevice` battery APIs). They are expected to carry forward, but check the iOS 27 release notes for any deprecations before building.

## Architecture

```
┌──────────────────┐
│ SignalCollector  │──┐
│ touch / scroll / │  │     ┌────────────────┐     ┌──────────────┐     ┌────────────┐
│ typing / motion  │  ├───► │ AgitationScorer│ ──► │ OfferEngine  │ ──► │  SwiftUI   │
└──────────────────┘  │     │ weights, decay,│     │ tier → deals │     │   views    │
┌──────────────────┐  │     │ baseline, tiers│     │ + fee rules  │     │            │
│ BatteryMonitor   │──┘     └────────────────┘     └──────────────┘     └────────────┘
│ level / charging │                ▲                                          │
│ low power mode   │                └────────── user interaction ◄─────────────┘
└──────────────────┘
```

Behavioral signals feed the scorer as **events**. Battery state feeds it as **context** that amplifies those events and adds a small capped baseline. `AgitationScorer` and `OfferEngine` have no UI dependencies, which keeps them easy to unit test.

## Signals

### Behavioral signals

| Signal | How it is detected | Default weight |
| --- | --- | --- |
| Rage tap | 4+ taps within 40 pt in 1 second | +15 |
| Dead tap | Tap on a non-interactive element | +4 |
| Rapid scroll reversal | 3+ direction changes in 2 seconds | +8 |
| High-velocity flick, no tap after | Velocity above personal baseline by 2x, no tap within 3 seconds | +5 |
| Backspace burst | 5+ deletions in 2 seconds | +6 |
| Checkout failure | Payment or promo error shown | +12 |
| Back-and-forth navigation | Same two screens swapped 3+ times in 10 seconds | +10 |
| Device shake | Accelerometer magnitude spike (CoreMotion) | +10 |

### Context signals (battery)

| Condition | Baseline points | Event multiplier |
| --- | --- | --- |
| Charging, full, or level unknown | 0 | 1.0x |
| Battery 20% or below, not charging | +10 | 1.25x |
| Battery 10% or below, not charging | +15 | 1.5x |
| Low Power Mode on | +5 | no change |

Baseline points from all battery conditions are **capped at 15**, which is below the Uneasy threshold (30). That means **a low battery alone can never change the offer tier**. It only makes the score more sensitive to behavior that is already happening.

All weights live in `Config/ScoringConfig.swift` so they can be tuned without touching logic.

## Scoring Model

- **Range:** 0 to 100, clamped
- **Behavioral events add points** per the table above, multiplied by the current battery multiplier
- **Exponential decay:** the behavioral score halves roughly every 20 seconds of calm
- **Battery baseline** is added on top of the decayed behavioral score and does not decay while the condition holds
- **Effective score** = `min(100, behavioralScore + batteryBaseline)`
- **Personal baseline:** for the first ~30 seconds of a session, the scorer records the user's normal tap rate and scroll velocity, and later signals are compared against that baseline
- **Hysteresis:** a tier change only applies after the effective score has stayed past a threshold for 3 seconds, which prevents offers from flickering

```swift
struct BatteryContext {
    let level: Float?        // nil if unknown (simulator reports -1)
    let isCharging: Bool
    let lowPowerMode: Bool

    var multiplier: Double {
        guard let level, !isCharging else { return 1.0 }
        if level <= 0.10 { return 1.5 }
        if level <= 0.20 { return 1.25 }
        return 1.0
    }

    var baseline: Double {
        var points = 0.0
        if let level, !isCharging {
            if level <= 0.10 { points += 15 }
            else if level <= 0.20 { points += 10 }
        }
        if lowPowerMode { points += 5 }
        return min(points, 15)   // hard cap: battery alone never reaches Uneasy
    }
}

struct AgitationScorer {
    private(set) var behavioralScore: Double = 0
    private var lastUpdate = Date()
    let halfLife: TimeInterval = 20

    func effectiveScore(battery: BatteryContext) -> Double {
        min(100, behavioralScore + battery.baseline)
    }

    mutating func add(_ event: SignalEvent, config: ScoringConfig, battery: BatteryContext) {
        decay(to: Date())
        behavioralScore = min(100, behavioralScore + config.weight(for: event) * battery.multiplier)
    }

    mutating func decay(to now: Date) {
        let dt = now.timeIntervalSince(lastUpdate)
        behavioralScore *= pow(0.5, dt / halfLife)
        lastUpdate = now
    }
}
```

## Offer Engine

| Tier | Effective score | Behavior |
| --- | --- | --- |
| Calm | 0 to 29 | Standard pricing, standard deals |
| Uneasy | 30 to 59 | Delivery fee reduced by 50% on current cart |
| Frustrated | 60 to 100 | Free delivery, flat discount on cart, and a "Need help?" support prompt |

All amounts are mock values defined in `Config/OfferConfig.swift`.

**Rules**

1. Offers can only reduce cost relative to the calm baseline (enforced by `precondition` and a unit test)
2. At most one agitation offer per session (cooldown), so deliberately rage-tapping or draining the battery for coupons is not rewarded repeatedly
3. Offers are shown with a neutral label such as "Here's a deal on us", never "We noticed you're upset" or "We noticed your battery is low"
4. A visible setting lets the user turn adaptive offers off entirely, which also stops battery monitoring

```swift
struct OfferEngine {
    func offer(for tier: AgitationTier, cart: Cart) -> PricedCart {
        let base = PricedCart(cart: cart, deliveryFee: cart.baseDeliveryFee, discount: 0)
        let result: PricedCart = switch tier {
        case .calm:       base
        case .uneasy:     base.withDeliveryFee(base.deliveryFee * 0.5)
        case .frustrated: base.withDeliveryFee(0).withDiscount(5.00)
        }
        precondition(result.total <= base.total, "Adaptive pricing must never exceed baseline")
        return result
    }
}
```

## Project Structure

```
CalmCourier/
├── App/
│   ├── CalmCourierApp.swift
│   └── AppEnvironment.swift         // wires collector, battery, scorer, engine
├── Signals/
│   ├── SignalCollector.swift        // @Observable, owns all detectors
│   ├── TouchCapture.swift           // window-level gesture recognizer
│   ├── ScrollDetector.swift
│   ├── TypingDetector.swift
│   ├── MotionDetector.swift         // CoreMotion shake
│   └── BatteryMonitor.swift         // level, charging, Low Power Mode
├── Scoring/
│   ├── SignalEvent.swift
│   ├── BatteryContext.swift
│   ├── AgitationScorer.swift
│   └── AgitationTier.swift
├── Offers/
│   ├── OfferEngine.swift
│   └── Models/                      // Cart, Restaurant, MenuItem (mock)
├── Views/
│   ├── RestaurantListView.swift
│   ├── MenuView.swift
│   ├── CartView.swift
│   ├── CheckoutView.swift
│   ├── OfferBanner.swift
│   └── DebugPanelView.swift
├── Config/
│   ├── ScoringConfig.swift
│   └── OfferConfig.swift
├── MockData/
│   └── restaurants.json
└── Tests/
    ├── AgitationScorerTests.swift
    ├── BatteryContextTests.swift
    ├── OfferEngineTests.swift
    └── ScenarioTests.swift
```

## Implementation Notes

### Battery monitoring

Battery monitoring must be switched on before `UIDevice` will report a level. Observe change notifications rather than polling.

```swift
@MainActor
@Observable
final class BatteryMonitor {
    private(set) var context = BatteryContext(level: nil, isCharging: false, lowPowerMode: false)
    var override: BatteryContext?        // set by the debug panel (simulator, demos)

    var current: BatteryContext { override ?? context }

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()

        let center = NotificationCenter.default
        center.addObserver(forName: UIDevice.batteryLevelDidChangeNotification,
                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        center.addObserver(forName: UIDevice.batteryStateDidChangeNotification,
                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        center.addObserver(forName: .NSProcessInfoPowerStateDidChange,
                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let device = UIDevice.current
        let level = device.batteryLevel            // -1 when unknown
        let state = device.batteryState
        context = BatteryContext(
            level: level >= 0 ? level : nil,
            isCharging: state == .charging || state == .full,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
```

Notes:

- `batteryLevel` is reported in coarse steps (roughly 5% increments), so it is a rough signal.
- Treat `-1` as "unknown", not "empty".
- Charging state matters: a low battery on a charger is not urgent.

### Global touch capture in SwiftUI

SwiftUI has no app-wide touch observer, so attach a passive gesture recognizer to the key window. It must not cancel or delay touches.

```swift
final class TouchCapture: NSObject, UIGestureRecognizerDelegate {
    var onTap: ((CGPoint, Bool) -> Void)?   // location, hitInteractiveElement

    func install(in window: UIWindow) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handle(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
    }

    @objc private func handle(_ g: UITapGestureRecognizer) {
        let point = g.location(in: g.view)
        let hit = g.view?.hitTest(point, with: nil)
        onTap?(point, hit is UIControl)
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
```

Dead-tap detection is approximate in SwiftUI because many tappable views are not `UIControl`s. For the prototype, tag interactive views with `.accessibilityIdentifier` or maintain a registry of tappable frames.

### Scroll velocity

```swift
ScrollView {
    // content
}
.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { old, new in
    collector.scrollDidChange(from: old, to: new, at: CACurrentMediaTime())
}
```

Use real timestamps rather than frame counts, since ProMotion displays refresh at variable rates. Smooth the velocity with an exponential moving average.

### Typing

Observe the text field with `.onChange(of:)` and track deletions by comparing string lengths between changes.

### Motion

```swift
let motion = CMMotionManager()
motion.accelerometerUpdateInterval = 1.0 / 30
motion.startAccelerometerUpdates(to: .main) { data, _ in
    guard let a = data?.acceleration else { return }
    let magnitude = sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
    if magnitude > 2.2 { collector.record(.shake) }
}
```

### State

Use `@Observable` for `SignalCollector`, `BatteryMonitor`, and `AppEnvironment`, and inject through `.environment(...)`. A `Timer` or `TimelineView` ticks the scorer once per second to apply decay.

## Debug Panel

Triple-tap the app title, or shake with the debug toggle on, to open `DebugPanelView`. It shows:

- Live effective score with a gauge and history sparkline, split into behavioral score and battery baseline
- Current tier and time until the next tier change is allowed
- Current battery context: level, charging state, Low Power Mode, and the resulting multiplier
- A log of recent signal events and their point contributions (after the battery multiplier)
- Sliders for each signal weight and for the half-life
- **Battery override controls:** a level slider, a charging toggle, and a Low Power Mode toggle, for simulator use and demos
- Buttons to inject synthetic events (rage tap, failed checkout, shake)
- Toggle: "Adaptive offers enabled"
- Reset session button (clears score, baseline, and offer cooldown)

The panel is the main way to tell whether a given offer was triggered by real behavior or by a bug.

## Testing

**Unit tests**

- Scorer adds the expected points per event
- Decay halves the behavioral score after one half-life
- Effective score never exceeds 100 or drops below 0
- Hysteresis prevents tier flicker
- `BatteryContext` returns the expected multiplier and baseline for each level, charging state, and Low Power Mode combination
- Battery baseline never exceeds 15, so battery alone never reaches the Uneasy tier
- Charging or unknown battery level produces no multiplier and no baseline
- `OfferEngine` total is never greater than baseline total for any tier, cart, score, or battery state (property-style test over many random inputs)
- Cooldown blocks a second agitation offer in the same session

**Scenario tests**

Feed recorded event sequences and battery states into the scorer and assert the final tier:

| Scenario | Battery | Expected tier |
| --- | --- | --- |
| Normal browsing, a few taps and scrolls | 80% | Calm |
| Normal browsing, a few taps and scrolls | 8%, unplugged | Calm (baseline alone stays below Uneasy) |
| Four taps on an unresponsive button | 80% | Calm or Uneasy, near the threshold |
| Same four taps on an unresponsive button | 8%, unplugged | Uneasy (amplified by multiplier and baseline) |
| Same four taps | 8%, charging | Same as the 80% case |
| Failed promo twice, rapid back-and-forth, rage taps | 80% | Frustrated |
| Fast scrolling that ends in an add-to-cart tap | 80% | Calm (flick followed by engagement) |

**Manual testing:** on a real device, deliberately behave "frustrated" and "calm" at different battery levels and compare the debug log against expectations.

## Demo Script

1. Launch the app with the debug battery override set to 80%. Browse two restaurants normally. The score stays near zero and the cart shows the standard $4.99 delivery fee.
2. Scroll up and down rapidly without tapping anything. The score climbs and the tier moves to Uneasy. The fee drops to $2.50 with a banner.
3. Reset the session. Set the battery override to 8%, unplugged, and repeat only a mild version of step 2. Note how the same behavior now reaches a higher score because of the multiplier and baseline, while idle browsing alone still stays Calm.
4. Toggle charging on and repeat. The battery effect disappears.
5. Go to checkout and trigger the mock payment failure twice, then tap repeatedly on the pay button. The tier moves to Frustrated, delivery becomes free, a discount appears, and a support prompt shows.
6. Stop interacting for 40 seconds. The behavioral score decays back toward Calm.
7. Open the debug panel and walk through the event log to show exactly why each change happened.

## Ethics and Guardrails

Adjusting prices from inferred emotional or situational state is sensitive, even in a learning project. These are built-in constraints, not afterthoughts:

- **Concept only.** This project must not be released, distributed, or used with real customers or real pricing.
- **Discounts only.** No code path may raise a price because of agitation, urgency, or battery level. A frustrated user or a user with 5% battery must never pay more than a calm user with a full battery.
- **No exploiting vulnerability.** A low battery is exactly the kind of context that could be abused to charge more to someone with less leverage. Using device state to raise prices is an area that has drawn public scrutiny, and this project deliberately goes the other direction. Do not extend it that way.
- **Battery is context, not a trigger.** The baseline is capped so battery alone never changes the offer tier.
- **Transparency.** The UI never claims to know how the user feels or reveals which signals were used, and a setting lets them disable adaptive offers.
- **On-device only.** Behavioral and battery signals stay in memory and are discarded when the app closes. Nothing is logged to disk or sent anywhere.
- **Proportionate use.** Where possible, the better response to frustration is fixing the cause (slow screens, broken buttons), so use this data to find those problems.

Any real-world version of this idea would need legal and policy review. Dynamic pricing based on behavioral and device inference can raise consumer protection, privacy (GDPR, CCPA), and App Store review questions.

## Known Limitations

- **Weak signals.** Fast scrolling can mean skimming, repeated taps can mean a laggy device, and low battery can mean nothing at all. False positives are expected.
- **Battery is a crude proxy for hurry.** Many people run low on battery routinely and are not rushed. Coarse level reporting and varying charging habits make it noisier still.
- **Gameable.** Users who learn the pattern can trigger offers on purpose. The cooldown mitigates this but does not solve it.
- **Heuristic weights.** The defaults are educated guesses, not tuned on real data.
- **Dead-tap accuracy.** SwiftUI hit testing is imprecise without a registry of interactive frames.
- **Simulator gaps.** No real motion or battery data, and touch timing differs from a device.
- **Accessibility.** Users of Switch Control, VoiceOver, or assistive input produce very different interaction patterns, and the scorer does not account for them.

## License

Released under the [MIT License](LICENSE). © 2026 SarahUniverse
