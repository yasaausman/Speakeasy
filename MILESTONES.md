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
  reuse; nested `result{}` extraction). Redacted proof: `docs/sample-run.json`.
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

- [x] **Visual world (warm) built**, then **redesigned to calm-blue** per your
  preference (cool blue-gray grounds, one blue tint, teal accent, SF Rounded,
  breathing voice orb). Light + dark verified. Documented in `ios/DESIGN.md`.

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
- [x] **Committed real sample run** — `docs/sample-run.json`.
- [x] **MIT license + CI badge + Verify section** in the README.

## Sponsor engagement & submission

- [x] **Filed integration feedback issue** →
  [call-e-integrations#126](https://github.com/CALLE-AI/call-e-integrations/issues/126).
- [x] **Opened the submission PR** →
  [awesome-phone-call-agents#449](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/449)
  — `apps/typescript/speakeasy/` catalog entry; their repository validator passes.

---

## Still to do

- [ ] **Record the ~3-minute demo video** (problem → payoff arc). *Time-sensitive.*
- [ ] **Submit the Devpost form** (paste the submission PR link). *Time-sensitive.*
- [ ] **Pick one headline beat** for the video/README pitch (speak in Spanish → real
  English call → booked → narrated back), with everything else as "and it also…".

## Later / optional (deferred by choice)

- [ ] **UI interactivity pass** — audio-reactive orb, animated transcript, haptics,
  smoother transitions (app is currently functional but static).
- [ ] **#6 real-time live push** (see Smart booking loop).
- [ ] **Rename the app** — under consideration (currently "Speakeasy").
