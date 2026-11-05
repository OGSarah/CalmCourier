//
//  AppRootView.swift
//  CalmCourier
//

import SwiftUI

/// Hosts navigation, the debug panel sheet, touch capture, and offer announcements.
struct AppRootView: View {
    @Bindable var environment: AppEnvironment

    var body: some View {
        NavigationStack(path: $environment.path) {
            RestaurantListView(viewModel: RestaurantListViewModel(environment: environment))
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .menu(let restaurant):
                        MenuView(viewModel: MenuViewModel(environment: environment, restaurant: restaurant))
                    case .cart:
                        CartView(viewModel: CartViewModel(environment: environment))
                    case .checkout:
                        CheckoutView(viewModel: CheckoutViewModel(environment: environment))
                    }
                }
        }
        .sheet(isPresented: $environment.isDebugPanelPresented) {
            DebugPanelView(viewModel: DebugPanelViewModel(environment: environment))
        }
        .background {
            WindowReader { window in
                environment.installTouchCapture(in: window)
            }
            .accessibilityHidden(true)
        }
        // The banner appears without moving focus, so tell VoiceOver users about a new offer.
        .onChange(of: environment.offerTier) { _, tier in
            if let offer = OfferPresentation(tier: tier, priced: environment.pricedCart) {
                AccessibilityNotification.Announcement(offer.announcement).post()
            }
        }
        .environment(environment)
        .task {
            environment.start()
        }
    }
}

#Preview {
    AppRootView(environment: .preview())
}
