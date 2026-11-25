//
//  MessageBubbleView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import Combine
import SwiftData
import AVFoundation
import QuickLook
import os

private let bubbleLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "MessageBubbleView")

struct MessageBubbleView: View {
    @ScaledMetric(relativeTo: .body) private var playButtonSize: CGFloat = 30
    let message: Message
    /// The code of the sender's language, shown on their avatar, when it isn't the reader's.
    var languageBadge: String?
    /// How to translate a received text message, shown under it in the bubble; nil for none.
    var translation: MessageTranslation?
    /// Whether the time and read receipt show under the bubble: only on the last message of a run.
    var showsTime = true
    /// Hears the translation once it is shown, so the message can be read out with it.
    var onTranslated: ((TranslationState) -> Void)?
    var onAvatarTap: (() -> Void)?
    /// A voice message whose words are still being written down.
    var isTranscribing = false
    /// How the reader stands with the sender, worked out once for the whole conversation
    /// rather than fetched by every bubble. Nil shows nothing, as for the reader's own messages.
    var senderStanding: FriendStanding?
    /// Sends the sender a friend request; throws if it couldn't be saved.
    var onAddFriend: (() throws -> Void)?

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingFullScreenImage = false
    @State private var fullScreenImage: UIImage? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @State private var attachmentPreviewURL: URL?

    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.prefersHighContrast) private var highContrast

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromCurrentUser {
                Spacer()
                messageBubble
            } else {
                avatarView
                messageBubble
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .alert(languageManager.string(LocalizedStringResource("Alert", comment: "Title of a message's notice, such as a sent friend request.")), isPresented: $showingAlert) {
            Button(languageManager.string("OK")) {}
        } message: {
            Text(alertMessage)
        }
        .quickLookPreview($attachmentPreviewURL)
        .sheet(isPresented: $showingFullScreenImage) {
            if let uiImage = fullScreenImage {
                FullScreenImageView(image: uiImage)
                    .environment(languageManager)
            }
        }
    }

    /// Text and icons on your own bubbles, dark on the light brand color.
    private var ownBubbleContent: Color {
        Color.onOwnBubble(highContrast: highContrast)
    }

    private var bubbleBackground: Color {
        if message.isFromCurrentUser {
            return Color.ownBubble(highContrast: highContrast)
        } else {
            return Color.incomingBubble(highContrast: highContrast)
        }
    }

    private var messageBubble: some View {
        VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Adding the sender as a friend is in the context menu, the chat's banner and their
            // profile, not on every message they sent.
            if !message.isFromCurrentUser {
                Text(message.sender)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            // 메시지 타입에 따른 콘텐츠
            messageContent
                .padding(.horizontal, message.messageType == .image ? 4 : 16)
                .padding(.vertical, message.messageType == .image ? 4 : 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(bubbleBackground)
                )
                .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent : .primary)

            if showsTime || hasStatus {
                footer
            }
        }
    }

    /// Bookmarked, disappearing or scheduled: worth showing even where the time is left out.
    private var hasStatus: Bool {
        message.isBookmarked || (message.isDisappearing && message.disappearAfterSeconds > 0) || message.isPendingScheduled
    }

    private var footer: some View {
        HStack(spacing: 4) {
            if showsTime {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }

            if message.isBookmarked {
                Image(systemName: "bookmark.fill")
                    .font(.caption2)
                    .foregroundStyle(.appPrimaryText)
            }

            if message.isDisappearing && message.disappearAfterSeconds > 0 {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if message.isPendingScheduled {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }

            if message.isFromCurrentUser && showsTime {
                Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(message.isRead ? .appPrimaryText : .secondary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var avatarView: some View {
        Button { onAvatarTap?() } label: {
            SenderAvatarView(avatar: SenderAvatar(name: message.sender), languageBadge: languageBadge)
        }
        .buttonStyle(.plain)
        .minimumHitTarget(visibleSize: 36)
        .contextMenu {
            if !message.isFromCurrentUser {
                switch senderStanding {
                case .stranger:
                    Button(languageManager.string(LocalizedStringResource(
                        "Add Friend",
                        comment: "Menu item on a message sender's avatar that sends them a friend request."
                    ))) { addFriend() }
                case .requested:
                    Label(languageManager.string(LocalizedStringResource(
                        "Pending", comment: "Menu item on a sender's avatar: your friend request awaits their answer."
                    )), systemImage: "clock")
                default:
                    EmptyView()
                }
            }
        }
        .accessibilityLabel(languageManager.string("Profile of \(message.sender)"))
    }

    @ViewBuilder
    private var messageContent: some View {
        switch message.messageType {
        case .text:
            if let translation, !message.isFromCurrentUser {
                // A grid, so the divider spans the wider of the two texts without widening the
                // bubble to the screen's edge.
                Grid(alignment: .leading, verticalSpacing: 8) {
                    // A grid cell keeps text to one line unless told to grow downward.
                    Text(message.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                        .gridCellUnsizedAxes(.horizontal)
                    TranslatedTextView(
                        text: message.text, autoDetect: translation.autoDetect, target: translation.target,
                        onResult: onTranslated
                    )
                }
            } else {
                Text(message.text)
                    .multilineTextAlignment(message.isFromCurrentUser ? .trailing : .leading)
            }

        case .image:
            if let imageData = message.imageData,
               let uiImage = UIImage(data: imageData) {
                Button {
                    fullScreenImage = uiImage
                    showingFullScreenImage = true
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                // What the photo shows when it has been described, otherwise just that it is one.
                .accessibilityLabel(message.imageDescription ?? languageManager.string(LocalizedStringResource("Photo", comment: "Spoken label of a photo in a chat bubble.")))
                .accessibilityHint(languageManager.string("Tap to view full screen"))
            } else {
                HStack {
                    Image(systemName: "photo")
                    Text(languageManager.string("Unable to load image"))
                }
                .foregroundStyle(Color.secondary)
            }

        case .video:
            if let videoData = message.videoData {
                Button { openAttachment() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 200, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }

                        Text(languageManager.string("Video (\(AttachmentHandler.formatFileSize(videoData.count)))"))
                            .font(.caption)
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.9) : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(languageManager.string("Tap to open"))
            } else {
                HStack {
                    Image(systemName: "video")
                    Text(languageManager.string("Unable to load video"))
                }
                .foregroundStyle(Color.secondary)
            }

        case .file:
            Button { openAttachment() } label: {
                HStack {
                    Image(systemName: AttachmentHandler.fileIcon(for: message.fileExtension ?? ""))
                        .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent : .appPrimaryText)
                    VStack(alignment: .leading) {
                        Text(message.fileName ?? languageManager.string(LocalizedStringResource("File", comment: "Stands in for the name of a sent file that has none.")))
                            .font(.headline)
                        if let fileSize = message.fileSize {
                            Text(AttachmentHandler.formatFileSize(fileSize))
                                .font(.caption)
                                .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                        }
                    }
                    Spacer()
                }
                .frame(minWidth: 150)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(languageManager.string("Tap to open"))

        case .audio:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Button {
                        toggleAudioPlayback()
                    } label: {
                        Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: playButtonSize))
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent : .appPrimaryText)
                    }
                    .accessibilityLabel(isPlayingAudio
                        ? languageManager.string("Pause voice message")
                        : languageManager.string("Play voice message"))

                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: "waveform")
                            .font(.subheadline)
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                        Text(formatAudioDuration(message.audioDuration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.7) : .secondary)
                    }
                }
                .frame(minWidth: 120, alignment: .leading)

                // Written down on device after sending.
                if let transcript = message.transcript {
                    Text(transcript)
                        .font(.subheadline)
                        .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.9) : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isTranscribing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(message.isFromCurrentUser ? ownBubbleContent : .secondary)
                        Text(languageManager.string("Transcribing…"))
                            .font(.caption)
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                    }
                }
            }

        case .deleted:
            HStack {
                Image(systemName: "trash")
                    .foregroundStyle(Color.secondary)
                Text(languageManager.string("Message deleted"))
                    .foregroundStyle(Color.secondary)
                    .italic()
            }

        case .location:
            if let lat = message.locationLatitude, let lon = message.locationLongitude {
                Button {
                    if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(lat),\(lon)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent : .appPrimaryText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(languageManager.string("Current Location"))
                                .font(.subheadline.bold())
                            Text(String(format: "%.5f, %.5f", lat, lon))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(message.isFromCurrentUser ? ownBubbleContent.opacity(0.8) : .secondary)
                        }
                    }
                    .frame(minWidth: 160)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(languageManager.string("Location shared — tap to open map"))
            } else {
                HStack {
                    Image(systemName: "location.slash")
                    Text(languageManager.string("Location unavailable"))
                }
                .foregroundStyle(Color.secondary)
            }
        }
    }

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.stop()
            isPlayingAudio = false
            return
        }
        guard let data = message.audioData,
              let player = try? AVAudioPlayer(data: data) else { return }
        audioPlayer = player
        isPlayingAudio = true
        Task {
            // The session is switched on away from the main thread, which it can block.
            try? await SharedAudioSession().activate(for: .playback)
            // Stopped, or another playback started, while the session was switching on.
            guard isPlayingAudio, audioPlayer === player else { return }
            player.play()
            try? await Task.sleep(for: .seconds(player.duration + 0.2))
            if audioPlayer === player { isPlayingAudio = false }
        }
    }

    private func openAttachment() {
        do {
            if let url = try AttachmentPreviewer().previewURL(for: message) {
                attachmentPreviewURL = url
                return
            }
        } catch {
            bubbleLogger.error("Failed to prepare attachment preview: \(error.localizedDescription, privacy: .public)")
        }
        alertMessage = languageManager.string("This attachment can no longer be opened.")
        showingAlert = true
    }

    private func formatAudioDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func addFriend() {
        do {
            try onAddFriend?()
            alertMessage = languageManager.string("Friend request sent.")
            showingAlert = true
        } catch {
            // The repository has logged it; the button stays for another try.
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Message.self, ChatRoom.self)

    VStack {
        MessageBubbleView(message: Message(text: "안녕하세요!", isFromCurrentUser: false, sender: "친구"))
        MessageBubbleView(message: Message(text: "안녕하세요! 반갑습니다 😊", isFromCurrentUser: true))
    }
    .padding()
    .modelContainer(container)
}
