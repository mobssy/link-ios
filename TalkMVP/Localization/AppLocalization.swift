//
//  AppLocalization.swift
//  TalkMVP
//  Copyright © 2025–2026 David Song. All rights reserved.
//

import Foundation

/// The app's one way to find text in its own language. Every string lives in
/// Localizable.xcstrings; this looks it up in the language picked in Settings, which can differ
/// from the system's, by setting the resource's locale. (`String(localized:locale:)` would not
/// do: its locale only formats numbers and dates and the lookup stays in the system language.)
///
/// Views use `LanguageManager.string(_:)`, which SwiftUI observes; code outside views, such as
/// notifications and sign-in errors, uses `AppLocalization.string(_:)`.
nonisolated enum AppLocalization {
    /// Where `LanguageManager` saves the language picked in Settings.
    static let languageKey = "selectedLanguage"

    /// The language the app speaks: the one picked in Settings, else the system's first.
    static func languageCode(defaults: UserDefaults = .standard) -> String {
        if let saved = defaults.string(forKey: languageKey) { return saved }
        if let languages = defaults.array(forKey: "AppleLanguages") as? [String], let first = languages.first {
            return first
        }
        return "en"
    }

    /// `resource` in the language with this code, falling back to English.
    static func string(_ resource: LocalizedStringResource, languageCode: String) -> String {
        var resource = resource
        resource.locale = locale(languageCode: languageCode)
        return String(localized: resource)
    }

    /// `resource` in the app's language.
    static func string(_ resource: LocalizedStringResource) -> String {
        string(resource, languageCode: languageCode())
    }

    /// The current locale with its language swapped for `languageCode`, so the region's formats
    /// (dates, numbers, calendar) stay the user's.
    static func locale(languageCode: String, base: Locale = .current) -> Locale {
        var components = Locale.Components(locale: base)
        let region = components.languageComponents.region
        components.languageComponents = Locale.Language.Components(identifier: languageCode)
        if components.languageComponents.region == nil {
            components.languageComponents.region = region
        }
        return Locale(components: components)
    }
}

extension LanguageManager {
    /// The locale for the language picked in Settings; the app's root view hands it to SwiftUI.
    var locale: Locale {
        AppLocalization.locale(languageCode: currentLanguage.rawValue)
    }

    /// `resource` in the language picked in Settings. Reading `currentLanguage` here makes a view
    /// that calls this redraw when the language changes.
    func string(_ resource: LocalizedStringResource) -> String {
        AppLocalization.string(resource, languageCode: currentLanguage.rawValue)
    }
}
