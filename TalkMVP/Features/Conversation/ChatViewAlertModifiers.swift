//
//  ChatViewAlertModifiers.swift
//  TalkMVP
//
//  Created by Claude Code
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI

// MARK: - Alert Modifiers
// Single Responsibility: Alert UI 표시만 담당
// Open/Closed: 새로운 Alert 타입 추가 시 새 struct만 추가하면 됨

/// 메시지 편집 Alert
struct EditMessageAlertModifier: ViewModifier {
    @Environment(LanguageManager.self) private var languageManager

    @Binding var isPresented: Bool
    @Binding var editingText: String
    @Binding var editingMessage: Message?
    let onSave: (Message, String) -> Void

    func body(content: Content) -> some View {
        content.alert(languageManager.string("Edit Message"), isPresented: $isPresented) {
            TextField(languageManager.string(LocalizedStringResource("Message", comment: "Placeholder of the field that edits a message")), text: $editingText)
            Button(languageManager.string("Cancel"), role: .cancel) {
                editingMessage = nil
                editingText = ""
            }
            Button(languageManager.string("Save")) {
                if let message = editingMessage {
                    let newText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !newText.isEmpty {
                        onSave(message, newText)
                    }
                }
                editingMessage = nil
                editingText = ""
                UIAccessibility.post(notification: .announcement, argument: languageManager.string("Message edited"))
            }
        } message: {
            Text(languageManager.string("Edit your message"))
        }
    }
}

/// 위치 권한 Alert
struct LocationPermissionAlertModifier: ViewModifier {
    @Environment(LanguageManager.self) private var languageManager
    @Binding var isPresented: Bool
    let openSettings: () -> Void

    func body(content: Content) -> some View {
        content.alert(languageManager.string("Location Permission Required"), isPresented: $isPresented) {
            Button(languageManager.string("Cancel"), role: .cancel) {}
            Button(languageManager.string("Open Settings")) { openSettings() }
        } message: {
            Text(languageManager.string("Location access is required for emergency calls. Please allow it in Settings."))
        }
    }
}

/// 신고 Alert
struct ReportAlertModifier: ViewModifier {
    @Environment(LanguageManager.self) private var languageManager
    @Binding var isPresented: Bool
    let name: String

    func body(content: Content) -> some View {
        content.alert(languageManager.string(LocalizedStringResource("Report", comment: "Reports the person a chat is with")), isPresented: $isPresented) {
            Button(languageManager.string("OK"), role: .cancel) {}
        } message: {
            Text(languageManager.string("Reported \(name)"))
        }
    }
}

/// 차단 Alert
struct BlockAlertModifier: ViewModifier {
    @Environment(LanguageManager.self) private var languageManager
    @Binding var isPresented: Bool
    let name: String
    let onBlock: () -> Void

    func body(content: Content) -> some View {
        let block = languageManager.string(LocalizedStringResource("Block", comment: "Blocks the person a chat is with"))
        content.alert(block, isPresented: $isPresented) {
            Button(languageManager.string("Cancel"), role: .cancel) {}
            Button(block, role: .destructive) {
                onBlock()
            }
        } message: {
            Text(languageManager.string("Blocked \(name)"))
        }
    }
}

// MARK: - Compound Alert Modifier
/// Combines all alert modifiers to reduce type-checking complexity
struct CompoundAlertModifier: ViewModifier {
    @Binding var showingEditAlert: Bool
    @Binding var editingText: String
    @Binding var editingMessage: Message?
    @Binding var showingLocationPermissionAlert: Bool
    @Binding var showingReportAlert: Bool
    @Binding var showingBlockAlert: Bool

    let chatRoomName: String
    let openURL: (URL) -> Void
    let onEditSave: (Message, String) -> Void
    let onBlock: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(EditMessageAlertModifier(
                isPresented: $showingEditAlert,
                editingText: $editingText,
                editingMessage: $editingMessage,
                onSave: onEditSave
            ))
            .modifier(LocationPermissionAlertModifier(
                isPresented: $showingLocationPermissionAlert,
                openSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            ))
            .modifier(ReportAlertModifier(
                isPresented: $showingReportAlert,
                name: chatRoomName
            ))
            .modifier(BlockAlertModifier(
                isPresented: $showingBlockAlert,
                name: chatRoomName,
                onBlock: onBlock
            ))
    }
}
