//
//  FriendProfileView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import SwiftData
import UIKit

struct FriendProfileView: View {
    let friendship: Friendship
    /// Opened from the chat with this same person: Start Chat goes back to it.
    var isInChatWithThisPerson = false
    /// In a sheet, which needs a way to close; pushed, the Back button does that.
    var showsCloseButton = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var router
    @State private var showingChatOpenFailed = false
    @State private var showingBlockAlert = false
    @State private var showingUnblockAlert = false
    @State private var showingReportConfirm = false
    @AppStorage("lastActivityEnabled") private var lastActivityEnabled = true
    @State private var lastActiveText: String?

    var body: some View {
        // No stack of its own: pushed from the Friends list, in its detail column, or in a
        // sheet that brings one.
        ScrollView {
            VStack(spacing: 20) {
                // 프로필 헤더
                VStack(spacing: 16) {
                    SenderAvatarView(name: friendship.friendName, size: 120)
                        .accessibilityHidden(true)

                    // 이름과 이메일
                    VStack(spacing: 8) {
                        Text(friendship.friendName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(friendship.friendEmail)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }

                    // 상태 배지
                    StatusBadge(status: friendship.status)
                }
                .padding(.vertical, 20)

                // 프로필 정보
                VStack(spacing: 16) {
                    ProfileInfoCard(
                        title: languageManager.string(LocalizedStringResource("Joined", comment: "Title of the card showing when a friend joined")),
                        value: formatDate(friendship.createdAt),
                        icon: "calendar"
                    )

                    // Shown only when there's something to show, never as "No Info".
                    if lastActivityEnabled && friendship.status == .accepted, let lastActiveText {
                        ProfileInfoCard(
                            title: languageManager.string("Last Active"),
                            value: lastActiveText,
                            icon: "clock"
                        )
                    }
                }

                // 액션 버튼들
                VStack(spacing: 12) {
                    if friendship.status == .accepted {
                        // 채팅하기 버튼
                        Button(action: startChat) {
                            Label(languageManager.string("Start Chat"), systemImage: "bubble.left.and.bubble.right.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appPrimary)
                                .foregroundStyle(.onAppPrimary)
                                .clipShape(.rect(cornerRadius: 12))
                        }
                    }

                    // 상태별 액션 버튼
                    switch friendship.status {
                    case .accepted:
                        // Blocking is rare and asks first, so it stays a plain button rather
                        // than a second large one competing with Start Chat.
                        Button(languageManager.string(Self.blockTitle), systemImage: "hand.raised", role: .destructive) {
                            showingBlockAlert = true
                        }
                        .padding(.top, 8)
                    case .blocked:
                        Button {
                            showingUnblockAlert = true
                        } label: {
                            Label(languageManager.string(.unblockAction), systemImage: "hand.raised.slash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    case .hidden:
                        Button {
                            unhideFriend()
                        } label: {
                            Label(languageManager.string(.unhideAction), systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    case .pending:
                        Text(languageManager.string(LocalizedStringResource("Pending", comment: "A friend request waiting for the other person to accept")))
                            .foregroundStyle(Color.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .screenCentered()
        }
        .navigationTitle(languageManager.string(LocalizedStringResource("Profile", comment: "Title of a person's profile screen")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button(languageManager.string("Close")) {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(languageManager.string("Share Profile")) {
                        shareProfile()
                    }

                    Divider()

                    Button(languageManager.string(Self.reportTitle), role: .destructive) {
                        reportUser()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .accessibilityLabel(languageManager.string("More options"))
                }
            }
        }
        .alert(languageManager.string("Couldn't open the chat"), isPresented: $showingChatOpenFailed) {
            Button(languageManager.string("Close"), role: .cancel) {}
        }
        .alert(languageManager.string("Block Friend"), isPresented: $showingBlockAlert) {
            Button(languageManager.string("Cancel"), role: .cancel) { }
            Button(languageManager.string(Self.blockTitle), role: .destructive) {
                blockFriend()
            }
        } message: {
            Text(languageManager.string("Block \(friendship.friendName)? Blocked friends can no longer send you messages."))
        }
        .alert(languageManager.string(LocalizedStringResource(
            "Unblock Friend",
            comment: "Title of the alert that unblocks a friend, on their profile"
        )), isPresented: $showingUnblockAlert) {
            Button(languageManager.string("Cancel"), role: .cancel) { }
            Button(languageManager.string(.unblockAction)) {
                unblockFriend()
            }
        } message: {
            Text(languageManager.string(LocalizedStringResource(
                "Unblock \(friendship.friendName)?",
                comment: "Message of the alert that unblocks a friend, on their profile; the argument is their name"
            )))
        }
        .onAppear { computeLastActivity() }
        .alert(languageManager.string(Self.reportTitle), isPresented: $showingReportConfirm) {
            Button(languageManager.string("Cancel"), role: .cancel) {}
            Button(languageManager.string(Self.reportTitle), role: .destructive) {}
        } message: {
            Text(languageManager.string("Report \(friendship.friendName)?"))
        }
    }

    private func computeLastActivity() {
        // Capture dynamic values into local constants for use in #Predicate
        let friendIdString = friendship.friendId
        let friendEmail = friendship.friendEmail
        let senderName = friendship.friendName

        var foundDate: Date?

        // 1) Try to find a User record for this friend by friendId
        if let friendUUID = UUID(uuidString: friendIdString) {
            let descriptorById = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.id == friendUUID
                }
            )
            if let users = try? modelContext.fetch(descriptorById), let user = users.first {
                foundDate = user.lastActiveAt
            }
        }

        // 2) If not found, try by email
        if foundDate == nil {
            let descriptorByEmail = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in
                    user.email == friendEmail
                }
            )
            if let users = try? modelContext.fetch(descriptorByEmail), let user = users.first {
                foundDate = user.lastActiveAt
            }
        }

        // 3) Fallback: use the most recent message timestamp from this friend (by sender name)
        if foundDate == nil {
            let descriptorMsg = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { m in
                    m.sender == senderName
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            if let msgs = try? modelContext.fetch(descriptorMsg), let recent = msgs.first {
                foundDate = recent.timestamp
            }
        }

        // When they last wrote, not whether they are online: with no server that can't be known.
        lastActiveText = foundDate.map(formatRelative)
    }

    private func formatRelative(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        let minute: Double = 60
        let hour = 60 * minute
        let day = 24 * hour

        if interval < hour {
            let mins = max(1, Int(interval / minute))
            return languageManager.string("\(mins)m ago")
        } else if interval < day {
            let hours = max(1, Int(interval / hour))
            return languageManager.string("\(hours)h ago")
        } else {
            let days = Int(interval / day)
            if days == 1 {
                return languageManager.string("Yesterday")
            }
            if days < 7 {
                return languageManager.string("\(days)d ago")
            }
            // 1주 이상이면 날짜 표기
            return formatDate(date)
        }
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func blockFriend() {
        setStatus(.blocked)
    }

    private func unblockFriend() {
        setStatus(.accepted)
    }

    private func unhideFriend() {
        setStatus(.accepted)
    }

    private func setStatus(_ status: FriendshipStatus) {
        withAnimation {
            try? LocalFriendshipRepository(modelContext: modelContext).setStatus(status, of: friendship)
        }
    }

    /// Opens the one-to-one room with this friend in the Chats tab, the same saved room every
    /// time, rather than presenting the chat in a sheet over this one.
    private func startChat() {
        guard !isInChatWithThisPerson else {
            dismiss()
            return
        }
        guard let currentUserId = authManager.currentUser?.id.uuidString else {
            showingChatOpenFailed = true
            return
        }
        let repository: ChatRoomRepositoryProtocol = LocalChatRoomRepository(modelContext: modelContext)
        Task {
            do {
                let room = try await repository.directChatRoom(
                    withUserId: friendship.otherUserId(currentUserId: currentUserId),
                    name: friendship.friendName,
                    email: friendship.friendEmail
                )
                // Close first: a sheet presented from the Friends tab would stay over Chats.
                dismiss()
                router.openChat(room.id)
            } catch {
                showingChatOpenFailed = true
            }
        }
    }

    private func shareProfile() {
        let profileText = "\(friendship.friendName) (\(friendship.friendEmail))"
        let activityVC = UIActivityViewController(activityItems: [profileText], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = scene.keyWindow?.rootViewController else { return }
        rootVC.present(activityVC, animated: true)
    }

    private func reportUser() {
        showingReportConfirm = true
    }

    /// On the button and in its alert. Its own key: the profile says "차단하기" where the
    /// Friends list's swipe action says "차단".
    private static let blockTitle = LocalizedStringResource(
        "friend.profile.block",
        defaultValue: "Block",
        comment: "Button on a friend's profile, and in its alert, that blocks them"
    )

    /// In the menu, and as the title and button of the alert that asks first.
    private static let reportTitle = LocalizedStringResource("Report", comment: "Reports a user for abuse")
}

// MARK: - Text shared by the Friends screens

extension LocalizedStringResource {
    /// Unblocks a friend, on their profile and in the blocked list.
    static let unblockAction = LocalizedStringResource("Unblock", comment: "Button that unblocks a friend")
    /// Shows a hidden friend again, on their profile and in the hidden list.
    static let unhideAction = LocalizedStringResource("Unhide", comment: "Button that shows a hidden friend again")
    /// The name for someone who hasn't set one.
    static let userPlaceholderName = LocalizedStringResource("User", comment: "Name shown for someone who has not set one")
}

extension FriendshipStatus {
    /// The status as a badge or a row shows it.
    var title: LocalizedStringResource {
        switch self {
        case .pending:
            LocalizedStringResource(
                "friendship.status.pending",
                defaultValue: "Pending",
                comment: "Status of a friend request that is not answered yet, on a badge or a row"
            )
        case .accepted:
            LocalizedStringResource("Friend", comment: "Status of someone who is your friend")
        case .hidden:
            LocalizedStringResource("Hidden", comment: "Status of a friend you hid")
        case .blocked:
            LocalizedStringResource("Blocked", comment: "Status of a friend you blocked")
        }
    }
}

// 상태 배지 컴포넌트
struct StatusBadge: View {
    let status: FriendshipStatus
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(languageManager.string(status.title))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .foregroundStyle(statusColor)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var statusColor: Color {
        switch status {
        case .accepted:
            return .green
        case .pending:
            return .orange
        case .blocked:
            return .red
        case .hidden:
            return .secondary
        }
    }
}

// 프로필 정보 카드
struct ProfileInfoCard: View {
    let title: String
    let value: String
    let icon: String
    var iconColor: Color = .appPrimary

    var body: some View {
        HStack(spacing: 16) {
            // 아이콘
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.body.weight(.medium))
            }

            // 정보
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)

                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let sampleFriendship = Friendship(
        userId: "user1",
        friendId: "user2",
        friendName: "김친구",
        friendEmail: "friend@example.com",
        status: .accepted
    )
    return NavigationStack { FriendProfileView(friendship: sampleFriendship) }
        .environment(AppRouter())
}
