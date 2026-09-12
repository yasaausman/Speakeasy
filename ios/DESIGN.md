# Speakeasy — Design system (iOS)

A **playful, vibrant, trustworthy** world for an app that makes scary English
phone calls on the user's behalf. Friendly and reassuring — a companion, not a
cold utility. Native SwiftUI, HIG-respecting (Dynamic Type, semantic dark mode,
one interactive tint, SF Symbols, system controls, in-context permissions).

Source of truth: `Speakeasy/Design/Theme.swift` (tokens + components + haptics)
and `Speakeasy/Design/VoiceOrb.swift` (signature element).

## Palette (adapts light ⇄ dark)

| Role | Light | Dark |
| --- | --- | --- |
| ground | `#F4F7F6` soft mint-gray | `#1A1C19` |
| groundTop (gradient top) | `#FCFEFD` | `#23261F` |
| surface (cards) | `#FFFFFF` | `#2A2D2A` |
| surfaceSunk | `#E8ECEB` | `#141513` |
| ink | `#2D3748` | `#F7FAFC` |
| inkSecondary | `#626C7A` | `#A0AEC0` |
| **primary (sky blue, the one tint)** | `#1CB0F6` | `#1CB0F6` |
| primaryDeep | `#1899D6` | `#1899D6` |
| accent (playful orange) | `#FF9600` | `#FF9600` |
| success (bouncy green) | `#58CC02` | `#58CC02` |
| warning (friendly amber) | `#FFC800` | `#FFC800` |
| hairline | `#E2E8F0` | `#4A5568` |

Sky blue is the single interactive tint (orb idle, buttons, toggles, links, nav).
Green = listening / success; amber = "couldn't hear" and gentle notices; orange =
accents and the multi-call winner. The ground uses a subtle top-down gradient
(`Theme.backgroundGradient`) so screens read with depth, not flat gray.
`inkSecondary` is tuned to clear **WCAG AA** contrast on the ground.

## Type

SF Rounded app-wide (`.fontDesign(.rounded)`), system text styles only (Dynamic
Type). Weight and size carry hierarchy; no hard-coded point sizes.

## Shape, depth, motion

- Cards: 32pt continuous radius, surface fill, hairline, soft shadow. `.softCard()`.
- Buttons: `PrimaryPill` (blue), `SoftPill` (surface). 52pt min height. All primary
  tap targets ≥ 44pt.
- **Haptics** (`Theme.swift` → `Haptics`): light tap on a starter chip, medium on
  "Yes, call", success notification on a completed booking.
- **Signature:** `VoiceOrb` — a sky-blue orb with a **mascot face** that breathes
  and blinks (Reduce-Motion aware); turns green + smiles while listening, amber on
  a mic/speech error.

## Navigation & screens

- **Burger drawer** (`SideDrawer`) from the leading edge → Home, Your details,
  History, How it works, plus a Language quick row. Dim scrim, spring slide.
- **Home** (`HomeView`): orb + localized greeting → **starter chips** (tappable,
  localized example goals that solve the blank-canvas problem) → confirm gate →
  **live call transcript** (chat bubbles: Agent / Them, auto-scrolling) →
  result / ranked. Location is requested **in context** (first goal submit), never
  on cold launch.
- **Your details** (`SavedDetailsView`): the facts vault + booking preferences +
  safe payment preference (never card numbers) + calendar & accessibility toggles.
- **History** (`HistoryView`): past calls with outcomes, confirmation chips, and
  replay; friendly empty state.
- **How it works** (`AboutView`): calm 4-step, text-forward (accessibility).
- **Language** (`LanguagePickerView`): searchable sheet, 12 languages; full **RTL**
  for Arabic (the whole UI mirrors — verified).
- **Result** (`ResultCardView`): status, confidence + evidence badge, confirmation
  chip, gap-surfacing + retry, Play narration, **Add to Calendar** (EventKit),
  collapsible English transcript, and a confetti burst on success.

## Localization

Every user-facing readback/outcome flows through the backend translation layer.
On-device, the Home greeting, starter chips, and the two Home captions are
localized into the app's languages (`Models/Suggestions.swift`) with an English
fallback. Remaining static UI chrome (button labels) is a candidate for a future
full-i18n pass.

## Direction contract

Recorded in `Design/Theme.swift`'s opening comment. Direction evolved
warm → calm-blue → **playful & vibrant** (user-pinned sky-blue with a mascot orb).
