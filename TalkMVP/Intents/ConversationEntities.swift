//
//  ConversationEntities.swift
//  TalkMVP
//
//  L!NK's chats and the people in them, as Siri's messages domain describes them
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import AppIntents
import Foundation
import SwiftData

/// Someone a reply can go to. L!NK knows the people in a chat by name only, so the name is the
/// identifier and there is no phone number or email to hand Siri.
@AppEntity(schema: .messages.messagePerson)
struct ChatPersonEntity {
    static let defaultQuery = ChatPersonQuery()

    /// The name, as the chat shows it.
    let id: String
    var person: IntentPerson

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }

    /// `isMe` marks the signed-in user, the author of what they send.
    init(name: String, isMe: Bool = false) {
        id = name
        person = IntentPerson(identifier: .applicationDefined(name), name: .displayName(name), handle: nil, isMe: isMe)
    }
}

/// Finds the people in the user's chats. Like the chat query, it finds no one while App Lock is
/// on or nobody is signed in.
struct ChatPersonQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    @MainActor
    func entities(for identifiers: [String]) async throws -> [ChatPersonEntity] {
        try people().filter(identifiers.contains).map { ChatPersonEntity(name: $0) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [ChatPersonEntity] {
        try people(matching: string).map { ChatPersonEntity(name: $0) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ChatPersonEntity] {
        try people().map { ChatPersonEntity(name: $0) }
    }

    @MainActor
    private func people(matching name: String? = nil) throws -> [String] {
        let actions = ChatIntentActions(context: container.mainContext)
        guard (try? actions.checkAccess()) != nil else { return [] }
        return try actions.people(matching: name)
    }
}

/// A chat, as Siri and Shortcuts refer to it.
@AppEntity(schema: .messages.conversation)
struct ChatConversationEntity {
    static let defaultQuery = ChatConversationQuery()

    let id: UUID
    var recipients: [ChatPersonEntity]
    var displayName: String
    var previewText: AttributedString
    /// The group's name; nil for a one-to-one chat, which is named after the person.
    var conversationName: String?
    var isRead: Bool
    var attributes: Set<ChatConversationAttribute>
    var dateLastActive: Date?

    /// The name only. The last message stays out of Siri's and Shortcuts' pickers, where anyone
    /// near the phone could read it.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
}

extension ChatConversationEntity {
    @MainActor
    init(_ room: ChatRoom) {
        id = room.id
        recipients = ChatIntentActions.recipients(of: room).map { ChatPersonEntity(name: $0) }
        displayName = room.name
        // A disappearing chat's last message outlives the message itself (the chat list keeps
        // it), so it isn't handed to Siri at all.
        previewText = AttributedString(room.disappearingDuration > 0 ? "" : room.lastMessage)
        conversationName = room.isGroup ? room.name : nil
        isRead = room.unreadCount == 0
        attributes = room.notificationsEnabled ? [] : [.muted]
        dateLastActive = room.timestamp
    }
}

/// What else the messages domain can say about a chat. The schema leaves the cases to the app,
/// and the tools need at least one: L!NK's is a muted chat.
@AppEnum(schema: .messages.conversationAttribute)
enum ChatConversationAttribute: String {
    case muted

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.muted: "Muted"]
}

/// Finds chats for Siri ("send a message to Mina") and for picking one in Shortcuts. While App
/// Lock is on or nobody is signed in, it finds none, so chat names stay out of sight too.
struct ChatConversationQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ChatConversationEntity] {
        try rooms().filter { identifiers.contains($0.id) }.map(ChatConversationEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ChatConversationEntity] {
        try rooms(matching: string).map(ChatConversationEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ChatConversationEntity] {
        try rooms().map(ChatConversationEntity.init)
    }

    @MainActor
    private func rooms(matching name: String? = nil) throws -> [ChatRoom] {
        let actions = ChatIntentActions(context: container.mainContext)
        guard (try? actions.checkAccess()) != nil else { return [] }
        return try actions.rooms(matching: name)
    }
}

/// Who Siri was asked to send to. The 27.2 tools accept only people here (no `conversation`
/// case, though the schema lists one), so a chat is found by the people in it.
@UnionValue
enum ChatDestination {
    case people([IntentPerson])
    case messagePerson(ChatPersonEntity)
    case messagePeople([ChatPersonEntity])
}

extension ChatDestination {
    /// The chat these people make up: one person's one-to-one chat, or the group of exactly them.
    @MainActor
    func room(in actions: ChatIntentActions) throws -> ChatRoom {
        switch self {
        case .messagePerson(let person): try actions.room(forPeople: [person.id])
        case .messagePeople(let people): try actions.room(forPeople: people.map(\.id))
        case .people(let people): try actions.room(forPeople: Self.names(of: people))
        }
    }

    /// The names Siri's people carry; someone without a name is left out.
    nonisolated static func names(of people: [IntentPerson]) -> [String] {
        people.compactMap { person in
            switch person.name {
            case .displayName(let name): name
            case .components(let components): PersonNameComponentsFormatter().string(from: components)
            case .unknown: nil
            @unknown default: nil
            }
        }
    }
}
