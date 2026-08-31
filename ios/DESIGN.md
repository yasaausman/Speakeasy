# Speakeasy — Design system (iOS)

A **calm, blue** world for an app that makes scary English phone calls on the
user's behalf. Cool and trustworthy, not a cold utility app. Native SwiftUI,
HIG-respecting (Dynamic Type, semantic dark mode, one interactive tint, SF
Symbols, system controls).

Source of truth: `Speakeasy/Design/Theme.swift` (tokens + components) and
`Speakeasy/Design/VoiceOrb.swift` (signature element).

## Palette (adapts light ⇄ dark)

| Role | Light | Dark |
| --- | --- | --- |
| ground | `#EDF1F7` cool blue-gray | `#0E1420` deep navy |
| surface (cards) | `#FCFDFF` | `#18202E` |
| surfaceSunk | `#E3EAF3` | `#1E2838` |
| ink | `#1B2430` | `#E9EEF6` |
| inkSecondary | `#5B6675` | `#94A2B6` |
| **primary (blue, the one tint)** | `#2F6FE4` | `#5B8DEF` |
| primaryDeep | `#2559C0` | `#4A7CE0` |
| accent (teal, highlights only) | `#0E97A6` | `#2CC5CE` |
| success | `#1E9A66` | `#4FC48A` |
| hairline | `#DCE4EE` | `#263349` |

Blue is the single interactive tint (orb, buttons, toggle, links, nav). Teal is
decoration only — the multi-call winner card and the Add-to-Calendar action.
Never beige; grounds are cool blue-gray.

## Type

SF Rounded app-wide (`.fontDesign(.rounded)`), system text styles only (Dynamic
Type). Weight and size carry hierarchy; no hard-coded point sizes.

## Shape, depth, motion

- Cards: 24pt continuous radius, cool surface, hairline, soft shadow. `.softCard()`.
- Buttons: `PrimaryPill` (blue), `SoftPill` (surface). 52pt min height.
- **Signature:** `VoiceOrb` — a blue orb that gently breathes (Reduce-Motion
  aware); turns red + waveform while listening.

## Navigation & screens

- **Burger drawer** (`SideDrawer`) from the leading edge → Home, Your details,
  History, How it works, plus a Language quick row. Dim scrim, spring slide.
- **Home** (`HomeView`): orb + prompt → confirm gate → **live call transcript**
  (chat bubbles: Agent / Them, auto-scrolling) → result / ranked.
- **Your details** (`SavedDetailsView`): the facts vault — name, callback,
  insurance, DOB, address; auto-saved, shared only when a rep asks.
- **History** (`HistoryView`): past calls with outcomes, confirmation chips, and
  replay; empty state.
- **How it works** (`AboutView`): calm 4-step, text-forward (accessibility).
- **Language** (`LanguagePickerView`): searchable sheet, 12 languages.
- **Result** (`ResultCardView`): outcome, confirmation chip, Play narration, and
  **Add to Calendar** (EventKit) when an appointment is present.

## Direction contract

Recorded in `Design/Theme.swift`'s opening comment. Direction "calm-blue" pinned
by the user (replacing the earlier warm world).
