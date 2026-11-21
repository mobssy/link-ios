//
//  ProfileEditView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var languageManager
    var authManager: AuthManager

    @State private var displayName: String
    @State private var statusMessage: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var didRemovePhoto = false

    init(authManager: AuthManager) {
        self.authManager = authManager
        self._displayName = State(initialValue: authManager.currentUser?.displayName ?? "")
        self._statusMessage = State(initialValue: authManager.currentUser?.statusMessage ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 프로필 이미지
                    HStack {
                        Spacer()

                        let currentUserImageData = authManager.currentUser?.profileImageData

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                Group {
                                    if let profileImage = profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else if !didRemovePhoto, let imageData = currentUserImageData,
                                              let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else {
                                        // The face the user has everywhere until they pick a photo.
                                        SenderAvatarView(name: displayName, size: 100)
                                    }
                                }

                                // Camera badge overlay
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 28, height: 28)
                                    Circle()
                                        .fill(Color.appPrimary)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.onAppPrimary)
                                        )
                                }
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                .offset(x: -3, y: -3)
                                .accessibilityHidden(true)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 20)

                    if profileImage != nil || (authManager.currentUser?.profileImageData != nil && !didRemovePhoto) {
                        Button(role: .destructive) {
                            profileImage = nil
                            didRemovePhoto = true
                        } label: {
                            Text(languageManager.string("Remove Photo"))
                        }
                    }
                } header: {
                    Text(languageManager.string("Profile Photo"))
                }

                Section {
                    HStack {
                        Text(languageManager.string("Username"))
                        Spacer()
                        Text(authManager.currentUser?.username ?? "")
                            .foregroundStyle(Color.secondary)
                    }

                    HStack {
                        Text(languageManager.string("Display Name"))
                        TextField(languageManager.string("Display Name"), text: $displayName)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text(languageManager.string("Email"))
                        Spacer()
                        Text(authManager.currentUser?.email ?? "")
                            .foregroundStyle(Color.secondary)
                    }
                } header: {
                    Text(languageManager.string("Account Information"))
                }

                Section {
                    TextField(languageManager.string("Status Message"), text: $statusMessage, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(languageManager.string("Status Message"))
                }

                Section {
                    Button(languageManager.string("Sign Out")) {
                        authManager.signOut()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle(languageManager.string("Edit Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(languageManager.string("Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(languageManager.string("Save")) {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if let newValue {
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            profileImage = uiImage
                            didRemovePhoto = false
                        }
                    }
                }
            }
        }
    }

    private func saveProfile() {
        let imageData: Data?
        if didRemovePhoto {
            imageData = nil
        } else if let profileImage = profileImage {
            imageData = profileImage.jpegData(compressionQuality: 0.7)
        } else {
            imageData = authManager.currentUser?.profileImageData
        }
        authManager.updateProfile(displayName: displayName, statusMessage: statusMessage, profileImageData: imageData)
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self)
    let context = ModelContext(container)
    return ProfileEditView(authManager: AuthManager(modelContext: context))
        .environment(LanguageManager())
}
