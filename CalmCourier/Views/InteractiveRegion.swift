//
//  InteractiveRegion.swift
//  CalmCourier
//

import SwiftUI

/// Registers a SwiftUI control's on-screen frame so taps on it aren't counted as dead taps.
/// Also sets the accessibility identifier used by UI tests.
private struct InteractiveRegion: ViewModifier {
    @Environment(AppEnvironment.self) private var environment
    let id: String

    func body(content: Content) -> some View {
        content
            .accessibilityIdentifier(id)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                environment.collector.registerInteractiveFrame(frame, id: id)
            }
            .onDisappear {
                environment.collector.unregisterInteractiveFrame(id: id)
            }
    }
}

extension View {
    func interactiveRegion(_ id: String) -> some View {
        modifier(InteractiveRegion(id: id))
    }
}
