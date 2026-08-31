# Speakeasy — Design system (iOS)

A **warm, human** world for an app that makes scary English phone calls on the
user's behalf. It refuses the cold utility-app look for something caring and
reassuring — because the people it serves have phone anxiety, limited English,
or disabilities. Built native SwiftUI, HIG-respecting (Dynamic Type, semantic
dark mode, one interactive tint, SF Symbols, system controls).

Source of truth: `Speakeasy/Design/Theme.swift` (tokens + components) and
`Speakeasy/Design/VoiceOrb.swift` (signature element).

## Palette (adapts light ⇄ dark)

| Role | Light | Dark |
| --- | --- | --- |
| ground | `#F5EDE1` warm cream | `#191512` warm charcoal |
| surface (cards) | `#FFFDF8` | `#241E19` |
| surfaceSunk | `#F0E7D8` | `#2C251E` |
| ink | `#2B2723` | `#F4ECE0` |
| inkSecondary | `#6E655B` | `#B2A798` |
| **primary (coral, the one tint)** | `#E15E43` | `#F47C61` |
| primaryDeep | `#C64E36` | `#EF6A4E` |
| honey (highlights only) | `#D98A24` | `#F0B152` |
| success | `#2F8F5F` | `#59C48D` |
| hairline | `#E7DCCB` | `#362E27` |

Coral is the single interactive tint (buttons, toggle, links, the orb). Honey is
decoration only — the multi-call winner card. Never gray on the warm ground:
secondary text is warm taupe.

## Type

SF Rounded app-wide (`.fontDesign(.rounded)`) — friendly and highly legible.
System text styles only (Dynamic Type): Large Title (screen title), Title/Title2/
Title3 for headings and body-of-note, Body, Subheadline, Footnote, Caption.
Weight and size carry hierarchy; no hard-coded point sizes.

## Shape, depth, motion

- Cards: 24pt continuous-corner radius, warm surface, 1px hairline, soft shadow
  (`black 6%`, radius 18, y 10). Reusable via `.softCard(_:stroke:)`.
- Buttons: `PrimaryPill` (coral fill, white, capsule, coral glow) and `SoftPill`
  (surface, ink, hairline). 52pt min height (≥44pt touch target).
- Chips: 14pt radius, tinted from coral/honey at ~12% for the confirmation number
  and play/replay pills.
- **Signature:** `VoiceOrb` — a coral orb with two soft glow rings that gently
  breathes (2.6s ease-in-out, honors Reduce Motion), turning red + waveform while
  listening. It is the invitation to speak and the calling indicator.

## Screens

- **Input:** large title, centered breathing orb, friendly prompt, soft capsule
  text field + circular coral send, a soft-card "Compare places" toggle.
- **Confirm gate:** coral quote-bubble mark, big "Did I get this right?", the
  read-back in a soft speech-bubble card, number with phone icon, Edit / Yes-call
  pills. No paid call before an explicit yes.
- **Calling:** the orb again, with a status line.
- **Result:** soft-card with a green "Done", the outcome in the user's language,
  a coral confirmation chip, a warm "Play narration" pill, a sunk transcript
  disclosure, and a coral "New request".
- **Ranked (multi-call):** a honey-lit "Best option" winner card, then numbered
  warm rows best-first.

## Direction contract

Recorded in `Design/Theme.swift`'s opening comment (THESIS / OWN-WORLD / STORY /
FIRST VIEWPORT / FORM / FINISH). Direction "warm-human" was pinned by the user.
