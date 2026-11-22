//
//  TestAccount.swift
//  TalkMVP
//
//  The one local account test mode signs into
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation
import SwiftData

/// Test mode signs into a single local "tester" account. Earlier builds created a new tester,
/// with its own copy of the sample friends, every time test mode was entered and never removed
/// the previous ones, so a store can hold dozens of them that nothing can reach any more.
@MainActor
enum TestAccount {
    static let username = "tester"
    static let email = "test@example.com"

    /// Stored test accounts, the one worth keeping first: the signed-in one, otherwise the
    /// most recently active. Matched on both username and email, so a real account that
    /// happens to use one of them is never mistaken for it.
    static func all(in context: ModelContext) throws -> [User] {
        let username = Self.username
        let email = Self.email
        let accounts = try context.fetch(FetchDescriptor<User>(
            predicate: #Predicate { $0.username == username && $0.email == email },
            sortBy: [SortDescriptor(\.lastActiveAt, order: .reverse)]
        ))
        return accounts.filter(\.isCurrentUser) + accounts.filter { !$0.isCurrentUser }
    }

    /// Whether `user` is the test-mode account.
    static func isTester(_ user: User) -> Bool {
        user.username == username && user.email == email
    }

    /// The domain sample people's addresses use. A friend at any other address was added by hand
    /// and is never touched by `syncSampleFriends`.
    static let sampleDomain = "@example.com"

    /// Makes the tester's sample friends match `friends`, by email: adds the missing ones, renames
    /// the ones whose name changed, and removes sample friends no longer listed, so a build that
    /// changes the sample list shows the new one without deleting the account. Does not save.
    static func syncSampleFriends(_ friends: [(name: String, email: String)], for tester: User, in context: ModelContext) throws {
        let testerID = tester.id.uuidString
        let names = Dictionary(friends.map { ($0.email, $0.name) }, uniquingKeysWith: { first, _ in first })
        var present = Set<String>()
        for friendship in try context.fetch(FetchDescriptor<Friendship>(
            predicate: #Predicate { $0.ownerUserId == testerID }
        )) {
            if let name = names[friendship.friendEmail] {
                if friendship.friendName != name { friendship.friendName = name }
                present.insert(friendship.friendEmail)
            } else if friendship.friendEmail.hasSuffix(sampleDomain) {
                context.delete(friendship)
            }
        }
        for friend in friends where !present.contains(friend.email) {
            present.insert(friend.email)
            context.insert(Friendship(
                userId: testerID,
                friendId: UUID().uuidString,
                friendName: friend.name,
                friendEmail: friend.email,
                status: .accepted
            ))
        }
    }

    /// Deletes every test account except `keep`, together with the friendships that belong to
    /// them. Does not save.
    /// - Returns: How many accounts were deleted.
    @discardableResult
    static func removeAll(except keep: User?, in context: ModelContext) throws -> Int {
        let extras = try all(in: context).filter { $0.id != keep?.id }
        guard !extras.isEmpty else { return 0 }
        let ids = Set(extras.map(\.id.uuidString))
        for friendship in try context.fetch(FetchDescriptor<Friendship>())
        where ids.contains(friendship.ownerUserId) || ids.contains(friendship.userId) || ids.contains(friendship.friendId) {
            context.delete(friendship)
        }
        extras.forEach(context.delete)
        return extras.count
    }
}
