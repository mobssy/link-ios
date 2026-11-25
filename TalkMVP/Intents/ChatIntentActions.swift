//
//  ChatIntentActions.swift
//  TalkMVP
//
//  What the Siri and Shortcuts actions do, apart from the App Intents plumbing
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation
import SwiftData

/// Why a Siri or Shortcuts action couldn't run.
enum ChatIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case signedOut
    case appLocked
    case chatNotFound
    case emptyMessage

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .signedOut: "Sign in to the app first."
        case .appLocked: "App Lock is on. Open the app to unlock it first."
        case .chatNotFound: "That chat isn't in the app anymore."
        case .emptyMessage: "There's nothing to send."
        }
    }
}

/// The work behind each action, on the app's own store, kept apart from the App Intents types so
/// it can be tested without Siri.
@MainActor
struct ChatIntentActions {
    let context: ModelContext
    /// Whether App Lock is on; read from the setting AppLockManager stores.
    var isAppLocked: () -> Bool = { UserDefaults.standard.bool(forKey: "appLockEnabled") }
    var summarize: (_ messages: [SummaryMessage], _ language: String) async -> String = { messages, language in
        await AIService.shared.summarize(messages: messages, targetLanguage: language)
    }
    /// Builds what the user is shown before a reply goes out: the text and how each recipient
    /// would read it.
    var previewReply: (_ text: String, _ room: ChatRoom, _ recent: [SummaryMessage]) async -> ReplyPreview = { text, room, recent in
        await ReplyPreviewBuilder.build(
            text: text,
            members: ChatIntentActions.recipients(of: room),
            recent: recent,
            siriLanguage: ChatIntentActions.summaryLanguage(),
            knownLanguage: { TestData.language(of: $0) },
            translate: { await AIService.shared.translate($0, autoDetect: true, target: $1) }
        )
    }

