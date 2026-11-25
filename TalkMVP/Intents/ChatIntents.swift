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
// The messages schema's @AppIntent expansion names file types (.audio, .image, .item).
import UniformTypeIdentifiers

/// Sends a message to a chat picked by name, as the App Shortcut phrases and Shortcuts ask ("Send a
/// message to Family Group with L!NK"). Siri's messages domain can't name a chat, only people, so
/// this is the way to reach a group by its name. It confirms like the domain's intent below.
struct SendChatMessageIntent: AppIntent {
    /// Not just "Send Message": the messages domain's intent below is listed under that name.
    static let title: LocalizedStringResource = "Send Message to Chat"
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
        // Read before sending, so a failure here can't follow a message that already went out.
        let authorName = try actions.signedInName()
        let sent = try await sendAfterSiriConfirms(content.map { String($0.characters) } ?? "", to: room, using: actions)
        let message = ChatMessageEntity(sent, in: room, authorName: authorName)
        return .result(value: [message], dialog: "Sent to \(room.name).")
    }
}

/// An intent that sends a reply only after Siri has shown the reply preview card and the user
/// said Send. Only the two send intents adopt it.
protocol ConfirmsReplyWithPreview: AppIntent {}

extension SendChatMessageIntent: ConfirmsReplyWithPreview {}
extension SendMessageToPeopleIntent: ConfirmsReplyWithPreview {}

extension ConfirmsReplyWithPreview {
    /// Sends `text` to `room` only once the user says Send in the system's confirmation, which
    /// shows the reply preview card and speaks `ReplyPreviewDialog`. Cancelling sends nothing, and
    /// there is no way around the confirmation.
    @MainActor
    @discardableResult
    func sendAfterSiriConfirms(_ text: String, to room: ChatRoom, using actions: ChatIntentActions) async throws -> Message {
        try await actions.sendAfterConfirming(text, to: room.id, pending: .shared) { preview in
            try await requestConfirmation(
                actionName: .send,
                dialog: IntentDialog(ReplyPreviewDialog.text(for: preview, chatName: room.name)),
                snippetIntent: ReplyPreviewSnippetIntent(chatID: room.id.uuidString, text: preview.text)
            )
        }
    }
}

/// Edit in L!NK on the reply card: opens the chat with the reply in its message field, to change
/// before sending. It sends nothing. The messages domain's `draftMessage` schema would fit, but the
/// 27.2 tools reject its `conversation` destination (as for `sendMessage`), and a draft from the
/// card belongs to one chat, so this names the chat itself, by its id as text for the reason
/// `ReplyPreviewSnippetIntent` gives.
struct OpenChatDraftIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Message"
    static let description = IntentDescription("Opens a chat with the message ready to edit. Nothing is sent.")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    /// Only the reply card runs it; Shortcuts has Send Message to Chat for writing to a chat.
    static let isDiscoverable = false

    @Parameter(title: "Chat")
    var chatID: String

    @Parameter(title: "Message")
    var text: String

    @Dependency private var container: ModelContainer
    @Dependency private var drafts: ChatDraftHandoff

    init() {}

    init(chatID: String, text: String) {
        self.chatID = chatID
        self.text = text
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let actions = ChatIntentActions(context: container.mainContext)
        try actions.checkAccess()
        let room = try actions.room(id: chatID)
        try actions.handDraft(text, to: room.id, via: drafts, pending: .shared)
        return .result()
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
