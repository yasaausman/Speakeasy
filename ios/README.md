# Speakeasy iOS

Native SwiftUI client, iOS 17+. The normal app uses `LiveSpeakeasyAPI` over HTTP; CALL-E authentication and phone calls stay on the Node backend.

## Build

```bash
xcodegen generate --spec ios/project.yml
open ios/Speakeasy.xcodeproj
```

Run from the repository root. The generated project and build outputs are ignored by Git.

Simulator backend default: `http://localhost:3000`. Physical-device testing requires the Mac's LAN address, configured through `SPEAKEASY_BACKEND_URL` in the Xcode scheme or `SpeakeasyBackendURL` in Info.plist. The phone and Mac must share a network.

## Debug UI rehearsal

Set `SPEAKEASY_DEMO_SCENARIO` to `success`, `gap`, or `pending`, and `SPEAKEASY_DEMO_LANGUAGE=hi`. These launch the labeled simulated API, with fictional details and no backend or real calls. Set `SPEAKEASY_DEMO_AUDIO=1` for native narration. Remove the variables for normal use. The demo is compiled only in Debug.

## Core files

- `Views/RootView.swift`: navigation and API selection.
- `Views/HomeView.swift`: input, readback/confirmation and English call activity.
- `ViewModels/SessionViewModel.swift`: session coordination, explicit approval, polling, pending recovery and retained-business follow-ups.
- `Views/ResultCardView.swift`: verified success, missing information, pending outcomes, and reviewed calendar dates.
- `Models/CallModels.swift`: wire models and outcome semantics.
- `Models/Strings.swift`: existing multi-language UI strings.
- `Models/FlowStrings.swift`: additional Hindi workflow/recovery copy.
- `Speech/SpeechManager.swift`: Apple recognition and synthesis (not a guarantee of entirely on-device recognition).
- `Stores/AppStore.swift`: UserDefaults details/history. Prototype storage, not an encrypted vault.

## Verification

`SpeakeasyTests` covers task completion, ambiguous calendar dates, and preserving the original business on slot selection. `SpeakeasyUITests` covers launch/language persistence and simulated Hindi success, missing information and pending recovery. See `docs/submission/VERIFICATION.md` for results and limitations.
