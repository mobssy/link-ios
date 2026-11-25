//
//  SwipeToReply.swift
//  TalkMVP
//
//  Swiping a message to the right to reply to it
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import UIKit

extension View {
    /// Swiping the view to the right reveals Reply, and a full swipe starts the reply.
    func swipeToReply(_ label: String, onReply: @escaping () -> Void) -> some View {
        swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(label) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onReply()
            }
            // The action's fill, under white text: the deeper shade reads in both modes.
            .tint(.appPrimaryStrong)
        }
    }
}
