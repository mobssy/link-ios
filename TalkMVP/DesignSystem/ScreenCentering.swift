//
//  ScreenCentering.swift
//  TalkMVP
//

import SwiftUI

/// Keeps content centered on the whole screen when the safe area is uneven left and right.
/// iPhone Duo's open screen in landscape puts the status bar in a strip down one side; content
/// centered in what is left then looks pushed to the other side. Padding the narrower side up
/// to the wider one centers it on the screen and still keeps it clear of both edges.
enum ScreenCentering {
    /// The padding to add on each side so both match the wider of the two insets.
    static func extraPadding(for insets: EdgeInsets) -> (leading: CGFloat, trailing: CGFloat) {
        let side = max(insets.leading, insets.trailing)
        return (side - insets.leading, side - insets.trailing)
    }
}

private struct ScreenCenteredModifier: ViewModifier {
    @State private var insets = EdgeInsets()

    func body(content: Content) -> some View {
        let padding = ScreenCentering.extraPadding(for: insets)
        content
            .padding(.leading, padding.leading)
            .padding(.trailing, padding.trailing)
            .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets = $0 }
    }
}

extension View {
    /// Centers the view on the screen rather than in an uneven safe area; see `ScreenCentering`.
    func screenCentered() -> some View {
        modifier(ScreenCenteredModifier())
    }
}
