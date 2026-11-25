//
//  FriendBanner.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI

/// What a one-to-one chat shows under its navigation bar about the person it is with: the one
/// place to add them, instead of a button on every message they sent.
nonisolated enum FriendBanner: Equatable {
    case none, addFriend, requestSent

    /// `standing` is nil until it has been looked up. A group has no one person to add, and
    /// someone blocked is unblocked from the menu, not befriended from a banner. Once closed, the
    /// banner stays away: adding the person is still in their profile and a message's menu.
    init(isGroup: Bool, standing: FriendStanding?, isBlocked: Bool, closed: Bool = false) {
        guard !isGroup, !isBlocked, !closed else {
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

/// Which chats' friend banners were closed, kept across launches.
nonisolated enum ClosedFriendBanners {
    static let key = "closedFriendBannerRooms"

    static func contains(_ roomID: UUID, in defaults: UserDefaults = .standard) -> Bool {
        (defaults.stringArray(forKey: key) ?? []).contains(roomID.uuidString)
    }

    static func close(_ roomID: UUID, in defaults: UserDefaults = .standard) {
        let closed = defaults.stringArray(forKey: key) ?? []
        guard !closed.contains(roomID.uuidString) else { return }
        defaults.set(closed + [roomID.uuidString], forKey: key)
    }
}

struct FriendBannerView: View {
    @Environment(LanguageManager.self) private var languageManager

    let banner: FriendBanner
    let name: String
    let onAddFriend: () -> Void
    let onClose: () -> Void

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
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .minimumHitTarget(visibleSize: 20)
                .accessibilityLabel(languageManager.string("Close"))
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
