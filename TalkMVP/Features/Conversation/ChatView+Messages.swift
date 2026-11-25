//
//  ChatView+Messages.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import NaturalLanguage
import SwiftData
import UIKit
import os

private let messagesLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatView.Messages")

extension ChatView {
    @ViewBuilder
    func chatContentView(viewModel: ChatViewModel) -> some View {
        // The input floats over the conversation instead of sitting on a panel of its own: the
        // room's background runs to the bottom of the screen, and messages scroll under the bar,
        // where the system softens them.
        messagesScrollView(viewModel: viewModel)
            .safeAreaBar(edge: .bottom) {
                messageInputView(viewModel: viewModel)
            }
    }

    @ViewBuilder
    func messagesScrollView(viewModel: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    // Pagination trigger: appears when the user scrolls to the top
                    if viewModel.hasMoreMessages {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .onAppear {
                                Task { await viewModel.loadMoreMessages() }
                            }
                    }

                    searchStatus(viewModel: viewModel)

                    messagesList(viewModel: viewModel)

                    if viewModel.otherUserTyping {
                        TypingIndicatorView(senderName: chatRoom.name)
                            .id("typing_indicator")
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            .accessibilityLabel(languageManager.string("\(chatRoom.name) is typing"))
                            .accessibilityIdentifier("typingIndicator")
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            // At the accessibility text sizes the title and the reply suggestions are big enough
            // that large message text sliding under their soft edge reads through them; a hard
            // edge keeps them legible.
            .scrollEdgeEffectStyle(dynamicTypeSize.isAccessibilitySize ? .hard : .soft, for: [.top, .bottom])
            // A translation arriving makes a bubble taller after the chat has scrolled to the
            // newest message; anchored at the bottom, that message stays in view instead of
            // sliding under the message field.
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .accessibilityLabel(languageManager.string(LocalizedStringResource("Messages", comment: "VoiceOver name for the list of messages in a chat")))
            .accessibilityHint(languageManager.string("Scroll up and down to review messages"))
            .accessibilityIdentifier("messagesScrollView")
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottomInline(proxy: proxy)
            }
            .onChange(of: viewModel.otherUserTyping) { _, isTyping in
                if isTyping {
                    scrollToBottomInline(proxy: proxy)
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
    }

    func scrollToBottomInline(proxy: ScrollViewProxy) {
        let animation: Animation = reduceMotion ?
            .easeInOut(duration: 0.1) :
            .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.2)

        if let lastMessage = viewModel?.messages.last {
            withAnimation(animation) {
                proxy.scrollTo(lastMessage.id, anchor: UnitPoint.bottom)
            }
        } else if viewModel?.otherUserTyping == true {
            withAnimation(animation) {
                proxy.scrollTo("typing_indicator", anchor: UnitPoint.bottom)
            }
        }
    }

    @ViewBuilder
    func messagesList(viewModel: ChatViewModel) -> some View {
        let badges = languageBadges(in: viewModel.messages)
        let shown = filteredMessages(viewModel: viewModel)
        let runEnds = MessageRuns.runEnds(in: shown.map {
            MessageRuns.Item(id: $0.id, sender: $0.sender, isFromCurrentUser: $0.isFromCurrentUser, timestamp: $0.timestamp)
        })
        ForEach(shown, id: \.id) { message in
            bubble(for: message, viewModel: viewModel, languageBadge: badges[message.sender], showsTime: runEnds.contains(message.id))
                .id(message.id)
                .scaleEffect(poppingMessageIds.contains(message.id) ? 1.18 : 1.0)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: reduceMotion
                        ? .opacity
                        : .scale(scale: 0.01).combined(with: .opacity)
                ))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("message_\(message.id)")
                .accessibilityLabel(accessibilityLabelForMessage(message))
                .accessibilityHint(languageManager.string("Long press for reactions, swipe to reply"))
                // Holding a message opens its menu, which has Add Reaction. A second long-press
                // gesture for the reactions raced the menu, so a hold opened either one.
                .swipeToReply(replyLabel) {
                    replyingToMessage = message
                    isTextFieldFocused = true
                }
                .contextMenu { messageMenu(for: message) }
            if message.messageType == .text, let url = firstURL(in: message.text) {
                LinkPreviewView(url: url)
                    .frame(maxWidth: 280, maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, alignment: message.isFromCurrentUser ? Alignment.trailing : Alignment.leading)
                    .padding(.horizontal, 2)
            }
        }
    }

    /// One message's bubble, with what it needs from the chat.
    private func bubble(for message: Message, viewModel: ChatViewModel, languageBadge: String?, showsTime: Bool) -> MessageBubbleView {
        MessageBubbleView(
            message: message,
            languageBadge: message.isFromCurrentUser ? nil : languageBadge,
            translation: translation(for: message),
            showsTime: showsTime,
            onTranslated: { translatedTexts[message.id] = $0 },
            onAvatarTap: { openProfile(of: message.sender) },
            isTranscribing: viewModel.transcribingMessageIDs.contains(message.id),
            senderStanding: message.isFromCurrentUser ? nil : senderStandings.map { $0[message.sender] ?? .stranger },
            onAddFriend: { try sendFriendRequest(toSender: message.sender) }
        )
    }

    /// The menu a message opens when held.
    @ViewBuilder
    private func messageMenu(for message: Message) -> some View {
        if message.messageType == .text {
            Button(languageManager.string(LocalizedStringResource("Copy", comment: "Copies a message's text")), systemImage: "doc.on.doc") {
                UIPasteboard.general.string = message.text
                UIAccessibility.post(notification: .announcement, argument: languageManager.string("Message copied"))
            }
        }
        Button(replyLabel, systemImage: "arrowshape.turn.up.left") {
            replyingToMessage = message
            isTextFieldFocused = true
        }
        Button(languageManager.string("Add Reaction"), systemImage: "face.smiling") {
            showReactionPicker(for: message)
        }
        Button(
            message.isBookmarked
                ? languageManager.string("Remove Bookmark")
                : languageManager.string(LocalizedStringResource("Bookmark", comment: "Command that bookmarks a message")),
            systemImage: message.isBookmarked ? "bookmark.slash" : "bookmark"
        ) {
            toggleBookmark(message)
        }
        if message.isFromCurrentUser {
            Button(languageManager.string(LocalizedStringResource("Edit", comment: "Command that edits a message")), systemImage: "pencil") {
                startEditingMessage(message)
            }
            Divider()
            Button(languageManager.string("Delete for Me"), systemImage: "trash") {
                deleteMessageForMe(message)
            }
            Button(languageManager.string("Delete for Everyone"), systemImage: "trash.fill", role: .destructive) {
                deleteMessageForEveryone(message)
            }
        } else {
            Button(languageManager.string("Delete for Me"), systemImage: "trash") {
                deleteMessageForMe(message)
            }
            Divider()
            Button(languageManager.string(LocalizedStringResource("Report", comment: "Reports the person a chat is with")), systemImage: "exclamationmark.bubble") {
                showingReportAlert = true
            }
            if isBlocked {
                Button(languageManager.string(LocalizedStringResource("Unblock", comment: "Command that unblocks the other person")), systemImage: "hand.raised.slash") {
                    unblockUser()
                }
            } else {
                Button(languageManager.string(LocalizedStringResource("Block", comment: "Blocks the person a chat is with")), systemImage: "hand.raised") {
                    showingBlockAlert = true
                }
            }
        }
    
    }

    /// The swipe's and the menu's name for replying to a message.
    private var replyLabel: String {
        languageManager.string(LocalizedStringResource("Reply", comment: "Command that replies to a message"))
    }

    /// Whether this chat translates: its own choice, or the app's setting.
    var isTranslatingHere: Bool {
        TranslationPreferences.isOn(inChat: chatRoom.translatesMessages, appSetting: translationEnabled)
    }

    /// Turns translation on or off for this chat alone, from its menu.
    var translationHereBinding: Binding<Bool> {
        Binding(
            get: { isTranslatingHere },
            set: { on in
                chatRoom.translatesMessages = on
                do { try modelContext.save() } catch {
                    messagesLogger.error("Failed to save the chat's translation choice: \(error.localizedDescription, privacy: .public)")
                }
            }
        )
    }

    /// How a received text message in another language is translated, or nil when it isn't.
    func translation(for message: Message) -> MessageTranslation? {
        guard !message.isFromCurrentUser, message.messageType == .text, shouldShowTranslation(for: message.text) else { return nil }
        return MessageTranslation(autoDetect: translationAutoDetect, target: effectiveTargetLanguage(for: message.text))
    }

    /// Each sender's language badge, read once for the whole chat from their own messages.
    func languageBadges(in messages: [Message]) -> [String: String] {
        let conversation = messages.suffix(100).map(SummaryMessage.init)
        let reader = appLanguageCode()
        var badges: [String: String] = [:]
        for sender in Set(conversation.filter { !$0.isFromCurrentUser }.map(\.sender)) {
            let language = ConversationLanguage.of(sender: sender, in: conversation)?.rawValue
            badges[sender] = SenderAvatar.languageBadge(senderLanguage: language, readerLanguage: reader)
        }
        return badges
    }

    func containsHangul(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0xAC00...0xD7A3).contains(value)
        }
    }

    func detectLanguageCode(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let lang = recognizer.dominantLanguage {
            return normalizeLanguageCode(lang.rawValue.lowercased())
        }
        return nil
    }

    func normalizeLanguageCode(_ code: String) -> String {
        switch code {
        case "zh-hans", "zh_cn", "zh": return "zh-Hans"
        case "zh-hant", "zh_tw": return "zh-Hant"
        default: return code
        }
    }

    func appLanguageCode() -> String {
        switch languageManager.currentLanguage {
        case .korean: return "ko"
        case .english: return "en"
        case .japanese: return "ja"
        case .chinese: return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        case .spanish: return "es"
        }
    }

    func shouldShowTranslation(for text: String) -> Bool {
        guard isTranslatingHere else { return false }

        let source = detectLanguageCode(for: text) ?? ""
        let target = effectiveTargetLanguage(for: text).lowercased()
        if !source.isEmpty {
            return source != target
        } else {
            if languageManager.currentLanguage != .korean && containsHangul(text) { return true }
            return false
        }
    }

    func filteredMessages(viewModel: ChatViewModel) -> [Message] {
        viewModel.searchResults(for: searchText)
    }

    /// While searching: that related words are being looked up, which ones were, and when
    /// nothing matches, that nothing did.
    @ViewBuilder
    func searchStatus(viewModel: ChatViewModel) -> some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            VStack(spacing: 8) {
                Group {
                    if viewModel.isExpandingSearch {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(languageManager.string("Searching by meaning…"))
                        }
                    } else if !viewModel.relatedSearchTerms.isEmpty {
                        Text(languageManager.string("Also searched for: \(viewModel.relatedSearchTerms.joined(separator: ", "))"))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                if !viewModel.isExpandingSearch && viewModel.searchResults(for: query).isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    func effectiveTargetLanguage(for text: String) -> String {
        let target = translationTargetLanguage.lowercased()
        if target != "auto" { return target }
        return appLanguageCode()
    }
}
