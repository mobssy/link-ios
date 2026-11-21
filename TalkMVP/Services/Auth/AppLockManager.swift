//
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import Combine
import LocalAuthentication
import Foundation

/// What App Lock needs from the device: whether the owner can be checked at all, and the check.
nonisolated protocol DeviceOwnerAuthenticating: Sendable {
    func canAuthenticate() -> Bool
    func authenticate(reason: String, fallbackTitle: String) async throws
}

/// Face ID or Touch ID first, then the device passcode. The owner can always get in this way, so
/// the lock screen never needs a way around the lock.
nonisolated struct LocalDeviceOwnerAuthenticator: DeviceOwnerAuthenticating {
    private let policy = LAPolicy.deviceOwnerAuthentication

    func canAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(policy, error: nil)
    }

    func authenticate(reason: String, fallbackTitle: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = fallbackTitle
        _ = try await context.evaluatePolicy(policy, localizedReason: reason)
    }
}

@MainActor
@Observable
class AppLockManager {
    /// The setting SecuritySettingsView turns on and off.
    static let enabledKey = "appLockEnabled"

    var isLocked: Bool = false
    var errorMessage: String?

    private let authenticator: DeviceOwnerAuthenticating
    private let defaults: UserDefaults
    private var isAuthenticating = false

    init(authenticator: DeviceOwnerAuthenticating = LocalDeviceOwnerAuthenticator(), defaults: UserDefaults = .standard) {
        self.authenticator = authenticator
        self.defaults = defaults
    }

    private var isLockEnabled: Bool {
        defaults.bool(forKey: Self.enabledKey)
    }

    // 앱 시작 시 현재 설정을 반영하여 잠금 여부 결정
    func updateLockStateOnLaunch() {
        if isLockEnabled && !authenticator.canAuthenticate() {
            // No passcode on the device any more, so there is nothing to check the owner
            // against: turn the setting off rather than lock the owner out for good.
            defaults.set(false, forKey: Self.enabledKey)
            isLocked = false
        } else {
            isLocked = isLockEnabled
        }
    }

    // ScenePhase 변화에 따라 잠금 처리 (활성화될 때 잠금 요구)
    func handleScenePhase(_ phase: ScenePhase) {
        if isLockEnabled {
            switch phase {
            case .inactive, .background:
                // App is leaving the foreground: require authentication next time
                isLocked = true
            case .active:
                // Do not force-lock on becoming active; AppLockView will prompt if `isLocked` is already true
                break
            @unknown default:
                break
            }
        } else {
            isLocked = false
        }
    }

    // 인증 시도 (Face ID/Touch ID, 안 되면 기기 암호)
    func authenticate(reason: String? = nil) async {
        // The lock screen asks on appear and again on returning to the foreground; one prompt at a time.
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let language = AppLocalization.languageCode(defaults: defaults)
        guard authenticator.canAuthenticate() else {
            isLocked = true
            errorMessage = AppLocalization.string("Authentication is unavailable on this device.", languageCode: language)
            return
        }
        do {
            try await authenticator.authenticate(
                reason: reason ?? AppLocalization.string("Authentication is required to unlock the app.", languageCode: language),
                fallbackTitle: AppLocalization.string("Use Passcode", languageCode: language)
            )
            isLocked = false
            errorMessage = nil
        } catch {
            // Cancelling or failing leaves the app locked; the only way in is to try again.
            isLocked = true
            errorMessage = error.localizedDescription
        }
    }
}
