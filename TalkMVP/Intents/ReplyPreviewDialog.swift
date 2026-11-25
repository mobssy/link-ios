//
//  ReplyPreviewDialog.swift
//  TalkMVP
//
//  What Siri says while it shows the reply preview card
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation

/// The question Siri asks before sending. For one person (or several reading one language) it
/// says the translation back, so the sender hears what will arrive; when the chat reads several
/// languages it asks them to look at the card instead.
nonisolated enum ReplyPreviewDialog {
    static func text(for preview: ReplyPreview, chatName: String) -> LocalizedStringResource {
        if preview.lines.count == 1, let line = preview.lines.first {
            switch line.reading {
            case .translated(_, back: let back?):
                let back = sentence(back, language: preview.senderLanguage)
                return "\(line.memberList) will read it as \"\(back)\" Send it?"
            case .untranslatable:
                return "\(line.memberList) will see it as written. Send it?"
            default:
                break
            }
        }
        guard preview.lines.contains(where: \.reading.isAnotherLanguage) else {
            return "Send \"\(preview.text)\" to \(chatName)?"
        }
        let languages = preview.lines.filter { $0.language != nil }.count
        return languages > 1 ? "\(languages) languages. Take a look before sending." : "Take a look before sending."
    }

    /// `text` ending like a sentence, so the question after it starts a new one.
    static func sentence(_ text: String, language: String) -> String {
        guard let last = text.last, !".!?。！？…".contains(last) else { return text }
        return text + (language.hasPrefix("ja") || language.hasPrefix("zh") ? "。" : ".")
    }
}

extension ReplyPreview.Line {
    /// The members as one phrase in the current language ("Emma Kang and Joon").
    nonisolated var memberList: String {
        ListFormatter.localizedString(byJoining: members)
    }
}

extension ReplyPreview.Reading {
    /// Whether these readers are in a language other than the sender's, translated or not.
    nonisolated var isAnotherLanguage: Bool {
        switch self {
        case .translated, .untranslatable: true
        case .asWritten, .unknownLanguage: false
        }
    }
}
