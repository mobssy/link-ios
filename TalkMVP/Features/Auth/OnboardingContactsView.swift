//
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI

struct OnboardingContactsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss
    @State private var service = ContactsSyncService()
    @State private var isRequesting = false
    @State private var status: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.appPrimaryText)
                .padding(.top, 20)

            Text(languageManager.string("Find friends faster with Contacts"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(languageManager.string("We safely hash phone numbers/emails from your contacts to match with your friends."))
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            if !status.isEmpty {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }

            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text(languageManager.string("Not Now"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.tertiarySystemFill))
                        .foregroundStyle(Color.primary)
                        .clipShape(.rect(cornerRadius: 12))
                }

                Button(action: { Task { await requestAccessAndSync() } }) {
                    if isRequesting {
                        ProgressView()
                    } else {
                        Text(languageManager.string(LocalizedStringResource("Allow", comment: "Button that asks for access to Contacts")))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appPrimary)
                .foregroundStyle(.onAppPrimary)
                .clipShape(.rect(cornerRadius: 12))
                .disabled(isRequesting)
            }
            .padding(.horizontal)

            Spacer(minLength: 20)
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var permissionNeeded: String {
        languageManager.string("Please allow Contacts access in Settings.")
    }

    private func requestAccessAndSync() async {
        isRequesting = true
        defer { isRequesting = false }
        let status = service.checkAuthorizationStatus()
        switch status {
        case .authorized:
            await runSyncThenDismiss()
        case .notDetermined:
            if await service.requestAccess() {
                await runSyncThenDismiss()
            } else {
                self.status = permissionNeeded
            }
        case .denied:
            self.status = permissionNeeded
        }
    }

    @MainActor
    private func runSyncThenDismiss() async {
        self.status = languageManager.string("Syncing...")
        do {
            _ = try await service.syncAndMatch()
            self.status = languageManager.string(LocalizedStringResource("Done", comment: "Status after contacts finished syncing"))
            try? await Task.sleep(nanoseconds: 500_000_000)
            dismiss()
        } catch {
            self.status = error.localizedDescription
        }
    }
}
