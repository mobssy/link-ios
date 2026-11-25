---
target: 채팅 화면
total_score: 29
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 0
target_identity: "file:/Users/davidsong/TalkMVP/TalkMVP/Features/Conversation/ChatView.swift"
target_fingerprint: "sha256:68285c2038acf6febeb16e78bc12f5efc1e24ea25d070f38f5e521e86f459599"
target_path: /Users/davidsong/TalkMVP/TalkMVP/Features/Conversation/ChatView.swift
timestamp: 2026-11-25T04-54-43Z
slug: talkmvp-features-conversation-chatview-swift
---
# Chat screen critique (run 2)

Method: design review only (detector not applicable, native platform). Evidence: iPhone simulator (iOS 27) captures after the fixes in light, dark, and Accessibility XL text. Summary offer and failed-translation state checked in code only (test mode never shows them).

| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 3 | Translating, translated and failed states are distinct and true |
| 2 | Match System / Real World | 3 | "Disappearing Messages" spelled out; Korean "자폭 메시지" is harsh |
| 3 | User Control and Freedom | 3 | Summary offer can be closed |
| 4 | Consistency and Standards | 3 | Sectioned system menu, glass, receipt color follow the rules |
| 5 | Error Prevention | 3 | Unchanged |
| 6 | Recognition Rather Than Recall | 3 | AI actions lead the menu; still behind "…" day to day |
| 7 | Flexibility and Efficiency | 3 | Unchanged |
| 8 | Aesthetic and Minimalist Design | 3 | Label line gone; run timestamps rarely visible in alternating sample chats |
| 9 | Error Recovery | 3 | Failed translation has Try Again |
| 10 | Help and Documentation | 2 | AI features explained only in Settings |
| **Total** | | **29/40** | **Good** |

## Design specificity
More L!NK than run 1: the translation bubble now tells the truth and the menu leads with the AI. On-device AI still never surfaces by itself in test mode: the summary offer needs 10+ unread, sample chats have 1–2.

## Priority issues
- [P2] Test mode never shows the AI features on its own; add a sample chat with ~12 unread so the summary offer appears. /impeccable onboard
- [P2] The 1:1 "isn't your friend / Add Friend" strip stays for the whole chat with no close. Add a close that sticks per chat. /impeccable distill
- [P3] Korean "Disappearing Messages" reads "자폭 메시지"; use "사라지는 메시지" and check other languages. /impeccable clarify
- [P3] Dark mode incoming bubble (gray 20%) barely separates from black. Raise it a step in dark only. /impeccable polish

## Persona red flags
- 한 여사, 68: translation state now clear; "자폭" alarming; translate glyph indents translation at large sizes.
- Sam (VoiceOver): state reads correctly; check Try Again reachability inside a combined message element on device.
- Reviewer (portfolio): opening several chats never meets the summary or meeting notes.

## Minor observations
- AX XL dark: large text still faintly visible behind the title; title legible.
- Simulator translation latency leaves 2–3 bubbles translating after 6 s; the spinner now says so.

## Questions
- Which chat should a reviewer meet first to see the AI within a minute?
- Is the friend strip a warning or a suggestion? If a suggestion, isn't once enough?
