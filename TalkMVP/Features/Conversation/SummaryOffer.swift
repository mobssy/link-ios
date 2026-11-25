//
//  SummaryOffer.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI

/// When a chat offers a summary on its own, instead of leaving it in the menu: on opening a chat
/// with enough unread messages that catching up by reading would take a while.
nonisolated enum SummaryOffer {
    static let unreadThreshold = 10

    static func shows(unreadAtOpen: Int, summaryEnabled: Bool, dismissed: Bool) -> Bool {
        summaryEnabled && !dismissed && unreadAtOpen >= unreadThreshold
    }
}

/// A glass strip under the chat's title that offers the summary and can be closed.
struct SummaryOfferView: View {
    @Environment(LanguageManager.self) private var languageManager
    let onSummarize: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSummarize) {
                Label(languageManager.string(LocalizedStringResource("Catch up with a summary", comment: "Offer at the top of a chat with many unread messages; opens the on-device summary.")), systemImage: "apple.intelligence")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .minimumHitTarget(visibleSize: 20)
            .accessibilityLabel(languageManager.string("Close"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
