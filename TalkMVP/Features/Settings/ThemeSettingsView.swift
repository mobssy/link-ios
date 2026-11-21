import SwiftUI

struct ThemeSettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @AppStorage("themeMode") private var themeMode: String = "system" // "system", "light", "dark"

    var body: some View {
        Form {
            Section(header: Text(languageManager.string("Theme"))) {
                Picker(selection: $themeMode) {
                    Label(languageManager.string("Use System"), systemImage: "iphone")
                        .tag("system")
                    Label(languageManager.string(LocalizedStringResource("Light", comment: "Light appearance option")), systemImage: "sun.max.fill")
                        .tag("light")
                    Label(languageManager.string(LocalizedStringResource("Dark", comment: "Dark appearance option")), systemImage: "moon.fill")
                        .tag("dark")
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle(languageManager.string("Theme"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
            .environment(LanguageManager())
    }
}
