# Speakeasy — iOS app

Voice-first SwiftUI client for Speakeasy. The app is the user's side (tap-to-talk,
confirm gate, live status, result card). All CALL-E logic stays on the Node
backend — the app only talks to it over HTTP (see `Networking/SpeakeasyAPI.swift`).

> **Status:** stub scaffold, written before Xcode was installed. These are real
> Swift sources but have not been compiled yet. Once Xcode is installed we create
> the project, add these files, and it runs in the simulator against the built-in
> **mock** (no backend, no CALL-E, no calls).

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

## Creating the Xcode project (once Xcode is installed)

1. First point the toolchain at Xcode (needs your password):
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```
2. Xcode → File → New → Project → **iOS App**.
   - Product Name: `Speakeasy`
   - Interface: **SwiftUI**, Language: **Swift**
   - Save it inside `ios/` (or let Claude generate the project — see below).
3. Delete the default `ContentView.swift`/`App.swift` Xcode made, then drag the
   files under `ios/Speakeasy/` into the project (check "Create groups").
4. Pick an iPhone simulator and Run (⌘R). It launches on the **mock** API, so you
   can walk the full flow — type a goal → confirm → watch the fake call → result.

> Tell Claude when Xcode is ready and it can generate the `.xcodeproj` and run/
> screenshot the app in the simulator for you.

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
