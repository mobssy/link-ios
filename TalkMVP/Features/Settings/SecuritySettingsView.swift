import SwiftUI

struct SecuritySettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $appLockEnabled) {
                    Label {
                        Text(languageManager.string("App Lock"))
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.purple)
                    }
                }
                .accessibilityHint(languageManager.string("Require Face ID/Touch ID to unlock the app"))
            }
        }
        // The same name as the Settings row that opens it.
        .navigationTitle(languageManager.string("App Lock"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
