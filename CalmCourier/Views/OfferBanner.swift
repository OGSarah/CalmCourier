//
//  OfferBanner.swift
//  CalmCourier
//

import SwiftUI

/// Neutral offer banner. It never says why the offer appeared.
struct OfferBanner: View {
    let offer: OfferPresentation
    /// Shown as a "Need help?" button when the offer includes a support prompt.
    var onSupport: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.headline)
                        .font(.headline)
                    Text(offer.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("offer-banner")

            if offer.showsSupportPrompt, let onSupport {
                Button("Need help?", systemImage: "questionmark.bubble", action: onSupport)
                    .buttonStyle(PrimaryButtonStyle())
                    .interactiveRegion("support-button")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    List {
        OfferBanner(offer: OfferPresentation(tier: .uneasy, priced: environment.offerEngine.offer(for: .uneasy, cart: environment.cart))!)
        OfferBanner(offer: OfferPresentation(tier: .frustrated, priced: environment.offerEngine.offer(for: .frustrated, cart: environment.cart))!,
                    onSupport: {})
    }
    .environment(environment)
}
