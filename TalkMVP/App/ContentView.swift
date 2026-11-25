//
//  ContentView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var router = AppRouter()
    @State private var showTestModeAlert = false
    @AppStorage("contactsOnboardingShown") private var contactsOnboardingShown = false
    @State private var showContactsOnboarding = false

    var body: some View {
        mainContent()
            .environment(router)
            .tint(.appPrimaryText)
            .task { authManager.refreshTestFriends(TestData.friends) }
            .sheet(isPresented: $showContactsOnboarding, onDismiss: {
                contactsOnboardingShown = true
            }) {
                OnboardingContactsView()
                    .environment(languageManager)
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    if !contactsOnboardingShown {
                        showContactsOnboarding = true
                    }
                } else {
                    // Signed out or account deleted: next session starts fresh on the first tab.
                    router.selectedTab = .friends
                }
            }
    }

    @ViewBuilder
    private func mainContent() -> some View {
        if authManager.isAuthenticated {
            AuthenticatedTabsView()
        } else {
            UnauthenticatedView(
                showTestModeAlert: $showTestModeAlert,
                startTestMode: enterTestMode
            )
        }
    }

    private func enterTestMode() {
        authManager.startTestSession(
            displayName: languageManager.string("Tester"),
            statusMessage: languageManager.string("Experiencing in test mode"),
            friends: TestData.friends
        )
    }
}

struct AuthenticatedTabsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AppRouter.self) private var router
    @Query var chatRooms: [ChatRoom]
    @State private var notificationManager = NotificationManager()
    @Environment(\.scenePhase) private var scenePhase
    private var totalUnread: Int { chatRooms.map { $0.unreadCount }.reduce(0, +) }

    var body: some View {
        TabView(selection: Bindable(router).selectedTab) {
            FriendsTab()
                .tabItem {
                    Label(languageManager.string(LocalizedStringResource("Friends", comment: "Tab bar item")), systemImage: "person.fill")
                }
                .tag(AppTab.friends)

            ChatTab()
                .tabItem {
                    Label(languageManager.string(LocalizedStringResource("Chats", comment: "Tab bar item")), systemImage: "message.fill")
                }
                .badge(totalUnread)
                .tag(AppTab.chats)

            SettingsTab()
                .tabItem {
                    Label(languageManager.string(LocalizedStringResource("Settings", comment: "Tab bar item")), systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        // Test mode puts nothing on these screens; Settings' profile card says it is on.
        .tint(.appPrimaryText)
        // The app icon shows the same unread count as the Chats tab (none with notifications off).
        .onChange(of: totalUnread, initial: true) { _, count in
            notificationManager.updateBadgeCount(count)
        }
        // Again on the way to the Home Screen, where the badge shows: a count set before
        // notifications were allowed didn't take.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { notificationManager.updateBadgeCount(totalUnread) }
        }
    }
}

private struct FriendsTab: View {
    @Environment(AuthManager.self) private var authManager
    var body: some View { FriendsView(authManager: authManager) }
}

private struct ChatTab: View {
    var body: some View { ChatListView() }
}

private struct SettingsTab: View {
    @Environment(AuthManager.self) private var authManager
    var body: some View { SettingsView(authManager: authManager) }
}

struct UnauthenticatedView: View {
    @Binding var showTestModeAlert: Bool
    let startTestMode: () -> Void

    var body: some View {
        AuthView {
            TestModeButtonView(showTestModeAlert: $showTestModeAlert, startTestMode: startTestMode)
        }
    }
}

struct TestModeButtonView: View {
    @Environment(LanguageManager.self) private var languageManager
    @Binding var showTestModeAlert: Bool
    let startTestMode: () -> Void

    var body: some View {
        // A secondary action beside signing in, so it is styled as one.
        Button(languageManager.string("Try Test Mode"), systemImage: "wrench.and.screwdriver") {
            showTestModeAlert = true
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier("testModeButton")
        // The question comes out of the button that asked it. An alert sits in the middle of
        // the safe area, which is off to one side of this screen when the status bar runs down
        // one edge (iPhone Duo open, in landscape).
        .confirmationDialog(
            languageManager.string("Test Mode"),
            isPresented: $showTestModeAlert,
            titleVisibility: .visible
        ) {
            Button(languageManager.string("Start Test"), action: startTestMode)
            Button(languageManager.string("Cancel"), role: .cancel) { }
        } message: {
            Text(languageManager.string("You can experience all app features without logging in.\nWould you like to enter test mode?"))
        }
    }
}

// MARK: - Test Data

nonisolated enum TestData {
    static let friends: [(name: String, email: String)] = [
        ("권도윤", "doyoon@example.com"),
        ("한서연", "seoyeon@example.com"),
        ("강민재", "minjae@example.com"),
        ("유지훈", "jihoon@example.com"),
        ("조하린", "harin@example.com")
    ]

    /// Who is in each sample group chat, by the group's localization key. Most are test-mode
    /// friends, so their messages carry a name the chat already knows; the study group's are
    /// people abroad, so one sample chat is written in several languages.
    static let groupMembers: [String: [String]] = [
        "family_group": ["강민재", "한서연"],
        "work_colleagues": ["유지훈", "조하린"],
        "family_trip": ["한서연", "Emma Kang"],
        "study_group": ["佐藤ゆき", "Lucía García"]
    ]

    /// The language each sample person writes in, whatever language the chat is in: they answer
    /// in theirs, and the reader sees it translated.
    static let memberLanguages: [String: String] = [
        "강민재": "ko", "한서연": "ko", "유지훈": "ko", "조하린": "ko", "권도윤": "ko", "김민지": "ko",
        "Emma Kang": "en",
        "佐藤ゆき": "ja",
        "Lucía García": "es"
    ]

    static func language(of member: String) -> String? {
        memberLanguages[member]
    }

    /// Test mode's status message as it may have been saved: in the language the app had when
    /// test mode started, in either wording the app has used.
    static let testModeStatuses: Set<String> = [
        "테스트 모드로 체험 중입니다", "Experiencing in test mode",
        "テストモードを体験中", "テストモードで体験中です",
        "正在体验测试模式", "正在以测试模式体验", "正在以測試模式體驗",
        "Explorando en modo de prueba", "Experimentando en modo de prueba",
    ]

    /// A status message to show: test mode's in the app's current language (`testModeStatus`),
    /// anything the user wrote as written.
    static func statusMessage(_ raw: String, testModeStatus: String) -> String {
        testModeStatuses.contains(raw.trimmingCharacters(in: .whitespacesAndNewlines)) ? testModeStatus : raw
    }
}

#Preview {
    if let container = try? ModelContainer(
        for: Message.self, ChatRoom.self, User.self, Friendship.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) {
        ContentView()
            .environment(AuthManager(modelContext: container.mainContext))
            .environment(LanguageManager())
            .modelContainer(container)
    } else {
        Text(verbatim: "Preview unavailable")
    }
}
