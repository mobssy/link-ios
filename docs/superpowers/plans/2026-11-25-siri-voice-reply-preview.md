# Siri Voice Reply Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sending a L!NK message from Siri shows, before it goes, what each recipient's screen will read and that text rendered back into the sender's language, with Send and Edit in L!NK.

**Architecture:** A plain `ReplyPreviewBuilder` (no App Intents) computes the per-language preview with the same translator path the chat bubbles use. `ChatIntentActions` gains a send-after-confirming flow whose confirmation step is injected, so it is unit-testable. The App Intents layer adopts the iOS 27 messages App Schema (conversation entity, send intent), asks the system for confirmation with an interactive snippet, and hands Edit off to the app through a small draft hand-off object.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, App Intents (iOS 27.2 SDK: App Schemas, `SnippetIntent`, `@UnionValue`), Foundation Models / Translation via `AIService.translate`, Swift Testing, XCTest + AppIntentsTesting.

**Spec:** `docs/superpowers/specs/2026-11-25-siri-voice-reply-preview-design.md`

## Global Constraints

- Deployment target iOS 27.0; build with the installed iOS 27.2 SDK. Nothing from 27.3 in this round.
- All translation stays on device through `AIService.shared.translate(_:autoDetect:target:)`; never show a translation that wasn't produced.
- The production intent always asks the system for confirmation before sending; no flag or launch argument skips it.
- Access rules unchanged: `ChatIntentActions.checkAccess()` runs before any preview or send (App Lock on or signed out → `ChatIntentError`).
- Every new user-facing string goes into `TalkMVP/Localizable.xcstrings` with en, es, ja, ko, zh-Hans, zh-Hant, inserted with Xcode's JSON layout (`indent=2`, `separators=(',', ' : ')`, key order preserved).
- Copy: plain, short, human; no em dashes in UI copy.
- Snippet follows DESIGN.md: system type and semantic colors, brand tint `.appPrimaryText` for actions, Dynamic Type, VoiceOver label per line, 44 pt targets.
- Commit messages in English with `feat:`/`fix:`/`test:`/`docs:` prefixes, no co-author trailers; warning-free build; tests run on the iOS 27 simulator `C746014A-21F1-4B94-ADD5-D53EDB159DCF` with `-parallel-testing-enabled NO`.

## Review Focus

1. Everyone in the chat writes the sender's language (Family Group in Korean, sender speaks Korean): only an "as written" line, no translation calls, a plain dialog. Test in Task 1 and Task 3.
2. Siri's language differs from the text (L!NK set to English, user says Korean): the sender's language comes from the text, so Korean readers read it as written. Test in Task 1.
3. A chat with no one to read it yet ("New Group" with no members, or a one-to-one chat with no messages): preview has no translated lines, sending still works after confirmation. Test in Task 1.
4. App Lock on or signed out: error before any translation runs and before confirmation. Test in Task 2.
5. Emoji-only or very short text ("👍", "ok"): detection isn't confident, falls back to Siri's language without crashing or inventing a translation. Test in Task 1.

---

### Task 1: Reply preview builder

**Files:**
- Create: `TalkMVP/Services/AI/ReplyPreview.swift`
- Test: `TalkMVPTests/TalkMVPTests.swift` (new `@Suite("Reply preview")`)

**Interfaces:**
- Consumes: `ConversationLanguage.confidentLanguage(of:) -> NLLanguage?`, `ConversationLanguage.of(sender:in:) -> NLLanguage?`, `ConversationLanguage.isSame(_:_:) -> Bool`, `SummaryMessage`.
- Produces:
  ```swift
  nonisolated struct ReplyPreview: Equatable, Sendable {
      enum Reading: Equatable, Sendable {
          case asWritten
          case translated(String, back: String?)
          case untranslatable
          case unknownLanguage
      }
      struct Line: Equatable, Sendable {
          let language: String?      // nil for .unknownLanguage
          let members: [String]
          let reading: Reading
      }
      let text: String
      let senderLanguage: String
      let lines: [Line]
  }

  nonisolated enum ReplyPreviewBuilder {
      typealias Translate = @Sendable (_ text: String, _ target: String) async -> String?
      static func senderLanguage(of text: String, siriLanguage: String) -> String
      static func build(
          text: String, members: [String], recent: [SummaryMessage],
          siriLanguage: String, knownLanguage: (String) -> String?, translate: Translate
      ) async -> ReplyPreview
  }
  ```

