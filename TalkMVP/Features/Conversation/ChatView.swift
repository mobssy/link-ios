//
//  ChatView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import Combine
import SwiftData
import PhotosUI
import Photos
import UniformTypeIdentifiers
import LinkPresentation
import NaturalLanguage
import UIKit

struct ChatView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.screenSafeArea) private var screenSafeArea
    @Environment(\.prefersReducedMotion) var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(LanguageManager.self) var languageManager

    let chatRoom: ChatRoom

    // MARK: - View Model
    // Internal (not private) so the ChatView extensions in other files can install it.
    @State var viewModel: ChatViewModel?
    @State var chatService: ChatService

    // MARK: - Input
    @FocusState var isTextFieldFocused: Bool
    @State var inputText: String = ""
    @State var replyingToMessage: Message?

    // MARK: - Message Actions
    @State var reactionToMessage: Message?
    /// The appearance this chat's own background calls for; see `ChatBackgroundAppearance`.
    @State private var backgroundColorScheme: ColorScheme?
    /// How each message's translation ended, for reading it out with the message.
    @State var translatedTexts: [UUID: TranslationState] = [:]
    @State var showingReactionPicker = false
    @State var editingMessage: Message?
    @State var showingEditAlert = false
    @State var editingText: String = ""

    // MARK: - Attachments
    @State var pendingAttachment: PendingAttachment?
    @State var showingAttachmentPreview = false
    @State var showingPhotosPicker = false
    @State var showingDocumentPicker = false

    // MARK: - Friends
    @State var isFriend = false
    @State var friendRequestSent = false
    @State var isBlocked = false
    @State var showingAddFriendAlert = false
    @State var addFriendEmail = ""
    @State var showingFriendProfile = false
    @State var profileFriendship: Friendship?
    /// The group member whose profile is open, with their friendship if they are a friend.
    @State var profileMember: (name: String, friendship: Friendship?)?
    /// How the user stands with each sender in this conversation, by name: one fetch for
    /// every bubble. Nil until loaded.
    @State var senderStandings: [String: FriendStanding]?

    // MARK: - Search & Summary
    @State var searchText: String = ""
    /// Whether the search field is on screen; it shows only when Search is chosen.
    @State var isSearchShown = false
    @State var showingGroupInfo = false
    @State var showingSummarySheet = false
    @State var showingMeetingNotes = false
    /// The summary and meeting notes, as the two sheets show them.
    @State var aiResults = ChatAIResults()

    // MARK: - Bookmarks
    @State var showingBookmarks = false

    // MARK: - Scheduled Send
    @State var showingSchedulePicker = false
    @State var scheduledSendDate = Date()

    // MARK: - Disappearing Messages
    @State var showingDisappearingPicker = false
    @State var poppingMessageIds: Set<UUID> = []

    // MARK: - Voice Recording
    @State var voiceService = VoiceMessageService()

    // MARK: - Location
    @State var locationManager = LocationManager()
    @State var pendingLocationSend = false

    // MARK: - Moderation
    @State var showingReportAlert = false
    @State var showingBlockAlert = false

    // MARK: - Background & Presentation
    @State var showingBackgroundSettings = false
    @State var showingLocationPermissionAlert = false

    // MARK: - AI Settings
    @AppStorage(AIFeatureSettings.summary.key) var aiSummaryEnabled = AIFeatureSettings.summary.defaultValue
    @AppStorage(AIFeatureSettings.meetingNotes.key) var aiAutoMeetingNotesEnabled = AIFeatureSettings.meetingNotes.defaultValue

    // MARK: - Translation Settings
    @AppStorage(TranslationPreferences.enabledKey) var translationEnabled = TranslationPreferences.enabledByDefault
    @AppStorage("translationAutoDetect") var translationAutoDetect = true
    @AppStorage("translationTargetLanguage") var translationTargetLanguage = "auto"

    // MARK: - Date Formatters (cached, internal so extensions can access via Self.)
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        return formatter
    }()

    // Shared in-memory context used only during init — replaced by the environment's
    // shared context in setupViewModelIfNeeded() before any real I/O happens.
    private static let initServiceContext: ModelContext = {
        let schema = Schema([Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Cannot create ChatService initialization container")
        }
        return container.mainContext
    }()

    init(chatRoom: ChatRoom, chatService: ChatService? = nil) {
        self.chatRoom = chatRoom
        self._chatService = State(initialValue: chatService ?? ChatService(modelContext: Self.initServiceContext))
    }

    // MARK: - Summary Sheet

    @ViewBuilder
    private var summarySheetContent: some View {
        if aiResults.isSummaryLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(summaryLoadingText)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // The sheet's title names it; the first line says when it was written and
                    // how much it read, marked as the on-device model's work.
                    if summaryParagraphs.count > 1, let heading = summaryParagraphs.first {
                        Label(heading, systemImage: "apple.intelligence")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                    ForEach(summaryParagraphs.count > 1 ? Array(summaryParagraphs.dropFirst()) : summaryParagraphs, id: \.self) { paragraph in
                        SummaryParagraphCard(text: paragraph)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
    }

    private var summaryLoadingText: String {
        switch aiResults.summaryProgress {
        case .readingPart(let index, let count):
            languageManager.string("Reading a long chat in parts… (\(index)/\(count))")
        case .writing:
            languageManager.string("Writing the summary…")
        case nil:
            languageManager.string("Generating summary...")
        }
    }

    private var summaryParagraphs: [String] {
        aiResults.summaryText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Body

    private var baseScaffold: some View {
        VStack(spacing: 0) {
            FriendBannerView(banner: friendBanner, name: chatRoom.name) {
                showingAddFriendAlert = true
            }

            mainContentView
        }
        .modifier(ChatBackgroundColorScheme(scheme: backgroundColorScheme))
        .task(id: chatRoom.backgroundAppearanceKey) {
            backgroundColorScheme = chatRoom.backgroundColorScheme
        }
        .safeAreaInset(edge: .top) {
            if showsTitleAboveMessages {
                Button(action: openTitle) {
                    titleView
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .padding(.top, 8)
            }
        }
        .navigationTitle(chatRoom.name)
        .navigationBarTitleDisplayMode(.inline)
        // As in Messages, a conversation on a phone has the screen to itself: its bottom edge
        // is the input field. Wide windows keep the tabs beside the chat list.
        .toolbar(horizontalSizeClass == .compact ? .hidden : .automatic, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // As in Messages, the name at the top opens what the chat is about.
                Button(action: openTitle) { titleView }
                    .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // The message field lets go first, or the two fight over the keyboard
                        // and the search field never gets it.
                        isTextFieldFocused = false
                        isSearchShown = true
                    } label: {
                        Label(languageManager.string(LocalizedStringResource("Search", comment: "Menu command that shows the search field")), systemImage: "magnifyingglass")
                    }

                    Toggle(isOn: translationHereBinding) {
                        Label(languageManager.string("Translate Messages"), systemImage: "translate")
                    }

                    Button {
                        showingBackgroundSettings = true
                    } label: {
                        Label(languageManager.string(LocalizedStringResource("Background", comment: "Menu command that opens this chat's background settings")), systemImage: "photo.fill")
                    }

                    Button {
                        toggleChatNotifications()
                    } label: {
                        Label(
                            chatRoom.notificationsEnabled ?
                                languageManager.string(LocalizedStringResource("Mute", comment: "Menu command that turns off this chat's notifications")) :
                                languageManager.string(LocalizedStringResource("Unmute", comment: "Menu command that turns this chat's notifications back on")),
                            systemImage: chatRoom.notificationsEnabled ? "bell.slash.fill" : "bell.fill"
                        )
                    }

                    Button {
                        showingBookmarks = true
                    } label: {
                        Label(languageManager.string("Bookmarks"), systemImage: "bookmark")
                    }

                    Button {
                        showingDisappearingPicker = true
                    } label: {
                        Label(languageManager.string(LocalizedStringResource("Disappearing", comment: "Menu command that opens the disappearing-messages timer")), systemImage: "flame")
                    }

                    if aiSummaryEnabled {
                        Button {
                            generateSummary()
                        } label: {
                            Label(languageManager.string("Summarize"), systemImage: "text.quote")
                        }
                    }

                    if aiAutoMeetingNotesEnabled {
                        Button {
                            generateMeetingNotes()
                        } label: {
                            Label(languageManager.string("Meeting Notes"), systemImage: "note.text")
                        }
                    }

                    if isBlocked && chatRoom.otherUserId != nil {
                        Button {
                            unblockUser()
                        } label: {
                            Label(languageManager.string(LocalizedStringResource("Unblock", comment: "Command that unblocks the other person")), systemImage: "hand.raised.slash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.appPrimaryText)
                        .accessibilityLabel(languageManager.string("More options"))
                }
            }
        }
        .background(chatRoomBackground)
        .onAppear {
            setupViewModelIfNeeded()
            checkIfFriend()
            loadSenderStandings()
            markMessagesAsRead()
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                self.handleDocumentSelection(url)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingReactionPicker) {
            ReactionPickerView(message: reactionToMessage) { emoji in
                if let message = reactionToMessage {
                    addReaction(emoji: emoji, to: message)
                }
                showingReactionPicker = false
            }
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
    }

    private var allAlertModifiers: some ViewModifier {
        CompoundAlertModifier(
            showingEditAlert: $showingEditAlert,
            editingText: $editingText,
            editingMessage: $editingMessage,
            showingLocationPermissionAlert: $showingLocationPermissionAlert,
            showingReportAlert: $showingReportAlert,
            showingBlockAlert: $showingBlockAlert,
            chatRoomName: chatRoom.name,
            openURL: { url in openURL(url) },
            onEditSave: { message, newText in
                viewModel?.editMessage(message, newText: newText)
            },
            onBlock: {
                blockUser()
            }
        )
    }

    var body: some View {
        baseScaffold
            .modifier(allAlertModifiers)
            .alert(addFriendAlertTitle, isPresented: $showingAddFriendAlert) {
                Button(languageManager.string("Cancel"), role: .cancel) {}
                Button(languageManager.string(LocalizedStringResource("Add", comment: "Button that sends the friend request"))) {
                    requestFriendship()
                }
            } message: {
                Text(languageManager.string("Add \(chatRoom.name) as a friend?"))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(languageManager.string("Chat Screen"))
            .accessibilityHint(languageManager.string("Chat with \(chatRoom.name)"))
            .accessibilityIdentifier("chatView")
            .alert(
                languageManager.string("Error"),
                isPresented: Binding(
                    get: { viewModel?.errorMessage != nil },
                    set: { if !$0 { viewModel?.errorMessage = nil } }
                )
            ) {
                Button(languageManager.string("OK")) { viewModel?.errorMessage = nil }
            } message: {
                Text(viewModel?.errorMessage ?? "")
            }
            .modifier(SearchWhenShown(text: $searchText, isShown: $isSearchShown, prompt: languageManager.string("Search conversation")))
            .task(id: searchText) { await viewModel?.expandSearch(for: searchText) }
            .sheet(isPresented: $showingSummarySheet) {
                NavigationStack {
                    summarySheetContent
                        .navigationTitle(languageManager.string("Conversation Summary"))
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(languageManager.string("Done")) { showingSummarySheet = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingMeetingNotes) {
                NavigationStack {
                    MeetingNotesView(notes: aiResults.meetingNotes, isLoading: aiResults.isMeetingNotesLoading)
                        .navigationTitle(MeetingNotesView.labels(languageManager).title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                if let notes = aiResults.meetingNotes, !aiResults.isMeetingNotesLoading, !notes.isEmpty {
                                    ShareLink(item: notes.shareText(labels: MeetingNotesView.labels(languageManager)))
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(languageManager.string("Done")) { showingMeetingNotes = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingFriendProfile) {
                if let profileMember {
                    if let friendship = profileMember.friendship {
                        NavigationStack { FriendProfileView(friendship: friendship, showsCloseButton: true) }
                    } else {
                        MiniProfileSheet(
                            name: profileMember.name,
                            standing: senderStandings?[profileMember.name] ?? .stranger,
                            onAddFriend: { try sendFriendRequest(toSender: profileMember.name) }
                        )
                        .environment(languageManager)
                    }
                } else if let friendship = profileFriendship {
                    NavigationStack { FriendProfileView(friendship: friendship, isInChatWithThisPerson: true, showsCloseButton: true) }
                } else {
                    MiniProfileSheet(
                        name: chatRoom.name,
                        standing: oneToOneStanding,
                        onAddFriend: { try sendFriendRequestToOtherSide() }
                    )
                    .environment(languageManager)
                }
            }
            .sheet(isPresented: $showingGroupInfo) {
                GroupInfoSheet(
                    name: chatRoom.name,
                    members: chatRoom.memberNames,
                    languageBadges: languageBadges(in: viewModel?.messages ?? []),
                    standings: senderStandings ?? [:],
                    onAddFriend: { try sendFriendRequest(toSender: $0) }
                )
                .environment(languageManager)
            }
            .sheet(isPresented: $showingPhotosPicker) {
                PhotoPickerView { selectedItems in
                    handlePhotoPickerSelection(selectedItems)
                }
            }
            .fullScreenCover(isPresented: $showingAttachmentPreview) {
                AttachmentPreviewView(
                    attachment: pendingAttachment,
                    onSend: sendPendingAttachment,
                    onCancel: cancelPendingAttachment
                )
                .environment(languageManager)
            }
            .sheet(isPresented: $showingBackgroundSettings) {
                ChatRoomBackgroundSettings(chatRoom: chatRoom)
                    .environment(languageManager)
            }
            .sheet(isPresented: $showingBookmarks) {
                BookmarkedMessagesSheet(
                    messages: viewModel?.messages.filter { $0.isBookmarked } ?? [],
                    chatRoomName: chatRoom.name,
                    onDismiss: { showingBookmarks = false }
                )
                .environment(languageManager)
            }
            .sheet(isPresented: $showingDisappearingPicker) {
                DisappearingMessagePickerSheet(
                    chatRoom: chatRoom,
                    onDismiss: { showingDisappearingPicker = false }
                )
                .environment(languageManager)
            }
            .sheet(isPresented: $showingSchedulePicker) {
                ScheduledSendSheet(
                    scheduledDate: $scheduledSendDate,
                    onConfirm: { date in
                        if let vm = viewModel {
                            scheduleMessage(viewModel: vm, sendAt: date)
                        }
                        showingSchedulePicker = false
                    },
                    onCancel: { showingSchedulePicker = false }
                )
                .environment(languageManager)
            }
            .onChange(of: locationManager.currentLocation) { _, location in
                guard pendingLocationSend, let location else { return }
                pendingLocationSend = false
                viewModel?.sendLocationMessage(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            .task {
                while !Task.isCancelled {
                    checkDisappearingMessages()
                    viewModel?.sendDueScheduledMessages()
                    try? await Task.sleep(for: .seconds(15))
                }
            }
    }

    // MARK: - Title

    /// With the status bar down one side of a wide screen (iPhone Duo open, in landscape) the
    /// system stacks the toolbar under it and leaves out the principal item, so the chat would
    /// have no name. The title then sits above the messages instead.
    private var showsTitleAboveMessages: Bool {
        horizontalSizeClass == .regular && screenSafeArea.hasStatusStripOnOneSide
    }

    /// The name, and under it what the app knows about the chat: a group's members, or the
    /// language the other person writes in.
    private var titleView: some View {
        VStack(spacing: 1) {
            Text(chatRoom.name)
                .font(.headline)
            if let chatSubtitle {
                Text(chatSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chatSubtitle: String? {
        let received = (viewModel?.messages ?? []).suffix(20).map(SummaryMessage.init)
        return ChatSubtitle.text(
            isGroup: chatRoom.isGroup,
            memberNames: chatRoom.memberNames,
            partnerLanguage: ConversationLanguage.of(sender: nil, in: received)?.rawValue,
            readerLanguage: appLanguageCode(),
            isTranslating: isTranslatingHere,
            translatedLabel: languageManager.string(LocalizedStringResource("Translated", comment: "Says a message is shown translated")),
            originalLabel: languageManager.string(LocalizedStringResource("Original", comment: "Says messages are shown as written, not translated"))
        )
    }

    private var addFriendAlertTitle: String {
        languageManager.string(LocalizedStringResource(
            "Add Friend",
            comment: "Title of the alert that asks before sending a friend request"
        ))
    }


    // MARK: - Background

    @ViewBuilder
    private var chatRoomBackground: some View {
        switch chatRoom.backgroundType {
        case "color":
            if let hexColor = chatRoom.backgroundColor,
               let color = Color(hex: hexColor) {
                color.ignoresSafeArea()
            } else {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            }

        case "gradient":
            if let startHex = chatRoom.gradientStartColor,
               let endHex = chatRoom.gradientEndColor,
               let startColor = Color(hex: startHex),
               let endColor = Color(hex: endHex) {
                LinearGradient(
                    colors: [startColor, endColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            }

        case "image":
            if let imageData = chatRoom.backgroundImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            }

        default:
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var mainContentView: some View {
        if let viewModel = viewModel {
            chatContentView(viewModel: viewModel)
        } else {
            ProgressView(languageManager.string("Loading..."))
        }
    }
}
