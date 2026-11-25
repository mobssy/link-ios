//
//  MessageRuns.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation

/// Groups a chat's messages into runs: messages one person sent close together. Only the last
/// message of a run carries the time and the read receipt, so a burst of short messages doesn't
/// repeat the same minute under every bubble.
nonisolated enum MessageRuns {
    /// One message, as far as runs are concerned.
    struct Item {
        let id: UUID
        let sender: String
        let isFromCurrentUser: Bool
        let timestamp: Date
    }

    /// How far apart two messages can be and still share a run.
    static let gap: TimeInterval = 5 * 60

    /// The messages that end a run, in a list ordered oldest first.
    static func runEnds(in items: [Item]) -> Set<UUID> {
        var ends = Set<UUID>()
        for (index, item) in items.enumerated() {
            let next = items.indices.contains(index + 1) ? items[index + 1] : nil
            if let next,
               next.isFromCurrentUser == item.isFromCurrentUser,
               next.sender == item.sender,
               next.timestamp.timeIntervalSince(item.timestamp) <= gap {
                continue
            }
            ends.insert(item.id)
        }
        return ends
    }
}