- [ ] **Step 1: Write the failing tests** (stub `translate` records calls and returns `"[\(target)] \(text)"`, or nil for a target listed as failing)

  - `senderLanguageComesFromTheText`: `senderLanguage(of: "펜션 예약했어요!", siriLanguage: "en") == "ko"`.
  - `shortTextFallsBackToSiri`: `senderLanguage(of: "👍", siriLanguage: "ja") == "ja"`.
  - `sameLanguageReadsAsWritten`: members 한서연, 강민재 with Korean recent messages, Korean text → `lines == [Line(language: "ko", members: ["한서연", "강민재"], reading: .asWritten)]` and the stub was never called.
  - `otherLanguageIsTranslatedAndBack`: member Emma Kang (English messages), Korean text → one line `.translated("[en] …", back: "[ko] [en] …")`.
  - `twoLanguagesTwoLines`: Study Group members 佐藤ゆき (ja), Lucía García (es), English text → two `.translated` lines, one per language, ordered by member count then language code.
  - `untranslatableIsFlagged`: stub fails for "en" → `.untranslatable` (no text).
  - `backTranslationFailureKeepsTheTranslation`: forward ok, back fails → `.translated(x, back: nil)`.
  - `unknownLanguageMember`: member with no messages and `knownLanguage` nil → line `language: nil, reading: .unknownLanguage`.
  - `knownLanguageFallback`: member with no messages, `knownLanguage("Emma Kang") == "en"` → translated line for "en".
  - `noMembersNoLines`: `members: []` → `lines.isEmpty`.
  - Ordering pin: translated/untranslatable lines first, then `.asWritten`, then `.unknownLanguage`.

- [ ] **Step 2: Run to verify they fail**

  Run: `xcodebuild test -scheme TalkMVP -destination id=C746014A-21F1-4B94-ADD5-D53EDB159DCF -parallel-testing-enabled NO -only-testing:TalkMVPTests`
  Expected: build failure, `ReplyPreviewBuilder` not found.

- [ ] **Step 3: Implement `ReplyPreview.swift`**

  Member language: `ConversationLanguage.of(sender: member, in: recent)?.rawValue ?? knownLanguage(member)`. Group members whose languages `isSame`. For each group not the sender's language: forward = `translate(text, lang)`; back = forward.flatMap { `translate($0, senderLanguage)` }. Run the groups' translations concurrently (`withTaskGroup`), then sort.

- [ ] **Step 4: Run tests, expect PASS**

- [ ] **Step 5: Commit** `feat: build a preview of how each recipient will read a reply`

---

### Task 2: Send after confirming

**Files:**
- Modify: `TalkMVP/Intents/ChatIntentActions.swift`
- Test: `TalkMVPTests/TalkMVPTests.swift` (`ChatIntentActionsTests`)

**Interfaces:**
- Consumes: Task 1 `ReplyPreviewBuilder.build`, `ReplyPreview`.
- Produces on `ChatIntentActions`:
  ```swift
  var previewReply: (_ text: String, _ room: ChatRoom, _ recent: [SummaryMessage]) async -> ReplyPreview
  func preview(_ text: String, for roomID: UUID) async throws -> ReplyPreview
  func sendAfterConfirming(_ text: String, to roomID: UUID,
                           confirm: (ReplyPreview) async throws -> Void) async throws -> Message
  static func recipients(of room: ChatRoom) -> [String]   // memberNames, or [room.name] for one-to-one
  ```
  `previewReply` default: `ReplyPreviewBuilder.build` with the room's recipients, the last 20 messages, `summaryLanguage()` as Siri's language, `TestData.language(of:)`, and `AIService.shared.translate(_, autoDetect: true, target:)`.

