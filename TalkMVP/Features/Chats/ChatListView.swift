//
//  ChatListView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import Combine
import SwiftData
import os

private let chatListLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatListView")

/// The name of a sample group chat, by the room's key in `SampleChats`. Unlike the sample
/// messages, the names are UI text, so they come from the String Catalog.
private enum SampleGroupName: String {
    case familyGroup = "family_group"
    case workColleagues = "work_colleagues"
    case studyGroup = "study_group"
    case familyTrip = "family_trip"

    var resource: LocalizedStringResource {
        switch self {
        case .familyGroup: "Family Group"
        case .workColleagues: "Work Colleagues"
        case .studyGroup: "Study Group"
        case .familyTrip: "Family Trip"
        }
    }
}

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(LanguageManager.self) private var languageManager
    @Query(sort: \ChatRoom.timestamp, order: .reverse) private var chatRooms: [ChatRoom]
    @State private var searchText = ""
    /// The open conversation. Kept as an id so a room deleted while open simply resolves
    /// to nothing instead of leaving a dangling model in the detail column.
    @State private var selectedRoomID: UUID?
    @State private var chatService: ChatService

    // Shared in-memory context used only during init — replaced by the environment's
    // shared context in onAppear before any real I/O happens.
    private static let initServiceContext: ModelContext = {
        let schema = Schema([Message.self, ChatRoom.self, User.self, Friendship.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Cannot create ChatService initialization container")
        }
        return container.mainContext
    }()

    init() {
        self._chatService = State(initialValue: ChatService(modelContext: Self.initServiceContext))
    }

    var filteredChatRooms: [ChatRoom] {
        guard !searchText.isEmpty else { return chatRooms }
        return chatRooms.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedRoom: ChatRoom? {
        guard let selectedRoomID else { return nil }
        return chatRooms.first { $0.id == selectedRoomID }
    }

    // A split view adapts to the window instead of the device: in a regular-width window
    // (iPad, iPhone Duo's inner display, a large iPhone in landscape) the list and the
    // open conversation sit side by side; in a compact one (any iPhone in portrait, the
    // Duo's outer display, a narrow Split View) it collapses into the familiar push.
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedRoomID) {
                ForEach(filteredChatRooms, id: \.id) { room in
                    NavigationLink(value: room.id) {
                        ChatRoomRow(room: room)
                    }
                }
                .onDelete(perform: deleteChatRooms)
            }
            // The selected row is filled with the tint and its text turns white; the
            // regular brand color is too light for that (and hides the row's avatar).
            .tint(.appPrimaryStrong)
            .navigationTitle(languageManager.string("Chats"))
            .searchable(text: $searchText, prompt: languageManager.string("Search"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(languageManager.string("New Chat")) {
                            addNewChatRoom()
                        }
                        Button(languageManager.string("Group Chat")) {
                            addGroupChatRoom()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(languageManager.string("Create new chat"))
                }
            }
        } detail: {
            if let room = selectedRoom {
                // A new identity per room: the chat view builds its view model for the
                // room it first appears with, so switching rooms must not reuse it.
                ChatScreen(room: room)
                    .id(room.id)
            } else {
                ContentUnavailableView(
                    languageManager.string("Select a Chat"),
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text(languageManager.string("Pick a conversation from the list to open it here."))
                )
                .screenCentered()
            }
        }
        .onAppear {
            chatService.modelContext = modelContext
            createSampleDataIfNeeded()
        }
        // A room handed over from another tab, such as Start Chat on a friend's profile. Read
        // on first appearance too: the hand-over can come before this tab was ever shown.
        .onChange(of: router.roomToOpen, initial: true) {
            if let roomID = router.takeRoomToOpen() {
                selectedRoomID = roomID
            }
        }
    }

    private func addNewChatRoom() {
        let newRoom = ChatRoom(name: languageManager.string("New Friend"))
        modelContext.insert(newRoom)
        do { try modelContext.save() } catch { chatListLogger.error("Failed to save new chat room: \(error.localizedDescription, privacy: .public)") }
    }

    private func addGroupChatRoom() {
        let groupRoom = ChatRoom(name: languageManager.string("New Group"), profileImage: ChatRoom.groupSymbol)
        modelContext.insert(groupRoom)
        do { try modelContext.save() } catch { chatListLogger.error("Failed to save group chat room: \(error.localizedDescription, privacy: .public)") }
    }

    private func deleteChatRooms(offsets: IndexSet) {
        // Resolve the rooms now: the offsets refer to the list as currently shown.
        let rooms = offsets.map { filteredChatRooms[$0] }
        if rooms.contains(where: { $0.id == selectedRoomID }) {
            selectedRoomID = nil
        }
        let repository: ChatRoomRepositoryProtocol = LocalChatRoomRepository(modelContext: modelContext)
        Task {
            for room in rooms {
                do {
                    try await repository.deleteChatRoom(room)
                } catch {
                    chatListLogger.error("Failed to delete chat room: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    /// Starts an empty chat list with the sample chats: short conversations whose previews,
    /// times and unread counts come from their messages.
    private func createSampleDataIfNeeded() {
        guard chatRooms.isEmpty else { return }
        let now = Date()
        for sample in SampleChats.rooms(readerLanguage: AppLocalization.languageCode()) {
            let room = ChatRoom(
                name: sample.personName ?? groupName(forSampleKey: sample.key),
                profileImage: sample.members.isEmpty ? ChatRoom.personSymbol : ChatRoom.groupSymbol
            )
            room.memberNames = sample.members
            let lastSent = now.addingTimeInterval(-Double(sample.minutesAgo * 60))
            for (index, line) in sample.lines.enumerated() {
                let minutesBefore = (sample.lines.count - 1 - index) * SampleChats.minutesBetweenLines
                let message = line.speaker.name.map {
                    Message(text: line.text, isFromCurrentUser: false, sender: $0, chatRoomId: room.id.uuidString)
                } ?? Message(text: line.text, isFromCurrentUser: true, chatRoomId: room.id.uuidString)
                message.timestamp = lastSent.addingTimeInterval(-Double(minutesBefore * 60))
                // The reader's messages have been seen once someone answered them.
                message.isRead = line.speaker == .reader && index < sample.lines.count - 1
                modelContext.insert(message)
            }
            room.lastMessage = sample.lastMessage
            room.timestamp = lastSent
            room.unreadCount = sample.unreadCount
            modelContext.insert(room)
        }
        do { try modelContext.save() } catch { chatListLogger.error("Failed to save sample data: \(error.localizedDescription, privacy: .public)") }
    }

    private func groupName(forSampleKey key: String) -> String {
        SampleGroupName(rawValue: key).map { languageManager.string($0.resource) } ?? key
    }
}

struct ChatRoomRow: View {
    let room: ChatRoom
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At accessibility text sizes the time goes under the name, so the name has the full width
    /// instead of being cut to a few letters beside a time broken over two lines.
    private var nameAndTimeLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout())
    }

    /// A person's face for a one-to-one room, the members' faces for a group; an organization
    /// room keeps its own symbol.
    @ViewBuilder
    private var roomAvatar: some View {
        if room.isOrganizationRoom {
            Image(systemName: room.profileImage)
                .font(.largeTitle)
                .foregroundStyle(.appPrimary)
                .frame(width: 50, height: 50)
        } else if room.isGroup {
            GroupAvatarView(avatar: GroupAvatar(members: room.memberNames), size: 50)
        } else {
            SenderAvatarView(name: room.name, size: 50)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            roomAvatar

            VStack(alignment: .leading, spacing: 4) {
                nameAndTimeLayout {
                    Text(room.name)
                        .font(.headline)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }

                    Text(room.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                HStack {
                    // A hierarchical style rather than the fixed gray, so the text turns
                    // light on a selected (filled) row instead of fading into it.
                    Text(room.lastMessage.isEmpty ? languageManager.string("Start a conversation") : room.lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if room.unreadCount > 0 {
                        Text("\(room.unreadCount)")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(combinedAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var combinedAccessibilityLabel: String {
        let lastMsg = room.lastMessage.isEmpty
            ? languageManager.string("Start a conversation")
            : room.lastMessage
        var parts = [room.name, lastMsg]
        if room.unreadCount > 0 {
            parts.append(languageManager.string("\(room.unreadCount) unread messages"))
        }
        return parts.joined(separator: ", ")
    }
}

/// A conversation as the chat list opens it. Adding the other person as a friend is the
/// conversation's own banner, so this adds nothing to its toolbar.
struct ChatScreen: View {
    let room: ChatRoom

    var body: some View {
        ChatView(chatRoom: room)
    }
}

#Preview {
    if let container = try? ModelContainer(
        for: ChatRoom.self, Message.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) {
        ChatListView()
            .modelContainer(container)
            .environment(AppRouter())
    } else {
        Text(verbatim: "Preview unavailable")
    }
}
