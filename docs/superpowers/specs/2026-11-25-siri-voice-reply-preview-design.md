# Siri voice reply with a preview of what they'll read

Date: 2026-11-25. Status: approved ("A 로 진행시켜"): approach A, built on the iOS 27.2 SDK first.

## Why

L!NK's promise is a messenger where each person writes in their own language and reads the
other side in theirs, with AI that only says what it can stand behind, easy enough for older
people. iOS 27.3 opens Siri AI to third-party apps through App Intents, and iOS 27 adds a
standard messages domain (App Schemas) that Siri understands in natural language.

Any messenger can adopt that domain and "send a message with Siri". What no messenger does is
let the sender check, before sending, what the other person will actually read in their own
language. That is the feature: say a reply to Siri in your language, see (and hear) what each
recipient will read, then send. It turns L!NK's two differentiators, translation in the bubble
and trustworthy AI, into one Siri moment, and it serves the person who most needs it: someone
who can't type easily and can't read the other language.

It is also the portfolio's showcase of the newest platform work (Siri AI, App Schemas,
interactive snippets) built on the app's existing on-device translation.

## How messages and translation work today

- A message is stored as written, in the sender's language. Each reader's screen translates
  it (`TranslatedTextView` → `AIService.translate(_:autoDetect:target:)`, on device: the
  Foundation Models translator, then the Translation framework; nil when neither can).
- The other side of every chat is simulated, but each member has a language: detected from
  their recent messages (`ConversationLanguage.of(sender:in:)`, as the chat subtitle does), and
  in test mode also known from `TestData.language(of:)`.
- Siri today: `SendChatMessageIntent` sends immediately with no confirmation;
  `SummarizeChatIntent`; `ChatRoomEntity` with `ChatRoomQuery` (respects App Lock and sign-in
  via `ChatIntentActions.checkAccess()`). Logic lives in `ChatIntentActions` so it is testable
  without Siri; Siri tests run in `TalkMVPSiriUITests` with AppIntentsTesting.

So the preview is not "the text we'll send". It is "how this will appear on their screen",
produced by the same translator their screen would use.

## Goals

- From Siri, in natural language, send a message to a L!NK chat by voice, in any of the app's
  languages ("Siri, tell the Family Trip chat I booked the guesthouse").
- Before sending, show a confirmation card with, per recipient language:
  - the translation that recipient will read, and
  - that translation rendered back into the sender's language (back-translation),
  and buttons **Send** and **Edit in L!NK**.
- Siri speaks the back-translation, so someone not looking at the screen can confirm by ear:
  "Emma will read it as: '펜션 예약했어요!' Send it?"
- **Edit in L!NK** opens that chat with the text in the message field, not sent.
- Groups with several languages show one line per language (decided: option A). Members who
  read the sender's language get a single "reads it as written" line.
- If a language can't be translated, the card says that recipient will see the original, and
  sending is still allowed.
- Replaces today's send-without-confirmation Siri action.

## Non-goals

- The same preview inside the app's own message field (decided: Siri only for now; the preview
  builder should be reusable for that later).
- Sending translated text. Messages stay stored as written; translation stays on the reader's
  side.
- Attachments, locations, links, subject, scheduled sends from Siri (the schema has them; L!NK
  leaves them out of this feature).
- Editing by voice in a loop ("change it to …"). Editing happens in the app.
- Any server or cloud translation. Private Cloud Compute stays unused.

## Anti-goals (would make it a failure even if it works)

- A preview that differs from what the recipient's screen would show. It must come from the
  same translator path as `TranslatedTextView`.
- A preview that invents a translation when none was produced (the app's rule: no translation
  beats a made-up one).
- Sending without the person's confirmation, or sending when App Lock is on or nobody is signed
  in.
- A card so long that Siri's sheet scrolls for a normal chat; two or three language lines must
  fit.

## Constraints

- Deployment target iOS 27.0. The messages App Schema domain is iOS 27.0 (present in the
  installed 27.2 SDK). Siri AI calling third-party intents by natural language is iOS 27.3
  (beta since 2026-11-03; public release expected December; App Store submissions with Siri AI
  integrations open in spring). Anything that only exists in the 27.3 SDK goes behind
  `#available(iOS 27.3, *)`.
