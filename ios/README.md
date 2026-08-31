# Speakeasy — iOS app

Voice-first SwiftUI client for Speakeasy. The app is the user's side (tap-to-talk,
confirm gate, live status, result card). All CALL-E logic stays on the Node
backend — the app only talks to it over HTTP (see `Networking/SpeakeasyAPI.swift`).

> **Status:** ✅ builds and runs in the iOS Simulator (verified on iPhone 17 Pro,
> iOS 26.5). Runs against the built-in **mock** — no backend, no CALL-E, no calls.
> The full flow works: type a goal → confirm gate (Spanish readback) → mock call →
> translated result card.

## Files

```
Speakeasy/
  SpeakeasyApp.swift              @main entry
  Models/CallModels.swift         SessionPhase, GoalUnderstanding, CallResult (mirror server/calle/types.ts)
  Networking/SpeakeasyAPI.swift   protocol + MockSpeakeasyAPI (runs standalone) + LiveSpeakeasyAPI (Node backend)
  ViewModels/SessionViewModel.swift  the state machine + confirm gate + poll loop
  Views/ContentView.swift         the single screen (input → confirm → status → result)
  Views/ResultCardView.swift      outcome, confirmation number, transcript
  Speech/SpeechManager.swift      STT/TTS stub (Phase M3)
```

## Build & run

The Xcode project is **generated from `project.yml`** with [XcodeGen] — it is not
committed (see root `.gitignore`). Regenerate it any time you add/rename a source
file:

```bash
cd ios
xcodegen generate          # writes Speakeasy.xcodeproj
open Speakeasy.xcodeproj    # then ⌘R on an iPhone simulator
```

Or build & launch from the command line:

```bash
cd ios
xcodegen generate
xcodebuild -project Speakeasy.xcodeproj -scheme Speakeasy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build build
xcrun simctl boot "iPhone 17 Pro"; open -a Simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Speakeasy.app
xcrun simctl launch booted com.speakeasy.app
```

[XcodeGen]: https://github.com/yonaskolb/XcodeGen  (`brew install xcodegen`)

## Switching from mock to the real backend (Phase M1)

In `SessionViewModel.init`, pass `LiveSpeakeasyAPI()` instead of the default
`MockSpeakeasyAPI()`. The simulator reaches the Mac's `localhost:3000` directly,
so no tunnel is needed while the Node backend runs locally.

## Mobile build phases

| Phase | Scope | Needs |
| --- | --- | --- |
| **M0** | SwiftUI shell runs in simulator on the mock — full state machine, no backend | Xcode |
| M1 | Swap to LiveSpeakeasyAPI; wire to Node backend (English text) | backend Phase 1 |
| M2 | Spanish text in/out (backend translation) | backend Phase 2 |
| M3 | Voice: SFSpeechRecognizer (STT) + AVSpeechSynthesizer (TTS) | mic/speech Info.plist keys |
| M4 | Multi-call comparison view | backend Phase 4 |
```
