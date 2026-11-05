//
//  CartView.swift
//  CalmCourier
//

import SwiftUI

struct CartView: View {
    @State private var viewModel: CartViewModel

    init(viewModel: CartViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            if let offer = viewModel.offer {
                Section {
                    OfferBanner(offer: offer, onSupport: viewModel.showSupport)
                }
            }

            if !viewModel.isEmpty {
                Section {
                    ForEach(viewModel.lines) { line in
                        CartLineRow(line: line,
                                    onIncrease: { viewModel.increase(line) },
                                    onDecrease: { viewModel.decrease(line) })
                    }
                } header: {
                    Text("Items")
                        .foregroundStyle(Color.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    SummaryRow(title: "Subtotal", value: viewModel.subtotalText)

                    SummaryRow(title: "Delivery fee", value: viewModel.deliveryFeeText,
                               originalValue: viewModel.originalDeliveryFeeText)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(viewModel.deliveryFeeAccessibilityLabel)

                    if let discount = viewModel.discountText {
                        SummaryRow(title: "Discount", value: discount)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(viewModel.discountAccessibilityLabel)
                    }

                    SummaryRow(title: "Total", value: viewModel.totalText, isEmphasized: true)
                } header: {
                    Text("Summary")
                        .foregroundStyle(Color.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .overlay {
            if viewModel.isEmpty {
                ContentUnavailableView("Your cart is empty", systemImage: "cart",
                                       description: Text("Add something from a restaurant menu."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.isEmpty {
                Button(viewModel.checkoutButtonTitle) {
                    viewModel.checkout()
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(viewModel.checkoutButtonAccessibilityLabel)
                .accessibilityInputLabels(["Checkout", "Go to checkout"])
                .interactiveRegion("checkout-button")
                .padding()
                .background(.bar)
            }
        }
        .navigationTitle("Cart")
        .alert("Need help?", isPresented: $viewModel.isSupportPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Support chat is a mock in this concept app. In a real app this would connect you with a person.")
        }
    }
}

private struct CartLineRow: View {
    let line: CartViewModel.Line
    let onIncrease: () -> Void
    let onDecrease: () -> Void

    var body: some View {
        AdaptiveStack {
            AdaptiveStack(spacing: 8) {
                Text(line.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Text(line.quantityText)
                        .foregroundStyle(Color.secondaryText)
                    Text(line.totalText)
                }
                .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(line.accessibilityLabel)

            QuantityControl(quantity: line.line.quantity,
                            addLabel: line.increaseLabel,
                            removeLabel: line.decreaseLabel,
                            itemName: line.name,
                            idPrefix: "cart-\(line.id)",
                            showsCount: false,
                            onAdd: onIncrease,
                            onRemove: onDecrease)
        }
    }
}

/// A label and amount. The original amount, if any, is struck through visually;
/// callers provide a spoken label that says "was … now …".
struct SummaryRow: View {
    let title: String
    let value: String
    var originalValue: String?
    var isEmphasized = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Titles and amounts are short, so a fixed layout is enough: side by side,
        // stacked at accessibility sizes.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                if let originalValue {
                    Text(originalValue)
                        .strikethrough()
                        .foregroundStyle(Color.secondaryText)
                }
                Text(value)
                    .monospacedDigit()
            }
        }
        .font(isEmphasized ? .headline : .body)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Uneasy offer") {
    let environment = AppEnvironment.preview(tier: .uneasy)
    NavigationStack {
        CartView(viewModel: CartViewModel(environment: environment))
    }
    .environment(environment)
}

#Preview("Frustrated offer, accessibility size") {
    let environment = AppEnvironment.preview(tier: .frustrated)
    NavigationStack {
        CartView(viewModel: CartViewModel(environment: environment))
    }
    .environment(environment)
    .dynamicTypeSize(.accessibility3)
}

