---
name: L!NK
description: Messaging without borders.
colors:
  periwinkle-mist: "#B5C7EB"
  periwinkle-deep: "#395CAC"
  ink-on-mist: "#151C30"
  incoming-bubble: "rgba(142, 142, 147, 0.2)"
  disappearing-flame: "#FF9500"
  recording-red: "#FF3B30"
typography:
  large-title:
    fontFamily: "SF Pro (system, Dynamic Type: Large Title)"
    fontSize: "34pt"
    fontWeight: 700
  title:
    fontFamily: "SF Pro (system, Dynamic Type: Title)"
    fontSize: "28pt"
    fontWeight: 400
  headline:
    fontFamily: "SF Pro (system, Dynamic Type: Headline)"
    fontSize: "17pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro (system, Dynamic Type: Body)"
    fontSize: "17pt"
    fontWeight: 400
  subheadline:
    fontFamily: "SF Pro (system, Dynamic Type: Subheadline)"
    fontSize: "15pt"
    fontWeight: 400
  caption:
    fontFamily: "SF Pro (system, Dynamic Type: Caption)"
    fontSize: "12pt"
    fontWeight: 400
rounded:
  image: "12pt"
  panel: "16pt"
  bubble: "20pt"
  sheet-card: "25pt"
  pill: "9999pt"
spacing:
  hair: "4pt"
  tight: "8pt"
  snug: "12pt"
  standard: "16pt"
  roomy: "20pt"
components:
  bubble-own:
    backgroundColor: "{colors.periwinkle-mist}"
    textColor: "{colors.ink-on-mist}"
    typography: "{typography.body}"
    rounded: "{rounded.bubble}"
    padding: "10pt 16pt"
  bubble-incoming:
    backgroundColor: "{colors.incoming-bubble}"
    typography: "{typography.body}"
    rounded: "{rounded.bubble}"
    padding: "10pt 16pt"
  send-button:
    backgroundColor: "{colors.periwinkle-mist}"
    textColor: "{colors.ink-on-mist}"
    rounded: "{rounded.pill}"
    size: "36pt"
  list-row-selected:
    backgroundColor: "{colors.periwinkle-deep}"
    textColor: "#FFFFFF"
    rounded: "{rounded.panel}"
  message-field:
    rounded: "{rounded.pill}"
    padding: "8pt 14pt"
    typography: "{typography.body}"
---

# Design System: L!NK

## Overview

**Creative North Star: "The Two-Language Bubble"**

Everything in L!NK exists to serve one object: a message bubble that holds what someone wrote and, under a thin divider, what it means in your language. The bubble is the only place the brand speaks loudly. Your own messages fill with Periwinkle Mist; everyone else's sit in a quiet translucent gray; the translation lives inside the same bubble behind a small translate glyph, never in a second bubble or a popover.

The rest of the app steps back into iOS itself: system text styles, semantic colors, SF Symbols, grouped lists for settings, tab bar and navigation stacks, and Liquid Glass for the controls that float over a chat. Density is calm and generous, because the app must be easy for older people too: large targets, readable type at every Dynamic Type size, and nothing on screen that the app can't vouch for.

**Key Characteristics:**
- One brand color, used for your own voice (your bubbles, the send button, read receipts) and almost nowhere else.
- Original and translation share one bubble; a language code badge ("JA", "ES") on the sender's avatar says who writes in what.
- Native first: system typography, semantic colors, platform controls, Liquid Glass over content.
- Rounded, soft forms; no hard boxes, no heavy borders.
- Light and dark are equal citizens, and a chat's own background (color, gradient, or photo) decides whether its controls render light or dark.

## Colors

A single soft periwinkle carries the brand against the system's neutral palette.

