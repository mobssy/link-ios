//
//  SettingsView.swift
//  TalkMVP
//
//  Main settings screen: profile card, preference links and account actions.

import SwiftUI
import UIKit
import SwiftData

struct SettingsView: View {
    var authManager: AuthManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("themeMode") private var themeMode: String = "system"

    @State private var showingDeleteAlert = false
    @State private var showingLogoutAlert = false

    // Sheets
    @State private var showingProfileEdit = false

    // Notifications
    @State private var notificationManager = NotificationManager()
    @AppStorage(NotificationPreferences.enabledKey) private var notificationsEnabled = true

    /// The status under the name; test mode's in the app's current language, not the one it
    /// started in.
    private var profileStatus: String {
        let testModeStatus = languageManager.string("Experiencing in test mode")
        guard let raw = authManager.currentUser?.statusMessage else { return testModeStatus }
        return TestData.statusMessage(raw, testModeStatus: testModeStatus)
    }

    // A split view like the Chats tab: in a regular-width window (iPad, an open iPhone Duo)
    // the list stays beside the page it opened; in a compact one it collapses into a push.
    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProfileCardView(
                        title: profileDisplayName().capitalized,
                        subtitle: profileStatus,
                        imageData: authManager.currentUser?.profileImageData,
                        action: { showingProfileEdit = true }
                    )

                    SettingsSectionCard(title: languageManager.string(LocalizedStringResource("General", comment: "Settings section with the app's everyday preferences"))) {
                        SettingsToggleRow(
                            systemImage: "bell.fill",
                            tint: .green,
                            title: languageManager.string("Notifications"),
                            isOn: $notificationsEnabled
                        )
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.theme) {
                            SettingsLinkRow(
                                systemImage: "paintpalette.fill",
                                tint: .orange,
                                title: languageManager.string("Theme")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.language) {
                            SettingsLinkRow(
                                systemImage: "globe",
                                tint: .blue,
                                title: languageManager.string("Language")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.appLock) {
                            SettingsLinkRow(
                                systemImage: "lock.fill",
                                tint: .purple,
                                title: languageManager.string("App Lock")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.aiFeatures) {
                            SettingsLinkRow(
                                systemImage: "sparkles",
                                tint: .pink,
                                title: languageManager.string("AI Features")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.translation) {
                            SettingsLinkRow(
                                systemImage: "character.bubble",
                                tint: .teal,
                                title: languageManager.string(LocalizedStringResource("Translation", comment: "Settings row that opens the message translation settings"))
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.contacts) {
                            SettingsLinkRow(
                                systemImage: "person.crop.circle.badge.plus",
                                tint: .green,
                                title: languageManager.string("Contacts")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.accessibility) {
                            SettingsLinkRow(
                                systemImage: "accessibility",
                                tint: .indigo,
                                title: languageManager.string("Accessibility")
                            )
                        }
                    }

                    SettingsSectionCard(title: languageManager.string(LocalizedStringResource("Info", comment: "Settings section with help, app info and terms"))) {
                        NavigationLink(value: SettingsPage.help) {
                            SettingsLinkRow(
                                systemImage: "questionmark.circle.fill",
                                tint: .blue,
                                title: languageManager.string("Help")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.appInfo) {
                            SettingsLinkRow(
                                systemImage: "info.circle.fill",
                                tint: .blue,
                                title: languageManager.string("App Info")
                            )
                        }
                        Divider().padding(.leading, 52)
                        NavigationLink(value: SettingsPage.terms) {
                            SettingsLinkRow(
                                systemImage: "doc.text.fill",
                                tint: .blue,
                                title: languageManager.string("Terms & Policies")
                            )
                        }
                    }
                    // One group like the others, signing out first; deleting the account asks to
                    // be confirmed, so it needs no card of its own.
                    SettingsSectionCard(title: languageManager.string(LocalizedStringResource("Account", comment: "Settings section with sign out and delete account"))) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showingLogoutAlert = true
                        } label: {
                            SettingsActionRow(systemImage: "rectangle.portrait.and.arrow.right", title: languageManager.string("Sign Out"))
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 52)
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showingDeleteAlert = true
                        } label: {
                            SettingsActionRow(systemImage: "trash", title: languageManager.string("Delete Account"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView(authManager: authManager)
                    .environment(languageManager)
            }
            // Alerts for destructive actions
            .alert(languageManager.string("Delete Account"), isPresented: $showingDeleteAlert) {
                Button(languageManager.string("Cancel"), role: .cancel) {}
                Button(languageManager.string("Delete Account"), role: .destructive) {
                    Task { await authManager.deleteAccount() }
                }
            } message: {
                Text(languageManager.string("Permanently delete your account."))
            }
            .alert(languageManager.string("Sign Out"), isPresented: $showingLogoutAlert) {
                Button(languageManager.string("Cancel"), role: .cancel) {}
                Button(languageManager.string("Sign Out")) {
                    authManager.signOut()
                }
            } message: {
                Text(languageManager.string("Sign out of your current account."))
            }
            .onChange(of: notificationsEnabled) { _, newValue in
                if !newValue {
                    notificationManager.clearAllNotifications()
                } else {
                    // 권한 재요청 (이미 허용된 경우 no-op)
                    Task {
                        await notificationManager.requestPermission()
                    }
                    // 읽지 않은 메시지 총합을 계산하여 배지 복원
                    let descriptor = FetchDescriptor<ChatRoom>()
                    let rooms = (try? modelContext.fetch(descriptor)) ?? []
                    let totalUnread = rooms.map { $0.unreadCount }.reduce(0, +)
                    notificationManager.updateBadgeCount(totalUnread)
                }
            }
            .navigationTitle(languageManager.string("Settings"))
            .navigationBarTitleDisplayMode(.large)
            // In a split view the page replaces the detail column; collapsed, it is pushed.
            .navigationDestination(for: SettingsPage.self) { page in
                destination(for: page)
                    .environment(languageManager)
            }
        } detail: {
            ContentUnavailableView(
                languageManager.string("Select a Setting"),
                systemImage: "gearshape",
                description: Text(languageManager.string("Pick an item from the list to open it here."))
            )
            .screenCentered()
        }
        .preferredColorScheme(themeMode == "light" ? .light : (themeMode == "dark" ? .dark : nil))
    }

    private func profileDisplayName() -> String {
        let raw = (authManager.currentUser?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return languageManager.string(LocalizedStringResource("User", comment: "Profile name shown when the account has no display name"))
        }
        if raw == "테스터" || raw == "Tester" {
            return languageManager.string(LocalizedStringResource("Tester", comment: "Profile name of the test-mode account"))
        }
        return raw
    }
}
