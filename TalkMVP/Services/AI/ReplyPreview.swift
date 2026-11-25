//
//  ReplyPreview.swift
//  TalkMVP
//
//  How each recipient will read a reply, shown before it is sent
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation
import NaturalLanguage

/// What a reply will look like to the people it goes to: one line per language, with the
/// translation they will read and a translation back so the sender can check the meaning.
nonisolated struct ReplyPreview: Equatable, Sendable {
    enum Reading: Equatable, Sendable {
        /// Same language as the sender; nothing to translate.
        case asWritten
        /// The translation, and what it says in the sender's language (nil when that failed).
        case translated(String, back: String?)
        /// The language is known but the translation failed. No text is invented.
        case untranslatable
        /// Nothing tells which language these members read.
        case unknownLanguage
    }

    struct Line: Equatable, Sendable {
        /// Nil for `.unknownLanguage`.
        let language: String?
        let members: [String]
        let reading: Reading
    }

    let text: String
    let senderLanguage: String
    let lines: [Line]
}

nonisolated enum ReplyPreviewBuilder {
    typealias Translate = @Sendable (_ text: String, _ target: String) async -> String?

    /// The language the reply is written in: told from the text, or Siri's language when the
    /// text is too short to tell ("👍").
    static func senderLanguage(of text: String, siriLanguage: String) -> String {
        ConversationLanguage.confidentLanguage(of: text)?.rawValue ?? siriLanguage
    }

    /// One line per language among `members`. A member's language is what they wrote in
    /// `recent`, else `knownLanguage`. Translations only ever come from `translate`.
    static func build(
        text: String, members: [String], recent: [SummaryMessage],
        siriLanguage: String, knownLanguage: (String) -> String?, translate: @escaping Translate
    ) async -> ReplyPreview {
        let sender = senderLanguage(of: text, siriLanguage: siriLanguage)

        var groups: [(language: String, members: [String])] = []
        var unknown: [String] = []
        for member in members {
            let language = ConversationLanguage.of(sender: member, in: recent)?.rawValue ?? knownLanguage(member)
            guard let language else { unknown.append(member); continue }
            if let index = groups.firstIndex(where: { ConversationLanguage.isSame($0.language, language) }) {
                groups[index].members.append(member)
            } else {
                groups.append((language, [member]))
            }
        }

        let sameAsSender = groups.filter { ConversationLanguage.isSame($0.language, sender) }
        let others = groups.filter { !ConversationLanguage.isSame($0.language, sender) }

        let translated = await withTaskGroup(of: ReplyPreview.Line.self) { tasks in
            for group in others {
                tasks.addTask {
                    guard let forward = await translate(text, group.language) else {
                        return .init(language: group.language, members: group.members, reading: .untranslatable)
                    }
                    let back = await translate(forward, sender)
                    return .init(language: group.language, members: group.members, reading: .translated(forward, back: back))
                }
            }
            return await tasks.reduce(into: []) { $0.append($1) }
        }.sorted {
            $0.members.count != $1.members.count
                ? $0.members.count > $1.members.count
                : ($0.language ?? "") < ($1.language ?? "")
        }

        let written = sameAsSender.map { ReplyPreview.Line(language: $0.language, members: $0.members, reading: .asWritten) }
        let unknownLine = unknown.isEmpty ? [] : [ReplyPreview.Line(language: nil, members: unknown, reading: .unknownLanguage)]
        return ReplyPreview(text: text, senderLanguage: sender, lines: translated + written + unknownLine)
    }
}
