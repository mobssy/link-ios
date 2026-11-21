//
//  AuthManager.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import SwiftData
import Combine
import UserNotifications
import os

private let authLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "AuthManager")

/// Owns the signed-in session. The persisted source of truth is the single `User`
/// flagged `isCurrentUser`; every sign-in path goes through `activate(_:)` and every
/// sign-out path through `endSession()`, so the flag and `currentUser` never disagree.
@MainActor
@Observable
class AuthManager {
    private(set) var currentUser: User?
    private(set) var isLoading = false
    var errorMessage: String?

    var isAuthenticated: Bool { currentUser != nil }

    /// Usernames given to accounts made by signing in with Apple or Google; sign-up can't take them.
    static let reservedUsernamePrefixes = ["apple_", "google_"]

    private let modelContext: ModelContext
    /// Stand-in for a server round trip on sign-up / sign-in. Tests pass `.zero`.
    private let simulatedLatency: Duration
    private let attachmentFiles: AttachmentFileStoring
    private let passwordStore: PasswordStoring

    init(
        modelContext: ModelContext,
        simulatedLatency: Duration = .seconds(1),
        attachmentFiles: AttachmentFileStoring = DiskAttachmentFileStore(),
        passwordStore: PasswordStoring = KeychainPasswordStore()
    ) {
        self.modelContext = modelContext
        self.simulatedLatency = simulatedLatency
        self.attachmentFiles = attachmentFiles
        self.passwordStore = passwordStore
        restoreSession()
    }

