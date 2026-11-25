---
target: 채팅 화면
total_score: 26
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
target_identity: "file:/Users/davidsong/TalkMVP/TalkMVP/Features/Conversation/ChatView.swift"
target_fingerprint: "sha256:cd5c9c39f9676dd341fad6f357b3e13a63c699e16c7bd8502e63265d6256be68"
target_path: /Users/davidsong/TalkMVP/TalkMVP/Features/Conversation/ChatView.swift
timestamp: 2026-11-25T04-06-11Z
slug: talkmvp-features-conversation-chatview-swift
---
# Chat screen critique

Method: design review only (detector not applicable, native platform). Evidence: iPhone simulator (iOS 27) captures in light, dark, and Accessibility XL text: study group, 1:1 chat with 김민지, chat menu open, family group; plus the user's Duo captures and source.

| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 2 | Bubble says "Translated" while translating and after failing |
| 2 | Match System / Real World | 3 | Language codes instead of flags are right; "Disappearing" unexplained |
| 3 | User Control and Freedom | 3 | Standard back, swipe to reply, menu toggles |
| 4 | Consistency and Standards | 3 | Native menu, glass, text styles; read receipt color breaks the rule |
| 5 | Error Prevention | 3 | No risky flows |
| 6 | Recognition Rather Than Recall | 2 | Summary and meeting notes hidden in an 8-item overflow menu |
| 7 | Flexibility and Efficiency | 3 | Reply suggestions, swipe to reply, search by meaning, Siri |
| 8 | Aesthetic and Minimalist Design | 3 | Clean; "Translated" label and timestamp repeat on every bubble |
| 9 | Error Recovery | 2 | "Couldn't translate" is honest but has no retry |
| 10 | Help and Documentation | 2 | AI features explained only deep in Settings |
| **Total** | | **26/40** | **Acceptable** |

## Design specificity
Mostly authored for L!NK: original and translation in one bubble, language-code badges, member names instead of fake presence. But the core promise (say only what is true) breaks in the translation bubble itself, and on-device AI is invisible until the menu is opened.

## Priority issues
- [P1] Translation label contradicts state: "Translated" shows over "Translating..." and "Couldn't translate" (ChatViewSupportingViews.swift:185). Fix: label states the state; failed gets a retry. /impeccable harden
- [P1] Read receipt uses .appPrimary on light background (~1.7:1) (MessageBubbleView.swift:133). Fix: .appPrimaryText. /impeccable polish
- [P2] Chat menu: 8 flat items mixing toggles, settings, AI actions. Fix: three sections (view, AI, chat settings); surface summary contextually. /impeccable distill
- [P2] At AX XL the glass title overlaps large bubble text; reply chips cover the sender name above. Fix: stronger scroll-edge blur, one-line title at large sizes. /impeccable adapt
- [P2] Repeated meta: "Translated" label and timestamp on every bubble. Fix: cluster timestamps; icon-only label except translating/failed. /impeccable quieter

## Persona red flags
- 한 여사, 68 (project persona): can't tell if translation finished; title overlaps at large text; never finds summary behind "…".
- Sam (VoiceOver): label reads "Translated, Translating..."; read state is color/shape only.
- Casey (one hand): AI features only in a top-right menu.

## Minor observations
- Persistent "isn't your friend / Add Friend" strip in 1:1 chats.
- Dark mode incoming bubble gray is close to the background.
- Typing state not verified (simulator keyboard did not show).

## Questions
- If translation is the hero, shouldn't its state be the most honest part of the bubble?
- What if the chat offered a summary when many messages are unread?
- Are "Disappearing" and "Bookmarks" clear to an older first-time user?
