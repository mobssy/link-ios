//
//  ScreenCentering.swift
//  TalkMVP
//

import SwiftUI

/// Keeps content centered when the screen's safe area is uneven left and right. iPhone Duo's
/// open screen in landscape puts the status bar in a strip down the right edge; content centered
/// in what is left then looks pushed to the left. Padding the other side by the same amount
/// centers it again and still keeps it clear of the strip.
///
/// Only the screen's own insets count. A split view's detail column also has a leading inset
/// as wide as the sidebar floating over it; balancing that would pull content out of the column.
enum ScreenCentering {
    /// The padding to add on each side so the screen's insets match the wider of the two.
    static func extraPadding(for screenInsets: EdgeInsets) -> (leading: CGFloat, trailing: CGFloat) {
        let side = max(screenInsets.leading, screenInsets.trailing)
        return (side - screenInsets.leading, side - screenInsets.trailing)
    }
}

extension EnvironmentValues {
    /// The window's safe area insets, read once at the root by `readsScreenSafeArea()`.
    @Entry var screenSafeArea = EdgeInsets()
}

private struct ScreenSafeAreaReader: ViewModifier {
    @State private var insets = EdgeInsets()

    func body(content: Content) -> some View {
        content
            .environment(\.screenSafeArea, insets)
            .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets = $0 }
    }
}

private struct ScreenCenteredModifier: ViewModifier {
    @Environment(\.screenSafeArea) private var screenInsets

    func body(content: Content) -> some View {
        let padding = ScreenCentering.extraPadding(for: screenInsets)
        content
            .padding(.leading, padding.leading)
            .padding(.trailing, padding.trailing)
    }
}

extension View {
    /// Publishes the window's safe area to `screenCentered()` below. Apply to the root view,
    /// which fills the window.
    func readsScreenSafeArea() -> some View {
        modifier(ScreenSafeAreaReader())
    }

    /// Centers the view as if the screen's safe area were even left and right; see
    /// `ScreenCentering`.
    func screenCentered() -> some View {
        modifier(ScreenCenteredModifier())
    }
}
