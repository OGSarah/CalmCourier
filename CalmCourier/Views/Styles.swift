//
//  Styles.swift
//  CalmCourier
//

import SwiftUI

extension Color {
    /// Secondary text that keeps at least 4.5:1 contrast in light and dark mode.
    /// The system `.secondary` style is roughly 3.5:1 on white, below WCAG AA for body text.
    static let secondaryText = Color.primary.opacity(0.75)
}

/// Full-width prominent button with accessible contrast in both color schemes.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, minHeight: 44)
            // OnAccent is white in light mode and black in dark mode, because the dark-mode accent is light.
            .foregroundStyle(isEnabled ? Color(.onAccent) : Color.secondaryText)
            .background(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.systemGray5)),
                        in: .rect(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.rect)
    }
}

/// Lays children out horizontally, and vertically at accessibility sizes so text never truncates.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var spacing: CGFloat = 12
    /// Also stacks vertically at smaller sizes when the horizontal layout doesn't fit.
    /// Off by default: swapping layouts changes element identity, which the accessibility
    /// audit's Dynamic Type check can't follow, so use it only where values are long.
    var stacksWhenCramped = false
    @ViewBuilder var content: Content

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            vertical
        } else if stacksWhenCramped {
            ViewThatFits(in: .horizontal) {
                horizontal
                vertical
            }
        } else {
            horizontal
        }
    }

    private var horizontal: some View {
        HStack(alignment: .center, spacing: spacing) { content }
    }

    private var vertical: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `LabeledContent` with values in accessible secondary text, stacked vertically at accessibility sizes.
struct AccessibleLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        AdaptiveStack(spacing: 4, stacksWhenCramped: true) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
            configuration.content
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

extension LabeledContentStyle where Self == AccessibleLabeledContentStyle {
    static var accessible: AccessibleLabeledContentStyle { AccessibleLabeledContentStyle() }
}
