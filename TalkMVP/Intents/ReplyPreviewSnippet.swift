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

/// The preview the send intent just built, so the card shows the very translations Siri spoke
/// rather than translating again. It holds one preview: Siri confirms one reply at a time.
@MainActor
final class ReplyPreviewCache {
    static let shared = ReplyPreviewCache()

    private var latest: (roomID: UUID, preview: ReplyPreview)?

    func store(_ preview: ReplyPreview, for roomID: UUID) {
        latest = (roomID, preview)
    }

    /// The stored preview, if it is for this chat and this text.
    func preview(for roomID: UUID, text: String) -> ReplyPreview? {
        guard let latest, latest.roomID == roomID, latest.preview.text == text else { return nil }
        return latest.preview
    }
}

/// Shows the reply preview card while Siri asks for confirmation. Send and Cancel are the
/// system's own confirmation buttons.
struct ReplyPreviewSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Reply Preview"
    static let isDiscoverable = false

    @Parameter(title: "Chat")
    var chat: ChatConversationEntity

    @Parameter(title: "Message")
    var text: String

    @Dependency private var container: ModelContainer

    init() {}

    init(chat: ChatConversationEntity, text: String) {
        self.chat = chat
        self.text = text
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let actions = ChatIntentActions(context: container.mainContext)
        try actions.checkAccess()
        let preview: ReplyPreview
        if let cached = ReplyPreviewCache.shared.preview(for: chat.id, text: text) {
            preview = cached
        } else {
            preview = try await actions.preview(text, for: chat.id)
        }
        return .result(view: ReplyPreviewCard(chatName: chat.displayName, preview: preview))
    }
}

/// The text being sent, then one block per language: who reads it, what they will read, and
/// that translation back in the sender's language.
struct ReplyPreviewCard: View {
    let chatName: String
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