    /// Siri can reach the app without opening it, so an action checks what the app's own screens
    /// would: that someone is signed in, and that App Lock isn't keeping the chats out of sight.
    func checkAccess() throws {
        guard !isAppLocked() else { throw ChatIntentError.appLocked }
        let signedIn = try context.fetchCount(FetchDescriptor<User>(predicate: #Predicate { $0.isCurrentUser == true })) > 0
        guard signedIn else { throw ChatIntentError.signedOut }
    }

    /// Chats, most recent first; with a name, only those whose name contains it.
    func rooms(matching name: String? = nil) throws -> [ChatRoom] {
        let rooms = try context.fetch(FetchDescriptor<ChatRoom>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return rooms }
        return rooms.filter { $0.name.localizedStandardContains(name) }
    }

    func room(id: UUID) throws -> ChatRoom {
        guard let room = try context.fetch(FetchDescriptor<ChatRoom>(predicate: #Predicate { $0.id == id })).first else {
            throw ChatIntentError.chatNotFound
        }
        return room
    }

    /// The chat for the people Siri names: one person's one-to-one chat, or the group whose members
    /// are exactly those people. Names match whatever their case.
    func room(forPeople names: [String]) throws -> ChatRoom {
        let wanted = Set(names.map(Self.nameKey))
        let match: (ChatRoom) -> Bool = wanted.count == 1
            ? { !$0.isGroup && wanted.contains(Self.nameKey($0.name)) }
            : { $0.isGroup && Set($0.memberNames.map(Self.nameKey)) == wanted }
        guard !wanted.isEmpty, let room = try rooms().first(where: match) else { throw ChatIntentError.chatNotFound }
        return room
    }

    /// Everyone a reply can go to, each name once, in the order of the most recent chats; with a
    /// name, only those whose name contains it.
    func people(matching name: String? = nil) throws -> [String] {
        var seen = Set<String>()
        let everyone = try rooms().flatMap(Self.recipients(of:)).filter { seen.insert(Self.nameKey($0)).inserted }
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return everyone }
        return everyone.filter { $0.localizedStandardContains(name) }
    }

    /// The signed-in user's name, as their messages are signed.
    func signedInName() throws -> String {
        let user = try context.fetch(FetchDescriptor<User>(predicate: #Predicate { $0.isCurrentUser == true })).first
        guard let user else { throw ChatIntentError.signedOut }
        return user.displayName
    }

    /// The messages with these ids, each with its chat; one whose chat is gone is left out.
    func messages(ids: [UUID]) throws -> [(message: Message, room: ChatRoom)] {
        let messages = try context.fetch(FetchDescriptor<Message>(predicate: #Predicate { ids.contains($0.id) }))
        return messages.compactMap { message in
            guard let roomID = UUID(uuidString: message.chatRoomId), let room = try? room(id: roomID) else { return nil }
            return (message, room)
        }
    }

    private static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Sends `text` to the chat as the signed-in user, with the chat's options, the way the chat
    /// screen does, and puts it in the chat list preview.
    @discardableResult
    func send(_ text: String, to roomID: UUID) async throws -> Message {
        try checkAccess()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ChatIntentError.emptyMessage }
        let room = try room(id: roomID)
        let message = Message(text: text, isFromCurrentUser: true, chatRoomId: room.id.uuidString)
        if room.disappearingDuration > 0 {
            message.isDisappearing = true
            message.disappearAfterSeconds = room.disappearingDuration
        }
        try await LocalMessageRepository(modelContext: context).saveMessage(message)
        try await LocalChatRoomRepository(modelContext: context).updateChatRoom(room, lastMessage: text, timestamp: Date())
        return message
    }

    /// The preview of sending `text` to the chat, built from its last 20 messages. Nothing is sent.
    func preview(_ text: String, for roomID: UUID) async throws -> ReplyPreview {
        try checkAccess()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ChatIntentError.emptyMessage }
        let room = try room(id: roomID)
        let recent = try await LocalMessageRepository(modelContext: context)
            .fetchMessages(for: room.id.uuidString, limit: Self.previewMessageLimit, before: nil)
        return await previewReply(text, room, recent.map(SummaryMessage.init))
    }

    /// Shows the preview to `confirm` and sends only if it returns. `confirm` throws to cancel
    /// (Siri's confirmation does when the user says no), and then nothing is sent.
    @discardableResult
    func sendAfterConfirming(
        _ text: String,
        to roomID: UUID,
        confirm: (ReplyPreview) async throws -> Void
    ) async throws -> Message {
        let preview = try await preview(text, for: roomID)
        try await confirm(preview)
        return try await send(text, to: roomID)
    }

    /// Who a reply in this chat is for: the members of a group, or the one person otherwise.
    static func recipients(of room: ChatRoom) -> [String] {
        room.isGroup ? room.memberNames : [room.name]
    }

    /// How many of the chat's latest messages a reply preview looks at.
    static let previewMessageLimit = 20

    /// The chat summarized in `language`, as plain text for Siri to say or show.
    func summary(of roomID: UUID, language: String) async throws -> String {
        try checkAccess()
        let room = try room(id: roomID)
        let messages = try await LocalMessageRepository(modelContext: context)
            .fetchMessages(for: room.id.uuidString, limit: AIService.summaryMessageLimit, before: nil)
        return Self.plainText(await summarize(messages.map(SummaryMessage.init), language))
    }

    /// The summary without the app's heading paragraph (title and date) and the Markdown markers,
    /// which Siri would otherwise show as they are.
    static func plainText(_ summary: String) -> String {
        var paragraphs = summary.components(separatedBy: "\n\n")
        if paragraphs.count > 1 { paragraphs.removeFirst() }
        return paragraphs.joined(separator: "\n\n")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The language Siri is speaking, among those summaries are written in.
    static func summaryLanguage(for preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let preferred = preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh-Hant") { return "zh-Hant" }
        if preferred.hasPrefix("zh") { return "zh-Hans" }
        return ["ko", "ja", "es"].first { preferred.hasPrefix($0) } ?? "en"
    }
}
