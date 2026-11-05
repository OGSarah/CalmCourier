//
//  MenuView.swift
//  CalmCourier
//

import SwiftUI

struct MenuView: View {
    @State private var viewModel: MenuViewModel

    init(viewModel: MenuViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            if let offer = viewModel.offer {
                Section {
                    OfferBanner(offer: offer)
                }
            }

            Section {
                ForEach(viewModel.rows) { row in
                    MenuItemRow(row: row,
                                onAdd: { viewModel.add(row) },
                                onRemove: { viewModel.remove(row) })
                }
            } header: {
                Text(viewModel.subtitle)
                    .accessibilityLabel(viewModel.subtitleAccessibilityLabel)
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offset in
            viewModel.scrollDidChange(to: offset)
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasItemsInCart {
                Button(viewModel.viewCartTitle) {
                    viewModel.openCart()
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(viewModel.viewCartAccessibilityLabel)
                .accessibilityInputLabels(["View cart", "Cart"])
                .interactiveRegion("view-cart-button")
                .padding()
                .background(.bar)
            }
        }
        .navigationTitle(viewModel.title)
    }
}

private struct MenuItemRow: View {
    let row: MenuViewModel.Row
    let onAdd: () -> Void
    let onRemove: () -> Void

    @ScaledMetric(relativeTo: .title3) private var iconWidth: CGFloat = 32

    var body: some View {
        AdaptiveStack {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: row.symbolName)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.headline)
                    Text(row.details)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    Text(row.priceText)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)
            .accessibilityValue(row.accessibilityValue)

            QuantityControl(quantity: row.quantity,
                            addLabel: row.addLabel,
                            removeLabel: row.removeLabel,
                            itemName: row.name,
                            idPrefix: row.id,
                            onAdd: onAdd,
                            onRemove: onRemove)
        }
        .padding(.vertical, 4)
    }
}

/// Add and remove buttons with 44 pt targets and explicit labels for VoiceOver and Voice Control.
struct QuantityControl: View {
    let quantity: Int
    let addLabel: String
    let removeLabel: String
    let itemName: String
    let idPrefix: String
    /// The cart already shows "×2" beside the item, so it hides the count here.
    var showsCount = true
    let onAdd: () -> Void
    let onRemove: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            if quantity > 0 {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(removeLabel)
                .accessibilityInputLabels(["Remove \(itemName)", "Remove"])
                .interactiveRegion("remove-\(idPrefix)")

                if showsCount {
                    Text(quantity, format: .number)
                        .font(.body.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 24)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .accessibilityHidden(true)
                }
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(addLabel)
            .accessibilityInputLabels(["Add \(itemName)", "Add"])
            .interactiveRegion("add-\(idPrefix)")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.tint)
    }
}

#Preview {
    let environment = AppEnvironment.preview()
    NavigationStack {
        MenuView(viewModel: MenuViewModel(environment: environment, restaurant: environment.restaurants[0]))
    }
    .environment(environment)
}
