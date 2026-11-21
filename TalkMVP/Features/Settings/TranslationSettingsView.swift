import SwiftUI

struct TranslationSettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @AppStorage(TranslationPreferences.enabledKey) private var translationEnabled = TranslationPreferences.enabledByDefault
    @AppStorage("translationTargetLanguage") private var translationTargetLanguage = "auto"

    var body: some View {
        Form {
            Section(footer: Text(languageManager.string("A message in another language shows its translation inside the bubble. Translation happens on this device."))) {
                Toggle(isOn: $translationEnabled) {
                    Label {
                        Text(languageManager.string("Translate Messages"))
                    } icon: {
                        Image(systemName: "character.bubble")
                            .foregroundStyle(.teal)
                    }
                }
                Picker(languageManager.string("Translate Into"), selection: $translationTargetLanguage) {
                    Text(languageManager.string("App Language")).tag("auto")
                    // Each language in its own name, the same in every app language.
                    Text(verbatim: "한국어").tag("ko")
                    Text(verbatim: "English").tag("en")
                    Text(verbatim: "日本語").tag("ja")
                    Text(verbatim: "中文(简体)").tag("zh-Hans")
                    Text(verbatim: "中文(繁體)").tag("zh-Hant")
                    Text(verbatim: "Español").tag("es")
                }
                .pickerStyle(.navigationLink)
            }
        }
        .navigationTitle(languageManager.string("Translation"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
