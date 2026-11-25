//
//  ChatDraftHandoff.swift
//  TalkMVP
//
//  A reply drafted with Siri, on its way to the chat's message field
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation
import Observation

/// Carries a draft from Siri's Edit in L!NK to the chat it belongs to. The app opens that chat
/// when a draft arrives, and the chat puts the text in its message field. Nothing is sent: the
/// user sends it, or not, from the chat. It holds one draft, the latest.
@MainActor
@Observable
final class ChatDraftHandoff {
    /// The draft not taken yet, and the chat it is for.
    private(set) var pending: (roomID: UUID, text: String)?

    func hand(_ text: String, to roomID: UUID) {
        pending = (roomID, text)
    }

    /// The draft for this chat, handed over once. A draft for another chat stays where it is.
    func takeDraft(for roomID: UUID) -> String? {
        guard let pending, pending.roomID == roomID else { return nil }
        self.pending = nil
        return pending.text
    }
}
