//
//  ChatView+Sheets.swift
//  TalkMVP
//

import SwiftUI

// MARK: - Bookmarked Messages

struct BookmarkedMessagesSheet: View {
    let messages: [Message]
    let chatRoomName: String
    let onDismiss: () -> Void
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        NavigationStack {
            Group {
                if messages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.secondary)
                        Text(languageManager.string("No bookmarked messages"))
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(messages.sorted { $0.timestamp > $1.timestamp }) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(message.isFromCurrentUser
                                    ? languageManager.string(LocalizedStringResource("Me", comment: "Names the reader as the writer of their own messages"))
                                    : message.sender)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.appPrimaryText)
                                Spacer()
                                Text(message.timestamp, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary)
                            }
                            Text(message.text)
                                .font(.body)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle(languageManager.string("Bookmarks"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(languageManager.string("Done")) { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Disappearing Message Duration Picker

struct DisappearingMessagePickerSheet: View {
    let chatRoom: ChatRoom
    let onDismiss: () -> Void
    @Environment(LanguageManager.self) private var languageManager

    private var options: [(label: String, seconds: Int)] {
        [
            (languageManager.string(LocalizedStringResource("Off", comment: "Disappearing-messages timer: messages don't disappear")), 0),
            (languageManager.string("15 seconds"), 15),
            (languageManager.string("1 minute"), 60),
            (languageManager.string("10 minutes"), 600),
            (languageManager.string("30 minutes"), 1800)
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(languageManager.string("New messages will be deleted after being sent"))) {
                    ForEach(options, id: \.seconds) { option in
                        Button {
                            chatRoom.disappearingDuration = option.seconds
                            onDismiss()
                        } label: {
                            HStack {
                                Text(option.label)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if chatRoom.disappearingDuration == option.seconds {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.appPrimaryText)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(languageManager.string("Disappearing Messages"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(languageManager.string("Done")) { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Scheduled Send Picker

struct ScheduledSendSheet: View {
    @Binding var scheduledDate: Date
    let onConfirm: (Date) -> Void
    let onCancel: () -> Void
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.appPrimaryText)

                Text(languageManager.string("Choose when to send this message"))
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)

                DatePicker(
                    "",
                    selection: $scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                Spacer()
            }
            .padding()
            .navigationTitle(languageManager.string("Schedule Send"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(languageManager.string("Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(languageManager.string(LocalizedStringResource("Schedule", comment: "Button that schedules the message for the chosen time"))) {
                        onConfirm(scheduledDate)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
