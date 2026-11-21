# One localization system

Date: 2026-11-21. Status: approved ("진행시켜", approach A).

## Why

L!NK finds its text in four different ways, and they have drifted apart:

- `L10n.text(key, AppLanguage)` is a 600-line switch with 72 keys.
- `LocalizationService` has about 170 `LocalizationKey` cases and a `Language` enum.
- 19 views keep a private `localizedText(_:)` / `loc(_:)` switch.
- About 330 call sites write all five languages inline with
  `languageManager.localize(ko:en:ja:zh:es:)`.
- Services repeat the language check by hand (`lang.hasPrefix("ko")`).

As a result:

- **Three language enums mean the same thing.** `LanguageManager.Language`, `Language` and
  `AppLanguage` all list the app's languages.
- **Some screens are English-only for most users.** App Info, Terms & Policies and the lock
  screen only know Korean and English, so Japanese, Chinese and Spanish users see English there.
- **Traditional Chinese falls back to Simplified.** It can be picked in Settings, but every
  string except one comes out in Simplified Chinese.
- **No tool sees the strings.** Translators and Xcode can't find text that lives in code; only
  the Siri phrases use a String Catalog.

The portfolio goal is clean, conventional engineering, and an app that is also easy for older
people to use. Both point to one system, the platform's own: String Catalogs.

## Goals

- **Every user-facing string lives in `Localizable.xcstrings`.**
  - Source language: English.
  - Translations: ko, ja, zh-Hans, zh-Hant and es.
- **Keep the in-app language picker** (Settings > Language). Changing the language there
  updates the screen at once, without relaunching.
- **One lookup function per context:**
  - views: `languageManager.string("…")`
  - code outside views: `AppLocalization.string("…")`
  - `Text("…")` resolves through the locale that the root view sets.
- **One language enum:** `LanguageManager.Language`.
- **Real Traditional Chinese.**

## Non-goals

- Changing any wording or translation, beyond filling the gaps above.
- Moving the language choice into the iOS Settings app (that was approach B).
- The Siri catalog (`AppShortcuts.xcstrings`), which already works.
- Sample chat content and test data. They are written in a person's own language on purpose.

## Approaches considered

- **A. Keep the in-app picker, look up with an explicit locale (chosen).**
  - How it works: `LocalizedStringResource.locale` selects the translation, and SwiftUI's
    `Text` resolves keys with `\.locale` from the environment.
  - It changes nothing for users and stays easy for older users: no trip to the Settings app.
- **B. iOS per-app language.**
  - The simplest code.
  - But changing the language relaunches the app and takes a trip to the Settings app.

### Spike (2026-11-21, iOS 27 simulator)

| Lookup | Result for "Send Message" |
|---|---|
| `LocalizedStringResource` with `.locale = ko` | "메시지 보내기" ✅ |
| `LocalizedStringResource` with `.locale = ja` | "メッセージを送信" ✅ |
| `String(localized:locale:)` | "Send Message" ❌ (that locale only formats) |
| `Text("Send Message")` under `.environment(\.locale, ko)` | Korean ✅ |

## Design

### API

- `AppLocalization` (`Localization/AppLocalization.swift`, nonisolated):
  - `string(_ resource: LocalizedStringResource, languageCode:)` sets the resource's locale and
    resolves it.
  - `languageCode()` reads the saved choice.
  - `locale(languageCode:)` swaps the language into the current locale and keeps the region, so
    date and number formats stay the user's.
- `LanguageManager.string(_:)` reads `currentLanguage`, so SwiftUI redraws when the language
  changes.
- `LanguageManager.locale` is set on the root view as `\.locale`.
- Literals passed as `LocalizedStringResource` are extracted by Xcode. The catalog's keys
  therefore match the code exactly; interpolation becomes `%@` or `%lld`.

### Keys

- **Usually the English text itself**, as in Apple's own catalogs. "Sign In" is the key "Sign In".
- **When one English word needs two translations, the key gets a context.** Example: a noun
  versus a verb. Such a key is written as
  `LocalizedStringResource("photo.label", defaultValue: "Photo")`.
- **Every key carries a comment** wherever the English alone is ambiguous.

### Migration

1. Foundation: `AppLocalization`, `LanguageManager.string`, the root `\.locale`, and tests.
2. Call sites, in groups of files that don't overlap:
   - Auth
   - Settings
   - Friends
   - Chats list
   - Conversation
   - App and Services
3. Each group rewrites its calls and records every key's translations in a sidecar JSON file.
   - Known translations are copied as they are.
   - Missing ones are written new: ja/zh/es for the Korean/English-only screens.
4. Delete `L10n`, `LocalizationService`, `AppLanguage`, `Language` and
   `LanguageManager.localize`. Add zh-Hant to `knownRegions`.
5. Sync the catalog:
   - An Xcode IDE build extracts the keys.
   - A script fills the translations from the sidecars.
   - zh-Hant is generated from zh-Hans with ICU's `Hans-Hant` transform, then checked by eye.
6. Verify:
   - unit tests;
   - the UI suite on iOS 27;
   - screenshots of the main screens in ko, ja, zh-Hant and es;
   - a check that the IDE build leaves the catalog unchanged.

## Risks

- **A key mistyped by hand would not match the catalog.** The extraction in step 5 is the check:
  every extracted key must have translations, and every sidecar key must be extracted.
- **Format strings can reorder their arguments in other languages.** Use positional specifiers
  (`%1$@`) wherever the order changes.
- **UI tests that match English text.** They launch with `-selectedLanguage en`, so they keep
  working.
