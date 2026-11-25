//
//  ReplyPreviewSnippet.swift
//  TalkMVP
//
//  The card Siri shows before sending a reply: the text, and how each recipient will read it
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import AppIntents
import SwiftData
import SwiftUI

/// The reply Siri is asking about: the preview the send flow just built, so the card shows the
/// very translations Siri spoke rather than translating again, and whether Edit in L!NK took the
/// reply to the chat meanwhile. It holds one reply, for as long as Siri asks about it: Siri
/// confirms one reply at a time.
@MainActor
final class ReplyPreviewCache {
    static let shared = ReplyPreviewCache()

    private var latest: (roomID: UUID, preview: ReplyPreview)?
    private var edited: (roomID: UUID, text: String)?

    /// Starts on a new reply; an edit of an earlier one no longer counts.
    func store(_ preview: ReplyPreview, for roomID: UUID) {
        latest = (roomID, preview)
        edited = nil
    }

    /// The stored preview, if it is for this chat and this text.
    func preview(for roomID: UUID, text: String) -> ReplyPreview? {
        guard let latest, latest.roomID == roomID, latest.preview.text == text else { return nil }
        return latest.preview
    }

    /// Notes that Edit in L!NK took `text` to the chat's message field.
    func markEdited(_ text: String, in roomID: UUID) {
        edited = (roomID, text)
    }

    /// Whether Edit in L!NK took this text to this chat since the reply was stored.
    func wasEdited(_ text: String, in roomID: UUID) -> Bool {
        guard let edited else { return false }
        return edited.roomID == roomID && edited.text == text
    }

    /// Forgets the reply once Siri is done asking about it.
    func clear() {
        latest = nil
        edited = nil
    }
}

/// Shows the reply preview card while Siri asks for confirmation. Send and Cancel are the
/// system's own confirmation buttons; the card adds Edit in L!NK.
///
/// The chat is named by its id as text, not as a chat entity: the system rebuilds the card on
/// its own, and an entity that no longer resolves (App Lock turned on, the chat deleted) would
/// leave nothing to read. A plain id is looked up here, after the access check.
struct ReplyPreviewSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Reply Preview"
    static let isDiscoverable = false

    @Parameter(title: "Chat")
    var chatID: String

    @Parameter(title: "Message")
    var text: String

    @Dependency private var container: ModelContainer

    init() {}

    init(chatID: String, text: String) {
        self.chatID = chatID
        self.text = text
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let actions = ChatIntentActions(context: container.mainContext)
        try actions.checkAccess()
        let room = try actions.room(id: chatID)
        let preview: ReplyPreview
        if let cached = ReplyPreviewCache.shared.preview(for: room.id, text: text) {
            preview = cached
        } else {
            preview = try await actions.preview(text, for: room.id)
        }
        return .result(view: ReplyPreviewCard(chatName: room.name, chatID: room.id.uuidString, preview: preview))
    }
}

/// The text being sent, then one block per language: who reads it, what they will read, and
/// that translation back in the sender's language. Edit in L!NK opens the chat with the text in
/// its message field instead of sending it.
struct ReplyPreviewCard: View {
    let chatName: String
    /// The chat's id as text, for Edit in L!NK.
    let chatID: String
    let preview: ReplyPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chatName)
                    .font(.headline)
                Text("You're sending")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(preview.text)
                    .font(.body)
            }
            .accessibilityElement(children: .combine)

            ForEach(Array(preview.lines.enumerated()), id: \.offset) { _, line in
                ReplyPreviewLineView(line: line, senderLanguage: preview.senderLanguage)
            }

            // A secondary action beside the system's Send, so a bordered button. The label grows
            // with the text size and keeps at least a 44 pt target.
            Button(intent: OpenChatDraftIntent(chatID: chatID, text: preview.text)) {
                Label("Edit in L!NK", systemImage: "pencil")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("editInLinkButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .tint(.appPrimaryText)
    }
}

/// One language block of the card, read by VoiceOver as one element.
private struct ReplyPreviewLineView: View {
    let line: ReplyPreview.Line
    let senderLanguage: String

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if case .translated(let translation, let back) = line.reading {
                Text(translation)
                    .font(.body)
                if let back {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "translate")
                            .accessibilityHidden(true)
                        Text("Back in \(languageName(senderLanguage)): \(back)")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: LocalizedStringResource {
        let names = line.memberList
        let one = line.members.count == 1
        switch line.reading {
        case .asWritten:
            return one ? "\(names) reads it as written" : "\(names) read it as written"
        case .translated:
            let language = languageName(line.language)
            return one ? "\(names) reads it in \(language)" : "\(names) read it in \(language)"
        case .untranslatable:
            return "\(names) will see it as written. It couldn't be translated."
        case .unknownLanguage:
            return "\(names) will read it in their own language"
        }
    }

    /// The language's name in the card's own language ("English", "영어").
    private func languageName(_ code: String?) -> String {
        guard let code else { return "" }
        return locale.localizedString(forIdentifier: code) ?? code
    }
}
