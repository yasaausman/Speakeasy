# Speakeasy — Milestones

The running checklist of what's built. **Everything below marked `[x]` is done and
verified**; the open items are at the bottom. Built for the CALL-E "Your Code Is
Calling" hackathon (Aug 30 – Sep 2026).

Repo: <https://github.com/yasaausman/Speakeasy> · CI: green · License: MIT

---

## Foundation

- [x] **M0 — Prove CALL-E.** `server/calle/` client (types, OAuth transport,
  `CalleClient`) drives `plan_call → run_call → poll get_call_run`, normalized to a
  `CallResult`. Dry-run smoke green.
- [x] **M1 — iOS app shell.** Native SwiftUI app runs in the simulator (iPhone 17
  Pro, iOS 26.5); full flow verified against a mock.

## Track A — make the calls real

- [x] **A1 — Backend API + orchestrator.** Fastify service (`/api/sessions`,
  `/goal`, `/confirm`, `GET /api/sessions/:id`) over the state machine (confirm
  gate + background poll loop).
- [x] **A2 — App wired to backend.** App ⇄ Node backend ⇄ CALL-E, verified in the
  simulator against the fake transport (zero calls).
- [x] **A3 — First real call.** A real CALL-E call completed end-to-end
  (`COMPLETED`, real transcript). Fixed two integration bugs on the way (auth token
  reuse; nested `result{}` extraction). The committed `docs/sample-run.json` is a
  **synthetic** stand-in (reserved fictional data) showing the result shape — no
  real call data is committed; reproduce a real run with `npm run smoke:real`.
- [x] **A4 — Live translation.** Gemini wired (`gemini-flash-latest`), auto-selected
  Gemini > OpenAI > passthrough; `.env` auto-loaded. Verified both directions.

## Track B — voice (native, on-device)

- [x] **B1 — Voice in.** Press-and-hold mic → `SFSpeechRecognizer` → goal.
- [x] **B2 — Voice out.** `AVSpeechSynthesizer` speaks the read-back and result;
  confirmation numbers read digit-by-digit; replayable.

## Languages & accessibility

- [x] **12 languages** — English, Spanish, Chinese, Hindi, Arabic, Vietnamese,
  French, Portuguese, Korean, Tagalog, Russian, Haitian Creole; searchable picker.
- [x] **RTL layout** for Arabic (whole UI mirrors).
- [x] **Text-forward mode** for Deaf / hard-of-hearing users (no audio required).

## Multi-call (C1)

- [x] **Comparison + ranking.** Fan out N calls in parallel, Gemini ranks the
  outcomes for the goal ("soonest"), ranked list + highlighted best option.
- [x] **Book the winner** — one tap after a comparison places the booking call.

## Design

- [x] **Visual world (warm) built**, then **redesigned to calm-blue**, then evolved
  to a **playful & vibrant** look — friendly sky-blue primary, a bouncy **mascot
  face** on the voice orb (eyes + expressive mouth), and a **confetti burst** on a
  successful booking (`ConfettiView`). Light + dark verified. Documented in
  `ios/DESIGN.md`.

## Native device bring-up & voice UX

- [x] **Runs on a physical iPhone.** Signed with a free Personal Team (local dev
  bundle id `com.yasaausman.speakeasy`), installed and launched on-device; **real
  on-device speech-to-text verified** (Hindi and Spanish transcribed live under the
  orb) — something the simulator can't do (no sustainable mic).
- [x] **Push-to-speak fixed.** A teammate's `HoldButtonStyle` didn't fire
  press/release; replaced with a `DragGesture(minimumDistance: 0)` plus a
  `wantsListening` guard so hold-to-talk works reliably.
- [x] **Friendly error banner.** Speech/mic failures were silent; now a soft,
  dismissible amber banner explains them and points to the type-below fallback
  (`ErrorBanner`), with `SpeechManager` changes forwarded through the view model so
  the live orb/caption and errors refresh reliably.
