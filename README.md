# Speakeasy

**Speak or type what you need, in your language. Speakeasy makes the English phone calls, finishes the task, and tells you out loud — and in text — what happened, in your language.**

Built for the [CALL-E "Your Code Is Calling"](https://devpost.com) hackathon. CALL-E places and holds the live English phone call; Speakeasy is the language bridge and the app around it — a **native iOS app** backed by a small Node service.

## Why it's defensible — the four-part wedge

No existing product sits on all four at once:

1. **Language-first UX** — built around *not* speaking English, not a language flag bolted onto an English app.
2. **Voice and text in, voice and text out** — both modes, both directions.
3. **Actually finishes the task** — books, confirms, and captures the reference number. Not just a price lookup.
4. **Built for the underserved user** — limited English, phone anxiety, disability, or no time during business hours.

## Architecture

```
┌─────────────────────────┐        ┌──────────────────────────┐        ┌──────────┐
│  iOS app (SwiftUI)       │  HTTP  │  Node backend            │  MCP   │  CALL-E  │
│  • tap-to-talk / type    │ ─────▶ │  • orchestrator state    │ ─────▶ │  places  │
│  • confirm gate          │        │    machine + confirm gate│        │  the real│
│  • live status + result  │ ◀───── │  • server/calle/ client  │ ◀───── │  call    │
│  • native STT/TTS        │  poll  │    (OAuth, plan/run/poll) │        └──────────┘
└─────────────────────────┘        └──────────────────────────┘
```

Why the split: CALL-E's phone layer needs OAuth, the MCP client, and a token cache —
that can't live in the app, so it stays on the Node service. The iOS app never speaks
MCP; it only calls the backend over HTTP. Voice (STT/TTS) is **native on-device iOS**,
so the app's voice layer needs no third-party keys.

## The CALL-E contract (ground truth)

The backend talks to CALL-E's OAuth-protected MCP endpoint over Streamable HTTP, using three tools in strict order:

| Tool | Purpose | Key I/O |
| --- | --- | --- |
| `plan_call` | Prepare a call plan (no call placed) | in: `user_input` (+ `to_phones`, `region`, `language`, `goal`); out: `plan_id`, `confirm_token`, `ready_to_run` |
| `run_call` | Place the real call | in: `plan_id`, `confirm_token`; out: `run_id`, `status` |
| `get_call_run` | Poll status/result (read-only) | in: `run_id`; out: `status`, `summary`, `details`, `transcript` |

Poll cadence: first check ~60s after `run_call`, then every 5–10s until a terminal status
(`COMPLETED`, `FAILED`, `NO_ANSWER`, `DECLINED`, `CANCELED`, `VOICEMAIL`, `BUSY`, `EXPIRED`).
`COMPLETED` means the run ended — success is judged from the summary/details, not the status alone.

## Milestones

### ✅ Done

- **M0 · CALL-E proven** — `server/calle/` client (types, OAuth transport, `CalleClient`) drives `plan_call → run_call → poll get_call_run` and normalizes to a `CallResult`. `scripts/smoke-call.ts` runs the full workflow; **dry-run green**. (Real call still pending CALL-E auth.)
- **M1 · iOS app shell** — SwiftUI app runs in the simulator (iPhone 17 Pro, iOS 26.5) against a built-in mock. Full loop verified on-device: type a goal → **confirm gate** (Spanish readback) → mock call → translated Spanish **result card**. No backend, no calls.

### ⬜ To do

**Track A — make the calls real (backend)**

- **A1 · Backend API + orchestrator** — Node HTTP service (`POST /api/sessions`, `/goal`, `/confirm`, `GET /api/sessions/:id`) over the `server/calle/` client and the state machine (confirm gate + poll loop). Testable with the fake transport — **zero calls**.
- **A2 · Wire the app to the backend** — swap `MockSpeakeasyAPI` → `LiveSpeakeasyAPI`; English text end-to-end, app ⇄ backend ⇄ CALL-E (still dry-run).
- **A3 · First real call** — finish `calle auth login`, then one deliberate real smoke call.
- **A4 · Spanish translation** — backend translates ES→EN (goal) and EN→ES (result). Locks the demo language pair.

**Track B — make it talk (voice)**

- **B1 · Voice in** — mic → `SFSpeechRecognizer` (native STT) → goal, rejoining the pipeline after transcription.
- **B2 · Voice out** — `AVSpeechSynthesizer` (native TTS) speaks the readback and the result; confirmation numbers read digit-by-digit.

**Later**

- **C1 · Multi-call comparison** — fan out N calls, rank, narrate a spoken comparison.
- **C2 · Polish + submit** — error/edge handling, backup demo video, submission PR to `CALLE-AI/awesome-phone-call-agents` (`apps/`).

## Layout

```
ios/                  native SwiftUI app (see ios/README.md)
  project.yml         XcodeGen spec → generates Speakeasy.xcodeproj
  Speakeasy/          app sources (Models, Networking, ViewModels, Views, Speech)
server/calle/         the ONLY place that touches CALL-E MCP
  types.ts            CallBrief, CallResult, the real tool I/O, terminal statuses
  oauth.ts            Streamable-HTTP + OAuth transport (token cache under .speakeasy/)
  client.ts           CalleClient: planCall/runCall/getCallRun, pollRun, runBrief
scripts/
  smoke-call.ts       CALL-E end-to-end smoke test (fake by default, --real to call)
```

## Setup

**Backend / CALL-E:**

```bash
npm install
cp .env.example .env
npm run smoke:fake      # full plan→run→poll workflow against a local fake — no auth, no calls
```

Real smoke call (spends one of your 20 free calls) — first authenticate the `calle` CLI
(see [call-e-integrations](https://github.com/CALLE-AI/call-e-integrations)):

```bash
SMOKE_TARGET_NUMBER=+1... npm run smoke:real
```

**iOS app:** see [ios/README.md](ios/README.md) (`brew install xcodegen`, then `cd ios && xcodegen generate`).

## Guardrails (non-negotiable)

- **Confirm gate:** no paid call goes out without an explicit user "yes" — a mistranslation must never cost a call.
- **AI disclosure:** every brief identifies the caller as an AI assistant acting on the user's behalf (`CallBrief.agentDisclosure`).
- **Dry-run first, always.** Real calls only on deliberate smoke tests.
- **Sensitive data** (insurance, DOB) stays in session memory, is never logged in plaintext, and never appears in the public demo video.

## Roadmap

More language pairs (the pipeline is already language-agnostic), saved profiles for repeat facts, persistent callback-camping, and accessibility polish for Deaf and hard-of-hearing users.