- This Mac has Xcode with the iOS 27.2 SDK. The feature is built and tested against 27.2
  (schema conformance, AppIntentsTesting, snippet UI). Real spoken Siri requests need a device
  on iOS 27.3 beta (the user's iPhone Duo) and are checked there by hand.
- Speech recognition doesn't run in the simulator; voice is verified on the device only.
- Everything L!NK computes (translations, back-translations) runs on device.
- Six app languages (en, ko, ja, zh-Hans, zh-Hant, es); every new string is translated in the
  String Catalog. Plain, short, human copy.
- Accessibility: Dynamic Type in the snippet, VoiceOver reads each line with its language and
  person, 44 pt targets.
- Tests: logic in `ChatIntentActions`-style plain types with Swift Testing; Siri flow with
  AppIntentsTesting in `TalkMVPSiriUITests`.

## The messages schema, as the 27.2 SDK defines it

From Xcode's App Intent schema database (`AppIntentSchemas.sqlite`):

- `messages.sendMessage` (SendMessageIntent): `content` (optional attributed string),
  `destination` (union of `people` [person], `messagePerson`, `messagePeople`, `conversation`),
  plus `subject`, `attachments`, `audioMessage`, `locations`, `links`, `scheduledDate`. It
  carries a system confirmation side effect with buttons "Send" / "Cancel" and returns
  `[MessageEntity]`.
- `messages.draftMessage` (DraftMessageIntent): same shape, `destination` optional, opens the
  app.
- `messages.conversation` (ConversationEntity): `recipients` [MessagePerson], `displayName`,
  `previewText`, `conversationName` (group name), `isRead`, `attributes`, `dateLastActive`.
- `messages.messagePerson` (MessagePerson): `person`.

## Approaches considered

- **A. Confirm and send inside Siri (chosen).** One intent conforming to
  `messages.sendMessage`. Before sending, it asks for confirmation with an interactive snippet
  (the card above); Send completes without opening the app; Edit opens the chat with a draft.
  Best demo, natural-language reach through the standard domain. Cost: L!NK's chat has to be
  modeled as the schema's `conversation` entity (recipients, display name, etc.), beyond
  today's `ChatRoomEntity` (id, name).
- **B. Draft only, confirm in the app.** Siri creates a draft and opens L!NK, which shows the
  preview. Free-form UI, but every send opens the app and loses "done from Siri".
- **C. Spoken confirmation only.** Add the back-translation to the current intent's dialog.
  Smallest, but nothing to see, and multi-language groups can't be shown.

## Design

### 1. The preview (plain logic, reusable)

A `ReplyPreview` builder, independent of App Intents, so it is unit-testable and can serve the
in-app preview later:

- Input: the text, the chat's members, and their recent messages.
- The text's language is detected from the text itself (`ConversationLanguage.confidentLanguage`),
  because a spoken reply comes in Siri's language, which can differ from L!NK's own language
  setting. When detection isn't confident, it falls back to Siri's language
  (`Locale.preferredLanguages`, as `ChatIntentActions.summaryLanguage()` does). This "sender's
  language" decides who reads it as written and what the back-translation is in.
- For each member, the recipient language: detected from their messages, else the test-mode
  known language, else unknown.
- Group members by language. For each language other than the sender's: translate the text
  into it with the same path as `TranslatedTextView` (`AIService.translate`, auto-detect on),
  then translate that result back into the sender's language.
- Output, per language: the members, the language, and one of:
  - `.sameLanguage` (reads it as written),
  - `.translated(text, backTranslation)`,
  - `.untranslatable` (they'll see the original),
  - `.unknownLanguage` (members whose language L!NK can't tell; they see it as their screen
    translates it, shown as "will read it in their own language" without a text).
- Ordering: languages by number of members, then name; the sender's language last or first
  (builder's call; keep it consistent).
- Back-translation failing while the forward translation succeeded: show the translation and
  omit the back line (don't fake it).

### 2. The conversation entity

Conform L!NK's chat entity to `messages.conversation` (extend `ChatRoomEntity` or add a schema
entity beside it, builder's call): recipients from `memberNames` (or the room name for a
one-to-one chat), display name, group name for groups, last message preview, read state from
`unreadCount`, last active date. Keep `ChatRoomQuery`'s access rules (no results while locked
or signed out). Make it indexable for Siri's semantic search if the SDK requires it
(`IndexedEntity`).

### 3. The send intent

`SendChatMessageIntent` becomes the `messages.sendMessage` conformance (same Siri phrases kept
in `ChatShortcuts`, updated as needed):

1. Check access (`checkAccess()`); empty text → `ChatIntentError.emptyMessage`.
2. Build the `ReplyPreview` for the chat.
3. Request confirmation with the snippet below. The spoken dialog is the back-translation for a
   one-to-one chat ("Emma will read it as '…'. Send it?"); for a group, a short line ("Two
   languages. Take a look before sending.").
4. On Send: `ChatIntentActions.send` (unchanged behavior: disappearing settings, chat list
   preview). Return the sent message as the schema's message result.
5. On Edit in L!NK: hand the text and chat to the app (via the `draftMessage` conformance or
   an open-app intent with the chat and draft), which opens that chat with the text in the
   field.

### 4. The snippet

```
┌ L!NK · Family Trip ───────────────┐
│ You're sending                     │
│ 펜션 예약했어요!                     │
│                                    │
│ Emma Kang reads it in English      │
│ I booked the guesthouse!           │
│ ↳ back in Korean: 펜션 예약했어요!   │
│                                    │
│ 한서연 reads it as written           │
│                                    │
│   [ Edit in L!NK ]     [ Send ]    │
└────────────────────────────────────┘
```

- System typography and colors; Send uses the brand tint (periwinkle with dark text, per
  DESIGN.md); the back-translation line is secondary text with the translate glyph.
- Untranslatable line: "Emma Kang will see it as written. It couldn't be translated."
- Two or three language blocks fit without scrolling at the default text size; at
  accessibility sizes it may scroll.
- All copy localized in the six languages; names shown as the chat shows them.

### 5. Draft into the app

The chat screen accepts a pending draft for a room (through `AppRouter`, as `roomToOpen` is
handed over today): opening L!NK from Edit selects the chat and fills the message field without
sending.

### 6. iOS 27.3 Siri AI

With the 27.3 SDK: add whatever Siri AI needs to call these intents from natural language
(secondary sources mention marking intents as tools and an Xcode "Siri Integration Advisor";
verify against Apple's 27.3 documentation before relying on any name), behind
`#available(iOS 27.3, *)` where an API is 27.3-only. Until then, the feature works through the
App Shortcut phrases and Shortcuts on iOS 27.0+.

## Scope of this round

Built now on the installed iOS 27.2 SDK: sections 1 to 5 (preview builder, conversation entity,
send intent with the confirmation snippet, Edit in L!NK draft hand-off) and their tests. Section
6 (Siri AI natural-language reach on iOS 27.3) and the by-hand check on the iPhone Duo come in a
later round, once the 27.3 beta Xcode is installed; they are not a gate for this round.

## Testing

- Unit (Swift Testing): `ReplyPreview` with stub translators: same language, one other
  language, two other languages, untranslatable, back-translation failure, unknown language,
  ordering; recipient-language detection from messages and the test-mode fallback.
- Unit: conversation entity mapping (one-to-one and group).
- Confirmation logic (unit): the send flow takes its confirmation step as an injected
  dependency in the plain-logic layer, so tests can confirm or cancel. Confirming sends once;
  cancelling sends nothing; locked and signed-out cases keep their errors. The production
  intent always asks the system for confirmation; no build or launch flag skips it.
- Siri (AppIntentsTesting, `TalkMVPSiriUITests`): AppIntentsTesting in the 27.2 SDK can only
  make and run an intent; it can't answer a confirmation or read a snippet. The test runs the
  send intent against Family Trip and checks what `run()` does when the intent asks for
  confirmation (to be found on the simulator), and that nothing is sent without a confirmation.
- UI: Edit in L!NK opens the chat with the draft in the field.
- Device (iPhone Duo on iOS 27.3 beta, by hand): spoken requests in Korean and English to
  Family Trip and Study Group; Siri speaks the back-translation; Send and Edit both work.

## Decided in conversation

- Siri only for now; in-app preview later, reusing the preview builder.
- Multi-language groups: one line per language (option A).
- Approach A: confirm and send inside Siri.

## Proposed by me (open to correction)

- Siri speaks the back-translation for one-to-one chats.
- Edit opens the chat with a draft rather than editing by voice.
- Untranslatable languages are flagged and sending is still allowed.
- Members who read the sender's language get one "reads it as written" line.
- The current no-confirmation send intent is replaced, not kept beside the new one.

## Settled after the builder check (my calls)

- Sender's language: detected from the dictated text, falling back to Siri's language (not the
  app's language setting). Card copy follows the app's localization, like the existing intents.
- Confirmation is tested through an injected confirmer in unit tests; the Siri test only
  covers what AppIntentsTesting can run. There is no test-only path that skips confirmation.

## Left to the builder

- Whether the schema entity extends `ChatRoomEntity` or sits beside it, and the exact way the
  union `destination` parameter maps to L!NK chats.
- How Edit hands the draft to the app (draftMessage conformance or an open intent).
- Language ordering on the card; snippet layout details within DESIGN.md.
- Whether translation and back-translation for several languages run concurrently.