- [x] **Expressive voice orb.** Green while listening, amber when it can't hear,
  blue idle; smiling open mouth while listening (was an upside-down frown).
- [x] **Easy keyboard dismissal.** Tap any empty area, swipe down, a Done button
  above the keyboard, or grab the orb.

## Navigation & core features

- [x] **Burger-menu navigation** (`SideDrawer`) → Home / Your details / History /
  How it works / Language.
- [x] **Live call transcript** — CALL-E activity streamed into the app as
  auto-scrolling chat bubbles during the call.
- [x] **Saved details vault** — name, callback, insurance, DOB, address; shared
  only when a rep asks.
- [x] **Call history** — persisted, with outcomes, confirmation chips, and replay.
- [x] **Add to Calendar** — EventKit event on a booking.
- [x] **Confidence + evidence badge** on results.
- [x] **Gap surfacing + retry** — when the rep needs missing info.
- [x] **Editable brief / change number** — add a detail or pick a number (Contacts)
  before calling.

## Smart booking loop

- [x] **#1 Front-loaded preferences** — preferred/fallback/avoid/budget compose into
  the brief so the agent handles an unavailable slot itself.
- [x] **#2 Auto Apple Calendar (enriched)** — auto-add on a booking, with location,
  tap-to-call reschedule number, and day-before + hour-before alarms.
- [x] **#3 Free/busy-aware booking** — reads calendar availability so the agent only
  asks for slots you're free for.
- [x] **#4 Speculative two-call booking** — call 1 finds available times → you pick →
  call 2 books it. Verified end-to-end in the simulator.
- [x] **#5 Defer + call back** — gap card with an inline answer field that saves to
  the vault and calls back.
- [ ] **#6 Real-time "tap a slot" live push** — *deferred (phase 2)*: needs CALL-E's
  Developer API + webhooks; MCP is one-shot async with no live hold.

## Hackathon build-proof

- [x] **Deterministic tests** — `npm test`: 5 offline end-to-end flow tests
  (booking, gap→complete, multi-call ranking, discover→slots, preferences→brief).
- [x] **CI** — `.github/workflows/ci.yml` runs type-check + tests + fake smoke on
  every push (green).
- [x] **One-command, zero-infra proof** — `npm test` and `npm run smoke:fake` need no
  Mac, keys, or real calls.
- [x] **Committed sample run** — `docs/sample-run.json` (**synthetic**, reserved
  fictional data showing the normalized result shape; not a real transcript).
- [x] **MIT license + CI badge + Verify section** in the README.

## Sponsor engagement & submission

- [x] **Filed integration feedback issue** →
  [call-e-integrations#126](https://github.com/CALLE-AI/call-e-integrations/issues/126).
- [x] **Opened the submission PR** →
  [awesome-phone-call-agents#449](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/449)
  — `apps/typescript/speakeasy/` catalog entry; their repository validator passes.

---

## Still to do

- [ ] **Reach the backend from the phone.** The app still points at
  `http://localhost:3000`, so on-device the call flow shows "Could not connect to
  the server" (on-device STT already works offline). Needs `baseURL` → the Mac's LAN
  IP (e.g. `http://10.0.0.91:3000`) + an ATS exception for the plain-`http` LAN call.
  Backend already binds `0.0.0.0:3000`, so no server change is needed — just run
  `npm run dev` on the Mac with both on the same Wi-Fi.
- [ ] **Record the ~3-minute demo video** (problem → payoff arc). *Time-sensitive.*
- [ ] **Submit the Devpost form** (paste the submission PR link). *Time-sensitive.*
- [ ] **Pick one headline beat** for the video/README pitch (speak in Spanish → real
  English call → booked → narrated back), with everything else as "and it also…".

## Later / optional (deferred by choice)

- [ ] **UI interactivity pass** — audio-reactive orb (react to mic amplitude),
  animated transcript, haptics, smoother transitions. (The orb now breathes, colors
  by state, and has a mascot face + confetti, but isn't yet audio-reactive.)
- [ ] **#6 real-time live push** (see Smart booking loop).
