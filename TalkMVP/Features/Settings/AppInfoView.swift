//
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import SwiftUI

struct AppInfoView: View {
    @Environment(LanguageManager.self) var languageManager

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    var body: some View {
        Form {
            Section(header: Text(languageManager.string(LocalizedStringResource("About", comment: "App Info section header with the app's name and version")))) {
                HStack {
                    Text(languageManager.string("App Name"))
                    Spacer()
                    Text(appName)
                }
                HStack {
                    Text(languageManager.string("Version / Build"))
                    Spacer()
                    Text(verbatim: "\(appVersion) (\(appBuild))")
                }
                Text(languageManager.string("Acknowledgements placeholder"))
            }
            Section(header: Text(languageManager.string(LocalizedStringResource("Licenses", comment: "App Info section header for open-source licenses")))) {
                Text(languageManager.string("Licenses placeholder"))
            }
        }
        .navigationTitle(languageManager.string("App Info"))
    }
}

#Preview {
    AppInfoView()
        .environment(LanguageManager())
}
