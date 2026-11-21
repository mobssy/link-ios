//
//  FriendManagementViews.swift
//  TalkMVP
//
//  Friend management views following Single Responsibility Principle
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import SwiftData

// MARK: - Blocked Friends View
struct BlockedFriendsView: View {
    let blockedFriends: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        NavigationStack {
            List {
                if blockedFriends.isEmpty {
                    ContentUnavailableView(
                        languageManager.string("No Blocked Friends"),
                        systemImage: "person.slash",
                        description: Text(languageManager.string("No Blocked Friends"))
                    )
                } else {
                    ForEach(blockedFriends, id: \.id) { friendship in
                        BlockedFriendRow(friendship: friendship, repository: LocalFriendshipRepository(modelContext: modelContext))
                    }
                }
            }
            .navigationTitle(languageManager.string("Blocked List"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(languageManager.string("Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Blocked Friend Row
struct BlockedFriendRow: View {
    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 40
    let friendship: Friendship
    let repository: FriendshipRepositoryProtocol
    @State private var showingUnblockAlert = false
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        HStack {
            // Gray while blocked or hidden.
            SenderAvatarView(name: friendship.friendName, size: avatarSize)
                .saturation(0)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text(languageManager.string(FriendshipStatus.blocked.title))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button(languageManager.string(.unblockAction)) {
                showingUnblockAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .alert(languageManager.string("Unblock Friend"), isPresented: $showingUnblockAlert) {
            Button(languageManager.string("Cancel"), role: .cancel) { }
            Button(languageManager.string(.unblockAction), role: .destructive) {
                unblockFriend()
            }
        } message: {
            Text(languageManager.string("Unblock \(friendship.friendName)?"))
        }
    }

    private func unblockFriend() {
        try? repository.setStatus(.accepted, of: friendship)
    }
}

// MARK: - Manage Friends View
struct ManageFriendsView: View {
    let hiddenFriends: [Friendship]
    let blockedFriends: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(languageManager.string("Hidden List"))) {
                    if hiddenFriends.isEmpty {
                        ContentUnavailableView(
                            languageManager.string("No Hidden Friends"),
                            systemImage: "eye.slash",
                            description: Text(languageManager.string("No Hidden Friends"))
                        )
                    } else {
                        ForEach(hiddenFriends, id: \.id) { friendship in
                            HiddenFriendRow(friendship: friendship, repository: LocalFriendshipRepository(modelContext: modelContext))
                        }
                    }
                }

                Section(header: Text(languageManager.string("Blocked List"))) {
                    if blockedFriends.isEmpty {
                        ContentUnavailableView(
                            languageManager.string("No Blocked Friends"),
                            systemImage: "hand.raised.slash",
                            description: Text(languageManager.string("No Blocked Friends"))
                        )
                    } else {
                        ForEach(blockedFriends, id: \.id) { friendship in
                            BlockedFriendRow(friendship: friendship, repository: LocalFriendshipRepository(modelContext: modelContext))
                        }
                    }
                }
            }
            .navigationTitle(languageManager.string("Manage Hidden/Blocked"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(languageManager.string("Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Hidden Friend Row
struct HiddenFriendRow: View {
    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 40
    let friendship: Friendship
    let repository: FriendshipRepositoryProtocol
    @State private var showingUnhideAlert = false
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        HStack {
            SenderAvatarView(name: friendship.friendName, size: avatarSize)
                .saturation(0)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text(languageManager.string(FriendshipStatus.hidden.title))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer()

            Button(languageManager.string(.unhideAction)) {
                showingUnhideAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .alert(languageManager.string("Unhide Friend"), isPresented: $showingUnhideAlert) {
            Button(languageManager.string("Cancel"), role: .cancel) { }
            Button(languageManager.string(.unhideAction), role: .destructive) {
                unhideFriend()
            }
        } message: {
            Text(languageManager.string("Unhide \(friendship.friendName)?"))
        }
    }

    private func unhideFriend() {
        try? repository.setStatus(.accepted, of: friendship)
    }
}
