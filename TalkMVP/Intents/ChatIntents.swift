//
//  ChatIntents.swift
//  TalkMVP
//
//  Siri and Shortcuts: send a message to a chat, summarize a chat
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import AppIntents
import Foundation
import GeoToolbox
import SwiftData
import UniformTypeIdentifiers

/// Sends a message to a chat picked by name, as the App Shortcut phrases and Shortcuts ask ("Send a
/// message to Family Group with L!NK"). Siri's messages domain can't name a chat, only people, so
/// this is the way to reach a group by its name. It confirms like the domain's intent below.
struct SendChatMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "Send Message"
    static let description = IntentDescription("Sends a message to one of your chats.")
    /// Sending as the user needs the phone unlocked, like opening the chat would.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Chat", requestValueDialog: "Which chat?")
    var chat: ChatConversationEntity

    @Parameter(title: "Message", requestValueDialog: "What should I send?")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$message) to \(\.$chat)")
    }

    @Dependency private var container: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let actions = ChatIntentActions(context: container.mainContext)
        try actions.checkAccess()
        let room = try actions.room(id: chat.id)
        try await sendAfterSiriConfirms(message, to: room, using: actions)
        return .result(dialog: "Sent to \(room.name).")
    }
}

/// Sends a message the way Siri's messages domain asks: to people, whose chat it finds, and only
/// after the user has seen how each of them will read it and said Send.
@AppIntent(schema: .messages.sendMessage)
struct SendMessageToPeopleIntent {
    /// Sending as the user needs the phone unlocked, like opening the chat would.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    var content: AttributedString?
    var destination: ChatDestination
    // L!NK sends text only this round. The schema's other parts are declared because the domain
    // requires them; a request that carries any of them sends its text and ignores the rest.
    var subject: AttributedString?
    var attachments: [IntentFile]
    var audioMessage: IntentFile?
    var locations: [PlaceDescriptor]
    var links: [URL]
    var scheduledDate: Date?

    @Dependency private var container: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ChatMessageEntity]> & ProvidesDialog {
        let actions = ChatIntentActions(context: container.mainContext)
        try actions.checkAccess()
        let room = try destination.room(in: actions)
        let sent = try await sendAfterSiriConfirms(content.map { String($0.characters) } ?? "", to: room, using: actions)
        let message = ChatMessageEntity(sent, in: room, authorName: try actions.signedInName())
        return .result(value: [message], dialog: "Sent to \(room.name).")
    }
}

extension AppIntent {
    /// Sends `text` to `room` only once the user says Send in the system's confirmation, which
    /// shows the reply preview card and speaks `ReplyPreviewDialog`. Cancelling sends nothing, and
    /// there is no way around the confirmation.
    @MainActor
    @discardableResult
    func sendAfterSiriConfirms(_ text: String, to room: ChatRoom, using actions: ChatIntentActions) async throws -> Message {
        let chat = ChatConversationEntity(room)
        return try await actions.sendAfterConfirming(text, to: room.id) { preview in
            ReplyPreviewCache.shared.store(preview, for: room.id)
            try await requestConfirmation(
                actionName: .send,
                dialog: IntentDialog(ReplyPreviewDialog.text(for: preview, chatName: room.name)),
                snippetIntent: ReplyPreviewSnippetIntent(chat: chat, text: preview.text)
            )
        }
    }
}

struct SummarizeChatIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Chat"
    static let description = IntentDescription("Summarizes a chat on device with Apple Intelligence.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Chat", requestValueDialog: "Which chat?")
    var chat: ChatConversationEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Summarize \(\.$chat)")
    }

    @Dependency private var container: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = try await ChatIntentActions(context: container.mainContext)
            .summary(of: chat.id, language: ChatIntentActions.summaryLanguage())
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

/// The phrases Siri knows these actions by, without any setup in Shortcuts.
struct ChatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendChatMessageIntent(),
            phrases: [
                "Send a message with \(.applicationName)",
                "Send a message to \(\.$chat) with \(.applicationName)",
            ],
            shortTitle: "Send Message",
            systemImageName: "paperplane"
        )
        AppShortcut(
            intent: SummarizeChatIntent(),
            phrases: [
                "Summarize a chat in \(.applicationName)",
                "Summarize \(\.$chat) in \(.applicationName)",
            ],
            shortTitle: "Summarize Chat",
            systemImageName: "text.quote"
        )
    }
}
