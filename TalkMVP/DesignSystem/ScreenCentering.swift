//
//  ScreenCentering.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI

/// Keeps content centered when the screen's safe area is uneven left and right. iPhone Duo's
/// open screen in landscape puts the status bar in a strip down the right edge; content centered
/// in what is left then looks pushed to the left. Padding the other side by the same amount
/// centers it again and still keeps it clear of the strip.
///
/// It only acts at regular width. iPhone Duo's folded screen has the same strip, but it is
/// narrow: matching the strip on the other side would cost the content a fifth of its width,
/// so compact layouts keep the safe area as it is, like the system's own lists.
///
/// Only the screen's own insets count, and only on the edges the view reaches. A split view's
/// detail column also has a leading inset as wide as the sidebar floating over it, and a sheet
/// in the middle of the screen reaches neither edge; balancing those would pull content off
/// center instead.
enum ScreenCentering {
    /// The screen's leading and trailing insets on the sides of `screen` that `view` reaches,
    /// zero elsewhere. Both frames are in global coordinates, which run left to right.
    static func screenInsets(
        _ insets: EdgeInsets,
        screen: CGRect,
        view: CGRect,
        layoutDirection: LayoutDirection
    ) -> EdgeInsets {
        let tolerance: CGFloat = 1
        let reachesLeft = view.minX <= screen.minX + tolerance
        let reachesRight = view.maxX >= screen.maxX - tolerance
        let reachesLeading = layoutDirection == .leftToRight ? reachesLeft : reachesRight
        let reachesTrailing = layoutDirection == .leftToRight ? reachesRight : reachesLeft
        return EdgeInsets(
            top: 0,
            leading: reachesLeading ? insets.leading : 0,
            bottom: 0,
            trailing: reachesTrailing ? insets.trailing : 0
        )
    }

    /// The padding to add on each side so the screen's insets match the wider of the two.
    static func extraPadding(for screenInsets: EdgeInsets) -> (leading: CGFloat, trailing: CGFloat) {
        let side = max(screenInsets.leading, screenInsets.trailing)
        return (side - screenInsets.leading, side - screenInsets.trailing)
    }
}

/// The window's safe area and frame, read once at the root by `readsScreenSafeArea()`.
nonisolated struct ScreenSafeArea: Equatable {
    var insets = EdgeInsets()
    var frame = CGRect.zero

    /// Whether the status bar runs down one side of the screen, as on iPhone Duo's open screen
    /// in landscape. A notch in landscape insets both sides alike, so it does not count.
    var hasStatusStripOnOneSide: Bool {
        abs(insets.leading - insets.trailing) > 1
    }
}

extension EnvironmentValues {
    @Entry var screenSafeArea = ScreenSafeArea()
}

private struct ScreenSafeAreaReader: ViewModifier {
    @State private var safeArea = ScreenSafeArea()

    func body(content: Content) -> some View {
        content
            .environment(\.screenSafeArea, safeArea)
            .onGeometryChange(for: ScreenSafeArea.self) { proxy in
                ScreenSafeArea(insets: proxy.safeAreaInsets, frame: proxy.frame(in: .global))
            } action: { safeArea = $0 }
    }
}

private struct ScreenCenteredModifier: ViewModifier {
    @Environment(\.screenSafeArea) private var screen
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var frame = CGRect.zero

    func body(content: Content) -> some View {
        let insets = horizontalSizeClass == .regular
            ? ScreenCentering.screenInsets(
                screen.insets, screen: screen.frame, view: frame, layoutDirection: layoutDirection
            )
            : EdgeInsets()
        let padding = ScreenCentering.extraPadding(for: insets)
        content
            .padding(.leading, padding.leading)
            .padding(.trailing, padding.trailing)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
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