### Primary
- **Periwinkle Mist** (#B5C7EB): the fill of your own message bubbles and the send button, and the tint for brand text in dark mode. It is light in both appearances, so anything on it is dark.
- **Periwinkle Deep** (#395CAC): the same hue made strong enough to carry white text (about 6.4:1), for selected list rows, and the brand text color in light mode, where Periwinkle Mist on white is only about 1.7:1.
- **Ink on Mist** (#151C30): text and icons on Periwinkle Mist (about 10:1).

### Neutral
- **System semantic colors** (label, secondaryLabel, tertiaryLabel, systemBackground, secondarySystemBackground, tertiarySystemFill): all text, backgrounds, and fills outside the bubble. They adapt to Dark Mode and Increase Contrast on their own.
- **Incoming Bubble** (gray at 20% opacity): other people's bubbles, translucent so a chat's chosen background shows through. With Increase Contrast it becomes systemGray4.

### Signal colors
- **Disappearing Flame** (system orange): the flame on a disappearing message.
- **Recording Red** (system red): the live recording dot and destructive actions such as Block.
- **Avatar palette** (system blue, indigo, purple, pink, brown, as gradients): sender initials, picked from the name so a person keeps one color.

### Named Rules
**The Your-Voice Rule.** Periwinkle marks what is yours (your bubbles, your send, your read receipts). It is not decoration, not a section header color, and not a background wash.

**The Dark-on-Mist Rule.** Never put white text on Periwinkle Mist. Use Ink on Mist on it, or switch the fill to Periwinkle Deep when the text must be white.

**The High-Contrast Swap.** With Increase Contrast on, your bubble becomes the label color with the system background as its text, the strongest pair in either appearance.

## Typography

**Display Font:** SF Pro (system)
**Body Font:** SF Pro (system)

**Character:** Entirely the system face through Dynamic Type text styles, so every size follows the reader's setting and the in-app text size control. Hangul, kana, and Latin all render in the system's own fonts.

### Hierarchy
- **Large Title** (bold, 34pt at default size): top-level tab screens (Chats, Friends, Settings), collapsing inline on scroll.
- **Title** (regular, 28pt): sheet headings such as Conversation Summary, and the profile name.
- **Headline** (semibold, 17pt): chat list names, row titles, the chat's title in the navigation bar.
- **Body** (regular, 17pt): message text, both original and translation.
- **Subheadline** (15pt): last-message previews, secondary row text.
- **Caption / Caption 2** (12pt / 11pt): sender names above bubbles, timestamps, the "Translated" label, status glyphs. 11pt is the floor.

### Named Rules
**The Text-Style Rule.** Use a text style (`.body`, `.headline`, `.caption`), never a fixed point size, so the in-app text size and Dynamic Type reach every label, including sheets.

## Layout

Native iOS structure: a tab bar with Friends, Chats, and Settings; navigation stacks within each; sheets for self-contained tasks (summary, meeting notes, group info, background settings). On iPad and on an open iPhone Duo, each tab becomes a split view with the list beside its detail; folded, the Duo behaves as a phone. On the open Duo in landscape the status bar runs down the right edge, so centered layouts use the uneven safe area rather than the screen's center.

Spacing follows a 4pt rhythm: 4 and 8 inside clusters, 12 and 16 for content padding, 20 between groups. Bubbles stack with 2pt between them and 16pt from the screen edge.

## Elevation & Depth

Depth comes from Liquid Glass, not shadows. Controls that float over a chat (the message field, the attach and mic buttons, the toolbar circles, the reply-suggestion strip, the title capsule) use the system glass effect so they read on any background the user picked. Surfaces at rest are flat. The only shadows are two faint ambient ones (black at 5% to 15%) on lifted cards.

### Named Rules
**The Glass-Over-Content Rule.** Glass is for controls floating over user content. Lists, settings rows, and bubbles are not glass.

## Shapes

Soft, generously rounded forms throughout: bubbles at 20pt, glass panels at 16pt, image thumbnails at 12pt, sheet cards at 25pt, and capsules for the message field, chips, and suggestion pills. Avatars are circles. No sharp-cornered boxes, no black outlines, no hairline borders around cards.

## Components

### Message Bubble (signature)
- **Shape:** rounded rectangle (20pt), padded 10pt by 16pt; images inset 4pt.
- **Own:** Periwinkle Mist with Ink on Mist text, right-aligned, with a read receipt (checkmark circle) under it.
- **Incoming:** translucent gray, left-aligned, sender name in caption above, avatar with a language-code badge beside it.
- **Translation:** inside the incoming bubble under a divider, in one of three states and never ahead of the truth. Translating: a small spinner and "Translating…" in caption. Translated: the translate glyph, then the translation in body with a hanging indent; no word label. Failed: "Couldn't translate" with a Try Again button. VoiceOver reads the same state with the message.
- **Time and receipt:** only the last message of a run (one sender, each within 5 minutes of the next) shows the time and, for your own messages, the read receipt in Periwinkle Deep / brand text color. Status glyphs (bookmark, flame for disappearing, clock for scheduled) show on any message that has them, in caption 2.

### Message Field
- **Style:** capsule of interactive Liquid Glass, 14pt by 8pt padding, between a plus button and the mic or send button.
- **Send:** a periwinkle circle with a dark paper-plane glyph.

### Buttons
- **Primary actions** (Sign In, Start Chat): bordered-prominent system buttons in the brand tint, full width, dark text on periwinkle.
- **Secondary:** bordered system buttons; destructive actions in system red as plain text with an SF Symbol.
- **Floating controls:** circular glass buttons (back, menu, plus, sidebar).

### Lists and Rows
- **Style:** inset grouped lists for settings and friends, rows with a colored SF Symbol tile, title in body, chevron.
- **Selected:** Periwinkle Deep fill with white text in split views.
- **Chat rows:** avatar (stacked pair for groups), name in headline, preview in subheadline, time in caption, an unread count badge in system red.

### Navigation
- **Tab bar:** Friends, Chats, Settings with SF Symbols; the unread count badge on Chats. On an open Duo the tabs become a glass pill on the trailing edge.
- **Chat title:** a glass capsule with the chat name and, under it, what the app actually knows (a group's members, or the language the other person writes in).

### Menus
- **Chat menu:** a system menu from the toolbar circle in three sections: the on-device AI (Summarize, Meeting Notes), finding things (Search, Bookmarks), and this chat's settings (Translate Messages toggle, Mute, Disappearing Messages, Background). Each item has an SF Symbol.
- **Summary offer:** opening a chat with 10 or more unread messages shows a glass strip under the title, "Catch up with a summary", with a close button.

## Do's and Don'ts

### Do:
- **Do** keep original and translation in one bubble, translation under a divider, its state (translating, translated, failed) shown exactly.
- **Do** mark a sender's language with its code ("JA") on the avatar, not a flag: a language isn't a country.
- **Do** use system text styles, semantic colors, SF Symbols, and platform controls before anything custom.
- **Do** give every tappable control a 44pt by 44pt target, growing the touch area around smaller visuals.
- **Do** check every screen in light, dark, Increase Contrast, and the largest text size.

### Don't:
- **Don't** put white text on Periwinkle Mist.
- **Don't** show status the app can't know: no online dots, no "Connecting…" banners, no invented presence.
- **Don't** show a translation the app didn't actually produce; say it couldn't translate.
- **Don't** use Periwinkle as decoration or a background wash.
- **Don't** use sharp-cornered boxes, black borders, or hand-made blur in place of system glass.
