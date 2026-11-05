//
//  CheckoutView.swift
//  CalmCourier
//

import SwiftUI

struct CheckoutView: View {
    @State private var viewModel: CheckoutViewModel
    @FocusState private var isPromoFieldFocused: Bool

    init(viewModel: CheckoutViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            if let offer = viewModel.offer, !viewModel.isOrderPlaced {
                Section {
                    OfferBanner(offer: offer, onSupport: viewModel.showSupport)
                }
            }

            if let confirmation = viewModel.confirmationMessage {
                Section {
                    Label {
                        Text(confirmation)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .accessibilityIdentifier("order-confirmation")

                    Button("Back to restaurants") {
                        viewModel.finish()
                    }
                    .interactiveRegion("finish-button")
                }
            } else {
                Section {
                    TextField("Promo code", text: $viewModel.promoCode,
                              prompt: Text("Promo code").foregroundStyle(Color.secondaryText))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($isPromoFieldFocused)
                        .onSubmit(viewModel.applyPromo)
                        .accessibilityIdentifier("promo-field")

                    Button("Apply code", action: viewModel.applyPromo)
                        .interactiveRegion("apply-promo-button")

                    if let promoError = viewModel.promoError {
                        ErrorText(message: promoError)
                            .accessibilityIdentifier("promo-error")
                    }
                } header: {
                    Text("Promo code")
                        .foregroundStyle(Color.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    LabeledContent("Card", value: "Mock card ending 4242")
                    LabeledContent("Total", value: viewModel.totalText)
                        .font(.headline)

                    if let paymentError = viewModel.paymentError {
                        ErrorText(message: paymentError)
                            .accessibilityIdentifier("payment-error")
                    }
                } header: {
                    Text("Payment")
                        .foregroundStyle(Color.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                } footer: {
                    Text("No real payment is taken. This is a concept app.")
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
        .labeledContentStyle(.accessible)
        .safeAreaInset(edge: .bottom) {
            if viewModel.canPay {
                Button(viewModel.payButtonTitle, action: viewModel.pay)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityInputLabels(["Pay"])
                    .interactiveRegion("pay-button")
                    .padding()
                    .background(.bar)
            }
        }
        .navigationTitle("Checkout")
        .navigationBarBackButtonHidden(viewModel.isOrderPlaced)
        // Errors and confirmations appear inline, so announce them for VoiceOver users too.
        .onChange(of: viewModel.announcement) { _, announcement in
            if let announcement { AccessibilityNotification.Announcement(announcement.message).post() }
        }
        .alert("Need help?", isPresented: $viewModel.isSupportPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Support chat is a mock in this concept app. In a real app this would connect you with a person.")
        }
    }
}

/// Error text that doesn't rely on color: an icon and plain-language message in primary text.
private struct ErrorText: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
        .accessibilityLabel("Error: \(message)")
    }
}

#Preview {
    let environment = AppEnvironment.preview(tier: .frustrated)
    NavigationStack {
        CheckoutView(viewModel: CheckoutViewModel(environment: environment))
    }
    .environment(environment)
}
