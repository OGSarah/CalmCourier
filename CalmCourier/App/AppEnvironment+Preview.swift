//
//  AppEnvironment+Preview.swift
//  CalmCourier
//

#if DEBUG
import Foundation

/// A clock that only moves when told to. Used by previews and tests.
final class ManualClock {
    var now: Date

    init(now: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now += seconds
    }
}

extension AppEnvironment {
    /// An environment with no device monitoring and a couple of items in the cart, for previews.
    static func preview(tier: AgitationTier = .calm) -> AppEnvironment {
        let clock = ManualClock()
        let environment = AppEnvironment(restaurants: CatalogLoader.loadBundled(),
                                         now: { clock.now },
                                         monitorsDevice: false)
        if let menu = environment.restaurants.first?.menu {
            menu.prefix(2).forEach(environment.add)
        }

        let events: [SignalEvent] = switch tier {
        case .calm: []
        case .uneasy: [.rageTap, .backAndForth, .checkoutFailure]
        case .frustrated: [.rageTap, .rageTap, .rageTap, .checkoutFailure, .checkoutFailure, .backAndForth]
        }
        events.forEach(environment.record)

        // Step past the hysteresis window so the offer shows immediately.
        environment.tick()
        clock.advance(by: environment.scoringConfig.hysteresis)
        environment.tick()
        return environment
    }
}
#endif