    /// Picks up the user that was signed in when the app last ran.
    /// A single indexed fetch, so it runs synchronously: the first frame already
    /// shows the right screen instead of flashing the sign-in form.
    private func restoreSession() {
        var descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isCurrentUser == true
            }
        )
        descriptor.fetchLimit = 1
        do {
            currentUser = try modelContext.fetch(descriptor).first
        } catch {
            authLogger.error("Failed to restore session: \(error.localizedDescription, privacy: .public)")
            currentUser = nil
        }
    }

    func signUp(username: String, displayName: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 실제 앱에서는 서버 API 호출
        try? await Task.sleep(for: simulatedLatency)

        guard !Self.reservedUsernamePrefixes.contains(where: { username.lowercased().hasPrefix($0) }) else {
            errorMessage = AppLocalization.string("Usernames can't start with apple_ or google_.")
            return
        }

        // 사용자명 중복 검사
        let existingUserDescriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username || user.email == email
            }
        )

        do {
            let existingUsers = try modelContext.fetch(existingUserDescriptor)
            if !existingUsers.isEmpty {
                errorMessage = AppLocalization.string("Username or email already exists.")
                return
            }

            let newUser = User(
                username: username,
                displayName: displayName,
                email: email,
                statusMessage: AppLocalization.string(LocalizedStringResource("Hey there!", comment: "Status message a new account starts with"))
            )
            // The password goes to the Keychain as a salted hash before the account exists, so
            // there is never an account that signs in without one. Hashing is slow on purpose,
            // so it runs off the main actor.
            let store = passwordStore
            let accountID = newUser.id
            try await Task.detached { try store.setPassword(password, for: accountID) }.value
            modelContext.insert(newUser)
            try activate(newUser)

            // 샘플 친구들 추가
            createSampleFriends(for: newUser)
        } catch {
            errorMessage = AppLocalization.string("An error occurred during sign up: \(error.localizedDescription)")
        }
    }

    func signIn(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 실제 앱에서는 서버 API 호출
        try? await Task.sleep(for: simulatedLatency)

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username || user.email == username
            }
        )

        // One message for an unknown account and a wrong password, so the form doesn't
        // tell anyone which usernames exist.
        let signInFailed = AppLocalization.string("The username or password is incorrect.")
        do {
            guard let user = try modelContext.fetch(descriptor).first else {
                errorMessage = signInFailed
                return
            }
            let store = passwordStore
            let accountID = user.id
            let verified = await Task.detached { store.verifyPassword(password, for: accountID) }.value
            guard verified else {
                errorMessage = signInFailed
                return
            }
            try activate(user)
        } catch {
            errorMessage = AppLocalization.string("An error occurred during sign in: \(error.localizedDescription)")
        }
    }

    /// Starts the credential-free demo session ("test mode"). It signs into the one stored test
    /// account, creating it on first use, and deletes any extra ones earlier builds left behind,
    /// so entering test mode again never piles up accounts or duplicate friends.
    func startTestSession(displayName: String, statusMessage: String, friends: [(name: String, email: String)]) {
        errorMessage = nil
        do {
            let tester = try TestAccount.all(in: modelContext).first
                ?? newTestAccount(displayName: displayName, statusMessage: statusMessage)
            try TestAccount.removeAll(except: tester, in: modelContext)
            try addMissingFriends(friends, to: tester)
            try activate(tester)
        } catch {
            authLogger.error("Failed to start test session: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    private func newTestAccount(displayName: String, statusMessage: String) -> User {
        let tester = User(
            username: TestAccount.username,
            displayName: displayName,
            email: TestAccount.email,
            statusMessage: statusMessage
        )
        modelContext.insert(tester)
        return tester
    }

    /// Gives the tester each sample friend it does not already have, matched by email.
    private func addMissingFriends(_ friends: [(name: String, email: String)], to tester: User) throws {
        let testerID = tester.id.uuidString
        let existing = Set(try modelContext.fetch(FetchDescriptor<Friendship>(
            predicate: #Predicate { $0.ownerUserId == testerID }
        )).map(\.friendEmail))
        for friend in friends where !existing.contains(friend.email) {
            modelContext.insert(Friendship(
                userId: testerID,
                friendId: UUID().uuidString,
                friendName: friend.name,
                friendEmail: friend.email,
                status: .accepted
            ))
        }
    }

    func signOut() {
        do {
            try clearCurrentUserFlags()
            try modelContext.save()
        } catch {
            authLogger.error("Failed to persist sign-out: \(error.localizedDescription, privacy: .public)")
        }
        currentUser = nil
    }

    /// Marks `user` as the one signed-in account and publishes it.
    private func activate(_ user: User) throws {
        try clearCurrentUserFlags()
        user.isCurrentUser = true
        user.lastActiveAt = Date()
        try modelContext.save()
        currentUser = user
    }

    private func clearCurrentUserFlags() throws {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isCurrentUser == true
            }
        )
        for user in try modelContext.fetch(descriptor) {
            user.isCurrentUser = false
        }
    }

    private func createSampleFriends(for user: User) {
        let sampleFriends = [
            ("friend1", "김친구", "friend1@example.com"),
            ("friend2", "이동료", "friend2@example.com"),
            ("friend3", "박가족", "friend3@example.com"),
            ("friend4", "최스터디", "friend4@example.com")
        ]

        for (_, name, email) in sampleFriends {
            let friendship = Friendship(
                userId: user.id.uuidString,
                friendId: UUID().uuidString,
                friendName: name,
                friendEmail: email,
                status: .accepted
            )

            modelContext.insert(friendship)
        }

        // 테스트용 받은 친구 요청들 추가
        let pendingRequests = [
            ("pending1", "신청자1", "pending1@example.com"),
            ("pending2", "신청자2", "pending2@example.com")
        ]

        for (_, name, email) in pendingRequests {
            let receivedRequest = Friendship(
                userId: UUID().uuidString, // 다른 사용자의 ID
                friendId: user.id.uuidString, // 현재 사용자가 친구로 추가되는 것
                friendName: name,
                friendEmail: email,
                status: .pending
            )
            receivedRequest.ownerUserId = user.id.uuidString
            modelContext.insert(receivedRequest)
        }

        do {
            try modelContext.save()
        } catch {
            authLogger.error("Failed to save sample friends: \(error)")
        }
    }

    // MARK: - SSO Sign-In

    func signInWithApple(userId: String, email: String?, fullName: PersonNameComponents?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        do {
            try signInWithSSO(
                provider: "apple",
                subject: userId,
                displayName: name.isEmpty ? "Apple User" : name,
                email: email ?? ""
            )
        } catch {
            errorMessage = AppLocalization.string("An error occurred during Apple sign in.")
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let info = try await GoogleOAuthService.signIn()
            try signInWithSSO(
                provider: "google",
                subject: info.userId,
                displayName: info.displayName,
                email: info.email
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reuses the local account created by an earlier sign-in with the same provider identity,
    /// or creates it on first use. The account is found by the provider's full user ID only:
    /// never by username, which sign-up controls, nor by part of the ID, which others can share.
    private func signInWithSSO(provider: String, subject: String, displayName: String, email: String) throws {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in user.ssoProvider == provider && user.ssoSubject == subject }
        )
        let user: User
        if let existingUser = try modelContext.fetch(descriptor).first {
            user = existingUser
        } else {
            user = User(
                username: "\(provider)_\(subject.prefix(8))",
                displayName: displayName,
                email: email,
                statusMessage: "안녕하세요!"
            )
            user.ssoProvider = provider
            user.ssoSubject = subject
            modelContext.insert(user)
        }
        try activate(user)
    }

    func updateProfile(displayName: String, statusMessage: String, profileImageData: Data?) {
        guard let user = currentUser else { return }

        user.displayName = displayName
        user.statusMessage = statusMessage
        user.profileImageData = profileImageData
        user.lastActiveAt = Date()

        try? modelContext.save()
    }

    /// Deletes the account. With no backend yet, that means wiping everything stored on
    /// this device — conversations and their attachment files, friendships and local
    /// accounts — then ending the session.
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            for message in try modelContext.fetch(FetchDescriptor<Message>()) {
                modelContext.delete(message)
            }
            for chatRoom in try modelContext.fetch(FetchDescriptor<ChatRoom>()) {
                modelContext.delete(chatRoom)
            }
            for friendship in try modelContext.fetch(FetchDescriptor<Friendship>()) {
                modelContext.delete(friendship)
            }
            for user in try modelContext.fetch(FetchDescriptor<User>()) {
                modelContext.delete(user)
            }
            try modelContext.save()
        } catch {
            authLogger.error("Failed to delete account data: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return
        }
        attachmentFiles.removeFiles(keeping: [])
        passwordStore.removeAllPasswords()

        // 알림 정리
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        try? await center.setBadgeCount(0)

        currentUser = nil
    }
}
