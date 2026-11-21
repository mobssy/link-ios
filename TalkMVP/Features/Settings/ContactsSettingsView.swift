//
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI

struct ContactsSettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @State private var service = ContactsSyncService()
    @AppStorage("contactsSyncEnabled") private var contactsSyncEnabled = false
    @State private var isSyncing = false
    @State private var status: String = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $contactsSyncEnabled) {
                    Label {
                        Text(languageManager.string("Enable Contacts Sync"))
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundStyle(.green)
                    }
                }
                .onChange(of: contactsSyncEnabled) { _, newValue in
                    if newValue {
                        Task { await requestAndMaybeSync() }
                    }
                }

                Button(action: { Task { await requestAndSyncNow() } }) {
                    Label {
                        Text(isSyncing ? syncingText : languageManager.string("Sync Now"))
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.tint)
                    }
                }
                .disabled(isSyncing)

                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section(footer: Text(languageManager.string("Phone numbers/emails are hashed before sending to the server."))) { EmptyView() }
        }
        .navigationTitle(languageManager.string("Contacts"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if contactsSyncEnabled {
                Task { await requestAndMaybeSync() }
            }
        }
    }

    private var syncingText: String {
        languageManager.string("Syncing...")
    }

    private var permissionNeededText: String {
        languageManager.string("Please allow Contacts access in Settings.")
    }

    private func requestAndMaybeSync() async {
        let status = service.checkAuthorizationStatus()
        switch status {
        case .authorized:
            if contactsSyncEnabled { await runSync() }
        case .notDetermined:
            if await service.requestAccess() {
                if contactsSyncEnabled { await runSync() }
            } else {
                errorMessage = permissionNeededText
            }
        case .denied:
            errorMessage = permissionNeededText
        }
    }

    private func requestAndSyncNow() async {
        let status = service.checkAuthorizationStatus()
        switch status {
        case .authorized:
            await runSync()
        case .notDetermined:
            if await service.requestAccess() {
                await runSync()
            } else {
                errorMessage = permissionNeededText
            }
        case .denied:
            errorMessage = permissionNeededText
        }
    }

    @MainActor
    private func runSync() async {
        isSyncing = true
        errorMessage = nil
        status = syncingText
        defer { isSyncing = false }
        do {
            let matched = try await service.syncAndMatch()
            if matched.isEmpty {
                status = languageManager.string("No matching users found.")
            } else {
                status = languageManager.string("Found \(matched.count) matching users.")
            }
        } catch {
            errorMessage = error.localizedDescription
            status = ""
        }
    }
}