- [ ] **Step 1: Write the failing tests** (in-memory context as the suite already does; `previewReply` stubbed)

  - `confirmingSendsOnce`: confirm closure receives the preview for the trimmed text; after it returns, exactly one message with that text is in the room.
  - `cancellingSendsNothing`: confirm throws → the error propagates, no message saved, chat list preview unchanged.
  - `lockedFailsBeforePreview`: `isAppLocked: { true }` → `ChatIntentError.appLocked`; `previewReply` and `confirm` never called.
  - `signedOutFailsBeforePreview`: no current user → `.signedOut`, same assertions.
  - `emptyTextFailsBeforePreview`: `"  "` → `.emptyMessage`.
  - `recipientsOfRooms`: group → `memberNames`; one-to-one room "김민지" → `["김민지"]`; empty group → `[]`.

- [ ] **Step 2: Run, expect FAIL** (same command as Task 1)

- [ ] **Step 3: Implement** `preview` and `sendAfterConfirming` (check access → trim/empty → room → preview → `try await confirm(preview)` → existing `send`).

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit** `feat: send from Siri only after the preview is confirmed`

---

### Task 3: Messages schema: conversation entity, send intent and the confirmation card

**Files:**
- Create: `TalkMVP/Intents/ConversationEntities.swift` (schema entities and the `@UnionValue` destination)
- Create: `TalkMVP/Intents/ReplyPreviewSnippet.swift` (snippet intent + SwiftUI card)
- Modify: `TalkMVP/Intents/ChatIntents.swift` (send intent, `ChatShortcuts`; `SummarizeChatIntent` uses the new entity)
- Modify: `TalkMVP/Localizable.xcstrings`, `TalkMVP/AppShortcuts.xcstrings` if phrases change
- Modify: `DESIGN.md` (Components: the Siri reply card)
- Test: `TalkMVPTests/TalkMVPTests.swift` (entity mapping, dialog text)

