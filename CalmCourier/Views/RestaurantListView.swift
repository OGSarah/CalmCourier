//
//  RestaurantListView.swift
//  CalmCourier
//

import SwiftUI

struct RestaurantListView: View {
    @State private var viewModel: RestaurantListViewModel

    init(viewModel: RestaurantListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                if let offer = viewModel.offer {
                    OfferBanner(offer: offer)
                }
            } header: {
                // Triple-tapping the app title is a shortcut. The toolbar button is the accessible path.
                Text(viewModel.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
                    .onTapGesture(count: 3) {
                        viewModel.openDebugPanel()
                    }
            }

            Section {
                ForEach(viewModel.rows) { row in
                    Button {
                        viewModel.open(row)
                    } label: {
                        RestaurantRow(row: row)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel(row.accessibilityLabel)
                    .accessibilityHint("Opens the menu")
                    .accessibilityInputLabels([row.name])
                    .interactiveRegion("restaurant-\(row.id)")
                }
            } header: {
                Text("Restaurants near you")
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .overlay {
            if viewModel.isCatalogEmpty {
                ContentUnavailableView("No restaurants", systemImage: "fork.knife",
                                       description: Text("The mock catalog couldn't be loaded."))
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offset in
            viewModel.scrollDidChange(to: offset)
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Debug panel", systemImage: "ladybug") {
                    viewModel.openDebugPanel()
                }
                .accessibilityIdentifier("debug-panel-button")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.openCart()
                } label: {
                    Label("Cart", systemImage: "cart")
                }
                .badge(viewModel.cartItemCount)
                .accessibilityLabel(viewModel.cartAccessibilityLabel)
                .accessibilityInputLabels(["Cart"])
                .accessibilityIdentifier("cart-button")
            }
        }
    }
}

private struct RestaurantRow: View {
    let row: RestaurantListViewModel.Row
    @ScaledMetric(relativeTo: .title2) private var iconWidth: CGFloat = 36

    var body: some View {
        AdaptiveStack {
            Image(systemName: row.symbolName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: iconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.headline)
                Text(row.cuisine)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.etaText)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}

#Preview {
    let environment = AppEnvironment.preview(tier: .uneasy)
    NavigationStack {
        RestaurantListView(viewModel: RestaurantListViewModel(environment: environment))
    }
    .environment(environment)
}
