//
//  ChatView+Input.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import UIKit
import CoreLocation

extension ChatView {
    @ViewBuilder
    func messageInputView(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            // Hidden once the user starts typing their own reply, and during a search, whose
            // results may not include the message the suggestions answer.
            if inputText.isEmpty, searchText.isEmpty, !viewModel.replySuggestions.isEmpty, !voiceService.isRecording {
                replySuggestionsBar(viewModel: viewModel)
            }

            if let replyingTo = replyingToMessage {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(languageManager.string("Replying to \(replyingTo.isFromCurrentUser ? meAsSender : chatRoom.name)"))
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        Text(replyingTo.text)
                            .font(.caption)
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(languageManager.string("Cancel")) {
                        replyingToMessage = nil
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }

            if voiceService.isRecording {
                recordingBannerView
            }

            HStack(spacing: 12) {
                Menu {
                    Button {
                        openPhotosAttachment()
                    } label: {
                        Label(languageManager.string("Photos/Videos"), systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label(languageManager.string(LocalizedStringResource("File", comment: "Names a file message or attachment")), systemImage: "doc")
                    }

                    Button {
                        sendLocation()
                    } label: {
                        Label(languageManager.string("Share Location"), systemImage: "location")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.appPrimaryText)
                        .font(.title)
                        .minimumHitTarget(visibleSize: 28)
                }
                .accessibilityLabel(languageManager.string("Attach file or media"))

                // Glass like the toolbar buttons, so the field reads on any room background, plain
                // or a photo, without a solid panel behind the bar.
                TextField(languageManager.string("Type a message"), text: $inputText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .focused($isTextFieldFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage(viewModel: viewModel)
                    }

                let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                if hasText {
                    Button {
                        scheduledSendDate = Date().addingTimeInterval(3600)
                        showingSchedulePicker = true
                    } label: {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.appPrimaryText)
                            .font(.title2)
                            .minimumHitTarget(visibleSize: 22)
                    }
                    .accessibilityLabel(languageManager.string("Schedule send"))
                    .transition(.scale.combined(with: .opacity))

                    Button {
                        sendMessage(viewModel: viewModel)
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.onAppPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.appPrimary)
                            .clipShape(Circle())
                            .minimumHitTarget(visibleSize: 32)
                    }
                    .accessibilityLabel(languageManager.string("Send message"))
                    .transition(.scale.combined(with: .opacity))
                } else {
                    micButton(viewModel: viewModel)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: inputText.isEmpty)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var recordingBannerView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(voiceService.isRecording ? 1 : 0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: voiceService.isRecording)
            Text(languageManager.string("Recording..."))
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Text(formatRecordingDuration(voiceService.recordingDuration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.secondary)
            Button(languageManager.string("Cancel")) {
                voiceService.cancelRecording()
            }
            .font(.caption)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(.red.opacity(0.15)), in: .capsule)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func micButton(viewModel: ChatViewModel) -> some View {
        Image(systemName: voiceService.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
            .foregroundStyle(voiceService.isRecording ? .white : .onAppPrimary)
            .frame(width: 32, height: 32)
            .background(voiceService.isRecording ? Color.red : Color.appPrimary)
            .clipShape(Circle())
            .scaleEffect(voiceService.isRecording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: voiceService.isRecording)
            .minimumHitTarget(visibleSize: 32)
            .accessibilityLabel(voiceService.isRecording
                ? languageManager.string("Stop and send voice message")
                : languageManager.string("Hold to record voice message"))
            .accessibilityAddTraits(.isButton)
            // VoiceOver and Switch Control can't hold a finger down: activating starts the
            // recording, and activating again stops it and sends it.
            .accessibilityAction {
                if voiceService.isRecording {
                    finishRecording(viewModel: viewModel)
                } else {
                    Task { _ = await voiceService.startRecording() }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !voiceService.isRecording else { return }
                        Task { _ = await voiceService.startRecording() }
                    }
                    .onEnded { _ in
                        // Let go while the recording was still starting: call the start off.
                        guard voiceService.isRecording else {
                            voiceService.cancelRecording()
                            return
                        }
                        finishRecording(viewModel: viewModel)
                    }
            )
    }

    /// Sends what was recorded, unless it was too short to be a message.
    private func finishRecording(viewModel: ChatViewModel) {
        if let (data, duration) = voiceService.stopRecording(), duration > 0.5 {
            viewModel.sendVoiceMessage(audioData: data, duration: duration)
        } else {
            voiceService.cancelRecording()
        }
    }

    private func formatRecordingDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Replies the user can pick instead of typing. A pick goes into the message field rather
    /// than straight out, so it can still be edited.
    func replySuggestionsBar(viewModel: ChatViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.replySuggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        inputText = suggestion
                        isTextFieldFocused = true
                        viewModel.clearReplySuggestions()
                    }
                    .buttonStyle(.glass)
                    .accessibilityHint(languageManager.string("Puts this reply in the message field"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        // A scroll view draws past the safe area; clipped, the replies stop at the edge and
        // don't run under a tab bar or status bar at the side of the screen.
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(languageManager.string("Suggested replies"))
    }

    func sendMessage(viewModel: ChatViewModel) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        viewModel.newMessageText = text
        if let replying = replyingToMessage {
            viewModel.setReplyMessage(replying)
        }
        viewModel.sendMessage()

        inputText = ""
        replyingToMessage = nil
        isTextFieldFocused = false
    }

    func sendLocation() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            showingLocationPermissionAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = locationManager.currentLocation {
                viewModel?.sendLocationMessage(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            } else {
                pendingLocationSend = true
                locationManager.requestLocation()
            }
        default:
            pendingLocationSend = true
            locationManager.requestLocation()
        }
    }
}
