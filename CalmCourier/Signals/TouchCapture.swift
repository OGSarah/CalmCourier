//
//  TouchCapture.swift
//  CalmCourier
//

import SwiftUI
import UIKit

/// A passive tap recognizer on the key window. SwiftUI has no app-wide touch observer.
///
/// It never cancels or delays touches and recognizes alongside every other gesture,
/// so it cannot change how the app responds to input.
final class TouchCapture: NSObject, UIGestureRecognizerDelegate {
    /// Location in window coordinates, and whether a UIKit control (navigation bar button,
    /// text field, and so on) is under it. SwiftUI buttons are found through the frame registry instead.
    var onTap: ((CGPoint, Bool) -> Void)?

    private weak var installedWindow: UIWindow?
    private var recognizer: UITapGestureRecognizer?

    func install(in window: UIWindow) {
        guard installedWindow !== window else { return }
        if let recognizer { installedWindow?.removeGestureRecognizer(recognizer) }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handle(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
        window.addGestureRecognizer(tap)

        recognizer = tap
        installedWindow = window
    }

    @objc private func handle(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: recognizer.view)
        let hit = recognizer.view?.hitTest(point, with: nil)
        onTap?(point, Self.isSystemControl(hit))
    }

    private static func isSystemControl(_ view: UIView?) -> Bool {
        var current = view
        while let candidate = current {
            if candidate is UIControl || candidate is UINavigationBar || candidate is UIToolbar
                || candidate is UITabBar || candidate is UITextField || candidate is UITextView {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

/// Hands the hosting `UIWindow` to SwiftUI so `TouchCapture` can attach to it.
struct WindowReader: UIViewRepresentable {
    let onWindow: (UIWindow) -> Void

    func makeUIView(context: Context) -> WindowReaderView {
        let view = WindowReaderView()
        view.onWindow = onWindow
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: WindowReaderView, context: Context) {
        uiView.onWindow = onWindow
    }

    final class WindowReaderView: UIView {
        var onWindow: ((UIWindow) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { onWindow?(window) }
        }
    }
}
