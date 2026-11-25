//
//  MessageEntities.swift
//  TalkMVP
//
//  A sent message, as Siri's messages domain returns it from the send intent
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import AppIntents
import Foundation
import GeoToolbox
import LinkPresentation
import SwiftData

/// A message sent from Siri. The schema requires every property below; L!NK fills the text, the
/// author, the chat, the time and whether it disappears, and leaves what it doesn't support
/// (subject, attachments, audio, places, links, effects, reactions, replies) empty.
@AppEntity(schema: .messages.message)
struct ChatMessageEntity {
    static let defaultQuery = ChatMessageQuery()

    let id: UUID
    var messageType: ChatMessageType
    var author: ChatPersonEntity
    var isRead: Bool
    var attributes: Set<ChatMessageAttribute>
    var conversation: ChatConversationEntity
    var date: Date
    var subject: AttributedString?
    var body: AttributedString?
    var attachments: [IntentFile]
    var audioMessage: IntentFile?
    var customAttachments: [ChatCustomAttachmentEntity]
    var locations: [PlaceDescriptor]
    var links: [LinkMetadata]
    var messageEffect: ChatMessageEffect?
    var reaction: ChatReaction?
    var referencedMessage: ChatMessageEntity?
    var notificationIdentifier: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(body.map { String($0.characters) } ?? "")")
    }
}

extension ChatMessageEntity {
    /// `message` in `room`, written by `authorName` when it is the user's own.
    @MainActor
    init(_ message: Message, in room: ChatRoom, authorName: String) {
        id = message.id
        messageType = .unspecified
        author = message.isFromCurrentUser
            ? ChatPersonEntity(name: authorName, isMe: true)
            : ChatPersonEntity(name: message.sender)
        isRead = message.isFromCurrentUser || message.isRead
        attributes = message.isDisappearing ? [.disappearing] : []
        conversation = ChatConversationEntity(room)
        date = message.timestamp
        subject = nil
        body = AttributedString(message.text)
        attachments = []
        audioMessage = nil
        customAttachments = []
        locations = []
        links = []
        messageEffect = nil
        reaction = nil
        referencedMessage = nil
        notificationIdentifier = nil
    }
}

/// Finds messages by id, with their chats; none while App Lock is on or nobody is signed in.
struct ChatMessageQuery: EntityQuery {
    @Dependency private var container: ModelContainer

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ChatMessageEntity] {
        let actions = ChatIntentActions(context: container.mainContext)
        guard (try? actions.checkAccess()) != nil else { return [] }
        let name = try actions.signedInName()
        return try actions.messages(ids: identifiers).map { ChatMessageEntity($0.message, in: $0.room, authorName: name) }
    }
}

/// The schema's one message type.
@AppEnum(schema: .messages.messageType)
enum ChatMessageType: String {
    case unspecified

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.unspecified: "Message"]
}

// The schema leaves the cases of these to the app, and the tools need at least one each.

/// What else can be said about a message: L!NK's is a disappearing one.
@AppEnum(schema: .messages.messageAttribute)
enum ChatMessageAttribute: String {
    case disappearing

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.disappearing: "Disappearing"]
}

/// L!NK sends no message effects, so a message's effect is always nil and this one case is
/// only there because the tools need one.
@AppEnum(schema: .messages.messageEffect)
enum ChatMessageEffect: String {
    case noEffect

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.noEffect: "No Effect"]
}

/// L!NK's reactions are emoji, not custom ones, so a message's reaction from Siri is always nil
/// and this one case is only there because the tools need one.
@AppEnum(schema: .messages.customReaction)
enum ChatCustomReaction: String {
    case like

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.like: "Like"]
}

/// A reaction on a message. L!NK messages sent from Siri never carry one.
@UnionValue
enum ChatReaction {
    case customReaction(ChatCustomReaction)
    case attributedString(AttributedString)
}

/// An app-defined attachment. L!NK has none, so the query finds none.
@AppEntity(schema: .messages.customAttachment)
struct ChatCustomAttachmentEntity {
    static let defaultQuery = ChatCustomAttachmentQuery()

    let id: String
    var sourceName: AttributedString?
    var description: AttributedString?

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct ChatCustomAttachmentQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ChatCustomAttachmentEntity] { [] }
}
