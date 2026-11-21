//
//  MeetingNotesView.swift
//  TalkMVP
//
//  Meeting notes for a chat, grouped by kind
//

import SwiftUI

struct MeetingNotesView: View {
    let notes: MeetingNotes?
    let isLoading: Bool
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(languageManager.string("Writing meeting notes..."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let notes, !notes.isEmpty {
            List {
                if !notes.summary.isEmpty {
                    Section { Text(notes.summary) }
                }
                if !notes.decisions.isEmpty {
                    Section(Self.labels(languageManager).decisions) {
                        ForEach(notes.decisions, id: \.self) { Label($0, systemImage: "checkmark.seal") }
                    }
                }
                if !notes.actionItems.isEmpty {
                    Section(Self.labels(languageManager).actionItems) {
                        ForEach(Array(notes.actionItems.enumerated()), id: \.offset) { _, item in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.task)
                                    let detail = [item.owner, item.due].compactMap { $0 }.joined(separator: " · ")
                                    if !detail.isEmpty {
                                        Text(detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: "circle")
                            }
                        }
                    }
                }
                if !notes.schedule.isEmpty {
                    Section(Self.labels(languageManager).schedule) {
                        ForEach(Array(notes.schedule.enumerated()), id: \.offset) { _, item in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.when)
                                    Text(item.context).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            } icon: {
                                Image(systemName: "calendar")
                            }
                        }
                    }
                }
                if !notes.openQuestions.isEmpty {
                    Section(Self.labels(languageManager).openQuestions) {
                        ForEach(notes.openQuestions, id: \.self) { Label($0, systemImage: "questionmark.circle") }
                    }
                }
                Section {
                } footer: {
                    Text(notes.generatedByModel
                        ? languageManager.string("Written on device by Apple Intelligence.")
                        : languageManager.string("Apple Intelligence couldn't write these notes, so they were picked out by rules."))
                }
            }
        } else {
            ContentUnavailableView(
                languageManager.string("Nothing to note yet"),
                systemImage: "note.text",
                description: Text(languageManager.string("Decisions, tasks and dates from the chat will show up here."))
            )
        }
    }

    static func labels(_ languageManager: LanguageManager) -> MeetingNotes.Labels {
        MeetingNotes.Labels(
            title: languageManager.string("Meeting Notes"),
            decisions: languageManager.string("Decisions"),
            actionItems: languageManager.string("Action Items"),
            schedule: languageManager.string(LocalizedStringResource("Schedule", comment: "Meeting notes heading over the dates and times mentioned in the chat.")),
            openQuestions: languageManager.string("Open Questions")
        )
    }
}
