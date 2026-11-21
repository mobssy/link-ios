//
//  FriendBanner.swift
//  TalkMVP
//

import SwiftUI

/// What a one-to-one chat shows under its navigation bar about the person it is with: the one
/// place to add them, instead of a button on every message they sent.
nonisolated enum FriendBanner: Equatable {
    case none, addFriend, requestSent

    /// `standing` is nil until it has been looked up. A group has no one person to add, and
    /// someone blocked is unblocked from the menu, not befriended from a banner.
    init(isGroup: Bool, standing: FriendStanding?, isBlocked: Bool) {
        guard !isGroup, !isBlocked else {
            self = .none
            return
        }
        switch standing {
        case .stranger: self = .addFriend
        case .requested: self = .requestSent
        case .friend, nil: self = .none
        }
    }
}

struct FriendBannerView: View {
    @Environment(LanguageManager.self) private var languageManager

    let banner: FriendBanner
    let name: String
    let onAddFriend: () -> Void

    var body: some View {
        if banner != .none {
            HStack(spacing: 12) {
                Text(languageManager.string("\(name) isn't your friend"))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if banner == .addFriend {
                    Button(languageManager.string("Add Friend"), action: onAddFriend)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(.appPrimaryText)
                } else {
                    Text(Self.requestSentText(languageManager))
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
    }

    static func requestSentText(_ languageManager: LanguageManager) -> String {
        languageManager.string("Request Sent")
    }
}