**Interfaces:**
- Consumes: Task 2 `preview`, `sendAfterConfirming`, `recipients(of:)`.
- Produces:
  ```swift
  @AppEntity(schema: .messages.conversation) struct ChatConversationEntity  // id: UUID; init(_ room: ChatRoom)
  @AppEntity(schema: .messages.messagePerson) struct ChatPersonEntity       // a member, by name
  @UnionValue enum ChatDestination                                        // schema's destination cases
  struct ReplyPreviewSnippetIntent: SnippetIntent                          // parameters: chat, text
  enum ReplyPreviewDialog { static func text(for: ReplyPreview, chatName: String) -> LocalizedStringResource }
  ```
  `ChatConversationEntity` replaces `ChatRoomEntity` (same `id`, same query rules as `ChatRoomQuery`, renamed `ChatConversationQuery`). Schema properties to fill (from the SDK's schema database): `recipients` ([MessagePerson]) from `recipients(of:)`, `displayName` = room name, `previewText` = `lastMessage`, `conversationName` = group name or nil, `isRead` = `unreadCount == 0`, `dateLastActive` = `timestamp`, `attributes` empty. Exact Swift types follow the `@AppEntity(schema:)` macro diagnostics.

- [ ] **Step 1: Write the failing tests**

  - `conversationEntityFromGroup` / `conversationEntityFromOneToOne`: field mapping above.
  - `dialogOneToOneTranslated`: preview with one `.translated("I booked it!", back: "예약했어요!")` for "Emma Kang" → resolved English text `Emma Kang will read it as "예약했어요!" Send it?`.
  - `dialogOneToOneUntranslatable`: → `Emma Kang will see it as written. Send it?`.
  - `dialogGroupSeveralLanguages`: two translated lines → `2 languages. Take a look before sending.`.
  - `dialogEveryoneAsWritten` and `dialogNoRecipients`: → `Send "…" to Family Group?`.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement the entities and destination**

  Mark the existing chat query results with the new entity. Destination mapping: `conversation` → that room; a person (or one-person list) → the one-to-one room whose name matches; several people → the group whose members are exactly those names; no match → `ChatIntentError.chatNotFound`.

- [ ] **Step 4: Implement the send intent**

  `@AppIntent(schema: .messages.sendMessage) struct SendChatMessageIntent`, `authenticationPolicy = .requiresAuthentication`. `perform()` calls `sendAfterConfirming` with a confirm closure that stores the preview in `ReplyPreviewSnippetIntent`'s cache and calls `requestConfirmation(actionName: .send, dialog: IntentDialog(ReplyPreviewDialog.text(...)), snippetIntent: ReplyPreviewSnippetIntent(chat:text:))`. Returns the sent message as the schema result (a minimal message entity if the schema requires one). Keep both existing `ChatShortcuts` phrases.

- [ ] **Step 5: Implement the snippet**

  `ReplyPreviewSnippetIntent.perform()` reads the cached preview for (room id, text), computing it with `preview(_:for:)` if absent, and shows the card from the spec: "You're sending" + text; per line, "<names> reads it in <language>" + translation + "↳ back in <sender language>: <back>" (secondary, translate glyph); "<names> reads it as written"; "<names> will see it as written. It couldn't be translated."; unknown: "<names> will read it in their own language". An **Edit in L!NK** button (`Button(intent: OpenChatDraftIntent(chat:text:))`, Task 4). Send/Cancel are the system's confirmation buttons. Add the strings in six languages and a DESIGN.md Components entry.

- [ ] **Step 6: Run unit tests, expect PASS; build warning-free**

- [ ] **Step 7: Commit** `feat: adopt the messages schema and confirm Siri replies with a preview card`

---

### Task 4: Edit in L!NK hands the draft to the chat

**Files:**
- Create: `TalkMVP/App/ChatDraftHandoff.swift`
- Modify: `TalkMVP/App/TalkMVPApp.swift` (register as dependency, put in environment), `TalkMVP/App/ContentView.swift` (observe → `router.openChat`), `TalkMVP/Features/Conversation/ChatView.swift` (take the draft for its room into `inputText`), `TalkMVP/Intents/ChatIntents.swift` (`OpenChatDraftIntent`)
- Test: `TalkMVPTests/TalkMVPTests.swift`, `TalkMVPSiriUITests/SiriActionsUITests.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor @Observable final class ChatDraftHandoff {
      private(set) var pending: (roomID: UUID, text: String)?
      func hand(_ text: String, to roomID: UUID)
      func takeDraft(for roomID: UUID) -> String?   // returns once, clears only for that room
  }
  struct OpenChatDraftIntent: AppIntent   // supportedModes: .foreground(.immediate); chat, text
  ```

- [ ] **Step 1: Failing unit tests**: `takeDraftOnce` (second take is nil), `takeDraftOnlyForItsRoom` (other room gets nil and the draft stays).
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement** the hand-off, the intent (access check, then `hand`), ContentView observation (`.onChange(of: handoff.pending?.roomID)` → `router.openChat`), ChatView `.onAppear`/`.onChange` taking the draft into `inputText` without sending.
- [ ] **Step 4: Siri UI test** `testEditInLinkOpensTheChatWithTheDraft`: run `OpenChatDraftIntent` for Family Trip with "Draft from Siri" via AppIntentsTesting; assert the message field's value is "Draft from Siri" and no new message with that text exists.
- [ ] **Step 5: Run unit + Siri UI tests, expect PASS**
- [ ] **Step 6: Commit** `feat: open the chat with the draft when a Siri reply is edited in L!NK`

---

### Task 5: Siri test for the send flow and docs

**Files:**
- Modify: `TalkMVPSiriUITests/SiriActionsUITests.swift`
- Modify: `docs/ENGINEERING.md` (a short paragraph under the AI section), `README.md` only if the feature list line should mention it (one clause at most)

- [ ] **Step 1: Find out on the simulator** what `run()` of the send intent does when it requests confirmation through AppIntentsTesting (throws, returns, or hangs with a timeout). Record it in a comment on the test.
- [ ] **Step 2: Update `testSiriSendsAMessageAndSummarizesAChat`**: replace the direct send with a check that running the send intent for Family Trip with "Sent from Siri" does not add that message without a confirmation (assert per Step 1's finding); keep the summary part.
- [ ] **Step 3: Run the full UI + Siri suites**: `xcodebuild test ... -only-testing:TalkMVPUITests -only-testing:TalkMVPSiriUITests`, expect 0 failures (the two Apple-Intelligence tests may skip).
- [ ] **Step 4: Docs**: ENGINEERING.md: how the preview reuses the bubble's translator, the back-translation, and why confirmation can't be skipped; the 27.3 Siri AI step is next.
- [ ] **Step 5: Commit** `test: cover the confirmed Siri send` and `docs: describe the Siri reply preview`
