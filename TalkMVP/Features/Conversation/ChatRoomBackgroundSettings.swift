//
//  ChatRoomBackgroundSettings.swift
//  TalkMVP
//
//  Chat room background customization view
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import SwiftData
import PhotosUI
import os

private let backgroundLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatRoomBackgroundSettings")

struct ChatRoomBackgroundSettings: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.prefersHighContrast) private var highContrast

    let chatRoom: ChatRoom

    @State private var selectedBackgroundType: BackgroundType
    @State private var selectedColor: Color
    @State private var gradientStart: Color
    @State private var gradientEnd: Color
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var showingResetConfirmation = false

    enum BackgroundType: String, CaseIterable {
        case `default`
        case color
        case gradient
        case image

        var title: LocalizedStringResource {
            switch self {
            case .default: LocalizedStringResource("Default", comment: "Chat background type: the system's own background.")
            case .color: "Solid Color"
            case .gradient: LocalizedStringResource("Gradient", comment: "Chat background type: a blend of two colors.")
            case .image: LocalizedStringResource("Image", comment: "Chat background type: a photo picked by the user.")
            }
        }

        func icon() -> String {
            switch self {
            case .default: return "circle"
            case .color: return "paintpalette.fill"
            case .gradient: return "circle.lefthalf.filled"
            case .image: return "photo.fill"
            }
        }
    }

    init(chatRoom: ChatRoom) {
        self.chatRoom = chatRoom

        // Initialize state based on current settings
        let bgType = BackgroundType(rawValue: chatRoom.backgroundType) ?? .default
        _selectedBackgroundType = State(initialValue: bgType)

        let color = Color(hex: chatRoom.backgroundColor ?? "#FFFFFF") ?? .white
        _selectedColor = State(initialValue: color)

        let gradStart = Color(hex: chatRoom.gradientStartColor ?? "#4A90E2") ?? .blue
        _gradientStart = State(initialValue: gradStart)

        let gradEnd = Color(hex: chatRoom.gradientEndColor ?? "#50E3C2") ?? .green
        _gradientEnd = State(initialValue: gradEnd)

        if let imageData = chatRoom.backgroundImageData,
           let image = UIImage(data: imageData) {
            _previewImage = State(initialValue: image)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview Section
                    previewSection

                    // Background Type Selection
                    backgroundTypeSection

                    // Type-specific settings
                    switch selectedBackgroundType {
                    case .default:
                        defaultBackgroundInfo
                    case .color:
                        colorPickerSection
                    case .gradient:
                        gradientPickerSection
                    case .image:
                        imagePickerSection
                    }

                    // Reset Button
                    resetButton
                }
                .padding()
            }
            .navigationTitle(languageManager.string("Chat Background"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.string("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.string("Save")) {
                        saveSettings()
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newValue in
                loadImage(from: newValue)
            }
        }
    }

    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(languageManager.string(LocalizedStringResource("Preview", comment: "Heading over a sample of how the chat background will look.")))
                .font(.headline)
                .padding(.horizontal, 4)

            ZStack {
                // Background
                backgroundPreview

                // Sample messages
                VStack(spacing: 12) {
                    Spacer()

                    // Received message
                    HStack {
                        messageBubble(text: languageManager.string("Hello! This is a sample message."), isFromCurrentUser: false)
                        Spacer()
                    }

                    // Sent message
                    HStack {
                        Spacer()
                        messageBubble(text: languageManager.string("Hello! This is a sample message."), isFromCurrentUser: true)
                    }
                }
                .padding()
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var backgroundPreview: some View {
        switch selectedBackgroundType {
        case .default:
            Color(UIColor.systemGroupedBackground)
        case .color:
            selectedColor
        case .gradient:
            LinearGradient(
                colors: [gradientStart, gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .image:
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(UIColor.systemGroupedBackground)
            }
        }
    }

    private func messageBubble(text: String, isFromCurrentUser: Bool) -> some View {
        Text(text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isFromCurrentUser ? Color.ownBubble(highContrast: highContrast) : Color(UIColor.secondarySystemGroupedBackground))
            .foregroundStyle(isFromCurrentUser ? Color.onOwnBubble(highContrast: highContrast) : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Background Type Section
    private var backgroundTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.string("Background Type"))
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(BackgroundType.allCases, id: \.self) { type in
                    Button {
                        selectedBackgroundType = type
                    } label: {
                        HStack {
                            Image(systemName: type.icon())
                                .foregroundStyle(.appPrimaryText)
                                .frame(width: 24)

                            Text(languageManager.string(type.title))
                                .foregroundStyle(Color.primary)

                            Spacer()

                            if selectedBackgroundType == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.appPrimaryText)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(selectedBackgroundType == type ? Color.appPrimary.opacity(0.1) : Color.clear)
                    }
                    .accessibilityAddTraits(selectedBackgroundType == type ? .isSelected : [])

                    if type != BackgroundType.allCases.last {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Default Background Info
    private var defaultBackgroundInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.tint)
                Text(languageManager.string("Using system default background"))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Color Picker Section
    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.string("Choose Color"))
                .font(.headline)
                .padding(.horizontal, 4)

            ColorPicker(languageManager.string("Choose Color"), selection: $selectedColor, supportsOpacity: false)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Gradient Picker Section
    private var gradientPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.string("Gradient Start"))
                .font(.headline)
                .padding(.horizontal, 4)

            ColorPicker(languageManager.string("Gradient Start"), selection: $gradientStart, supportsOpacity: false)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(languageManager.string("Gradient End"))
                .font(.headline)
                .padding(.horizontal, 4)

            ColorPicker(languageManager.string("Gradient End"), selection: $gradientEnd, supportsOpacity: false)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Image Picker Section
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.string("Choose Image"))
                .font(.headline)
                .padding(.horizontal, 4)

            Button {
                showingPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.appPrimaryText)
                    Text(languageManager.string("Choose Image"))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Reset Button
    private var resetButton: some View {
        Button(role: .destructive) {
            showingResetConfirmation = true
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text(languageManager.string("Reset"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .alert(languageManager.string("Reset"), isPresented: $showingResetConfirmation) {
            Button(languageManager.string("Cancel"), role: .cancel) {}
            Button(languageManager.string("Reset"), role: .destructive) {
                resetToDefault()
            }
        } message: {
            Text(languageManager.string("Reset background to default?"))
        }
    }

    // MARK: - Helper Functions
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    previewImage = image
                }
            } catch {
                backgroundLogger.error("Failed to load image: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func saveSettings() {
        chatRoom.backgroundType = selectedBackgroundType.rawValue

        switch selectedBackgroundType {
        case .default:
            chatRoom.backgroundColor = nil
            chatRoom.backgroundImageData = nil
            chatRoom.gradientStartColor = nil
            chatRoom.gradientEndColor = nil

        case .color:
            chatRoom.backgroundColor = selectedColor.toHex()
            chatRoom.backgroundImageData = nil
            chatRoom.gradientStartColor = nil
            chatRoom.gradientEndColor = nil

        case .gradient:
            chatRoom.gradientStartColor = gradientStart.toHex()
            chatRoom.gradientEndColor = gradientEnd.toHex()
            chatRoom.backgroundColor = nil
            chatRoom.backgroundImageData = nil

        case .image:
            if let image = previewImage,
               let imageData = image.jpegData(compressionQuality: 0.7) {
                chatRoom.backgroundImageData = imageData
            }
            chatRoom.backgroundColor = nil
            chatRoom.gradientStartColor = nil
            chatRoom.gradientEndColor = nil
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            backgroundLogger.error("Failed to save background settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resetToDefault() {
        selectedBackgroundType = .default
        selectedColor = .white
        gradientStart = .blue
        gradientEnd = .green
        previewImage = nil
        selectedPhotoItem = nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ChatRoom.self, configurations: config)
    let chatRoom = ChatRoom(name: "테스트 채팅방")
    container.mainContext.insert(chatRoom)

    return NavigationStack {
        ChatRoomBackgroundSettings(chatRoom: chatRoom)
            .environment(LanguageManager())
            .modelContainer(container)
    }
}
