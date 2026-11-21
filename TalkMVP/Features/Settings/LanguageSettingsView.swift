//
//  LanguageSettingsView.swift
//  TalkMVP
//
//  Created by David Song on 10/3/25.
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI

struct LanguageSettingsView: View {
    @Environment(LanguageManager.self) var languageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingChangeAlert = false
    @State private var pendingLanguage: LanguageManager.Language?

    var body: some View {
        // Always pushed, from Settings: the stack, and its Back button, are the caller's.
        List {
            Section(
                header: Text(languageManager.string("Language Selection")),
                footer: Text(languageManager.string("The app's text changes as soon as you pick a language."))
            ) {
                ForEach(LanguageManager.Language.allCases, id: \.self) { language in
                    LanguageRow(
                        language: language,
                        isSelected: languageManager.currentLanguage == language
                    ) {
                        selectLanguage(language)
                    }
                }
            }

            // 디버그 정보 섹션 (선택적)
            if ProcessInfo.processInfo.environment["SHOW_LANGUAGE_DEBUG"] == "1" {
                Section(header: Text("Debug Info")) {
                    let info = languageManager.getLanguageInfo()
                    ForEach(Array(info.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption)
                            Spacer()
                            Text(info[key] ?? "")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(languageManager.string("Language"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            languageManager.string("Change Language"),
            isPresented: $showingChangeAlert
        ) {
            Button(languageManager.string("Cancel"), role: .cancel) {
                pendingLanguage = nil
            }
            Button(languageManager.string(LocalizedStringResource("Change", comment: "Confirms switching the app's language"))) {
                if let pendingLanguage = pendingLanguage {
                    languageManager.setLanguage(pendingLanguage)
                    dismiss()
                }
            }
        } message: {
            Text(languageManager.string("The app's text will change to this language. Do you want to continue?"))
        }
    }

    private func selectLanguage(_ language: LanguageManager.Language) {
        if language != languageManager.currentLanguage {
            pendingLanguage = language
            showingChangeAlert = true
        }
    }
}

struct LanguageRow: View {
    let language: LanguageManager.Language
    let isSelected: Bool
    let action: () -> Void
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(.body)
                        .foregroundStyle(Color.primary)

                    // 현재 설정된 언어와 다른 언어로 설명 표시
                    Text(languageManager.string(alternativeName))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .font(.body.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// The row's language named in the app's language, under its own name. Context keys keep
    /// these apart from the untranslated native names, such as "English" in the translation picker.
    private var alternativeName: LocalizedStringResource {
        switch language {
        case .korean:
            return LocalizedStringResource("language.name.korean", defaultValue: "Korean", comment: "Name of the Korean language")
        case .english:
            return LocalizedStringResource("language.name.english", defaultValue: "English", comment: "Name of the English language")
        case .japanese:
            return LocalizedStringResource("language.name.japanese", defaultValue: "Japanese", comment: "Name of the Japanese language")
        case .chinese:
            return LocalizedStringResource("language.name.chineseSimplified", defaultValue: "Chinese (Simplified)", comment: "Name of the Simplified Chinese language")
        case .chineseTraditional:
            return LocalizedStringResource("language.name.chineseTraditional", defaultValue: "Chinese (Traditional)", comment: "Name of the Traditional Chinese language")
        case .spanish:
            return LocalizedStringResource("language.name.spanish", defaultValue: "Spanish", comment: "Name of the Spanish language")
        }
    }
}

#Preview {
    LanguageSettingsView()
        .environment(LanguageManager())
}
