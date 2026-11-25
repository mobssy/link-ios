# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Anyone who chats with people who write in another language: family abroad, friends met while studying, colleagues. The app is not built for older people only. It is a messenger everyone uses, and older people must be able to use it easily too. When a decision trades power for ease, judge it by how an older person would manage.

A second audience reads the project rather than using it: hiring managers and reviewers who open the repository, the README, and the running app in test mode to judge the work.

## Product Purpose

L!NK is a portfolio app. It shows a complete, careful iOS messenger in which each person writes in their own language and reads the other side in theirs. There is no server: the other side of every chat is simulated, and test mode signs in with sample friends and chats. There is no plan to ship it to the App Store.

Success is a reviewer who tries test mode, understands the product in a minute, and trusts what the AI features say.

## Positioning

- **Translation in the bubble.** The original and its translation sit together in one message bubble, translated on the device. When nothing can translate a message, the bubble says so instead of showing a guess.
- **On-device AI.** Summaries, meeting notes, reply suggestions, and search by meaning run on the device's own model. Conversations never leave the phone; Private Cloud Compute is deliberately not used.
- **AI that can be trusted.** Every meeting-note task must quote the message it came from, owners come only from names in the chat, and dates are read by the system, not the model. The app shows no state it doesn't know, such as fake "online" dots or connection banners.

## Operating Context

- One-to-one and group chats, with group members who each write in their own language (Korean, Japanese, Spanish, and more).
- Tabs: Friends, Chats, Settings. A chat's menu holds search, translation, background, mute, bookmarks, disappearing messages, summary, and meeting notes.
- Runs on iPhone, iPad, and the foldable iPhone Duo (folded it behaves as a phone; open, each list stays beside its detail).
- Siri and Shortcuts can send and read messages.

## Capabilities and Constraints

- Swift, SwiftUI, SwiftData, Foundation Models, Translation and Speech frameworks.
- Deployment target iOS 27. Features from a later iOS release (such as Siri AI in 27.3) sit behind availability checks.
- Six app languages; seven translation languages.
- No backend, no network accounts. Sign in with Apple and Google are local stand-ins.
- Sample people use invented names. Real public figures must never appear in sample data.

## Brand Commitments

- Name: **L!NK**, written with the exclamation mark. Tagline: "Messaging without borders."
- App icon: a dark, glossy speech bubble.
- Voice in copy: plain, short, human sentences that say what is true; no hype.
- License: all rights reserved, worldwide; the repository is public only so the work can be seen.

## Evidence on Hand

- README screenshots in `docs/screenshots/` (iPhone set, iPhone Duo open and folded, on-device summary and meeting notes).
- `docs/ENGINEERING.md`: the iteration history behind the AI features, with before/after behavior.
- Unit and UI test suites.
- There are no real users, testimonials, ratings, press, or usage numbers. Future work must not invent any.

## Product Principles

1. **Say only what is true.** No invented translations, tasks, owners, dates, or status. When the app doesn't know, it says so.
2. **Easy for everyone, older people included.** Large targets, readable text, few steps, familiar iOS patterns before novel ones.
3. **Private by construction.** Language and AI work stays on the device.
4. **Every language is first-class.** A Korean, Japanese, or Spanish reader gets the same quality as an English one, including dates and labels.

## Accessibility & Inclusion

- Dynamic Type and an in-app text size control; layouts must hold at the largest sizes.
- VoiceOver labels on every control; generous hit targets (see `DesignSystem/HitTarget.swift`).
- Contrast that stays readable on the chat backgrounds a user can choose.
