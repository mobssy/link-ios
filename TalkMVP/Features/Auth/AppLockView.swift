import SwiftUI

struct AppLockView: View {
    @Environment(AppLockManager.self) var appLock
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.appPrimaryText)

                Text(languageManager.string("Unlock Required"))
                    .font(.title2)
                    .fontWeight(.semibold)

                if let error = appLock.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: {
                    Task { await appLock.authenticate() }
                }) {
                    HStack {
                        Image(systemName: "faceid")
                        Text(languageManager.string(LocalizedStringResource("Authenticate", comment: "Button on the lock screen that asks for Face ID, Touch ID or the passcode")))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary)
                    .foregroundStyle(.onAppPrimary)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && appLock.isLocked {
                // 포그라운드 복귀 시 자동 인증 시도
                Task { await appLock.authenticate(reason: unlockReason) }
            }
        }
        .onAppear {
            if appLock.isLocked {
                Task { await appLock.authenticate(reason: unlockReason) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(languageManager.string("App Lock Screen"))
        .accessibilityHint(languageManager.string("Authenticate with Face ID, Touch ID or your passcode"))
    }

    /// Why the app asks for Face ID, shown in the system prompt.
    private var unlockReason: String {
        languageManager.string("Authentication is required to unlock the app.")
    }
}

#Preview {
    AppLockView()
        .environment(AppLockManager())
        .environment(LanguageManager())
}
