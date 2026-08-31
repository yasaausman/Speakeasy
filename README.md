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
- **M1 · iOS app shell** — SwiftUI app runs in the simulator (iPhone 17 Pro, iOS 26.5). Full loop verified on-device: goal → **confirm gate** → call → **result card**.
- **A1 · Backend API + orchestrator** — Fastify service (`POST /api/sessions`, `/goal`, `/confirm`, `GET /api/sessions/:id`) over the `server/calle/` client + the state-machine (confirm gate, background poll loop). Verified end-to-end with the fake transport — **zero calls**.
- **A2 · App wired to the backend** — app defaults to `LiveSpeakeasyAPI`; verified in the simulator app ⇄ backend ⇄ CALL-E (dry-run): goal → readback from the orchestrator → confirm → result card with confirmation number.
- **Multi-language** — English, Spanish, Hindi, Arabic. In-app language picker; **RTL layout** for Arabic (verified). Language flows through the backend translation layer.
- **A3 · First real call** ☎️ — a real CALL-E call completed end-to-end (`COMPLETED`, real transcript, task confirmed). Fixed auth (reuse the `calle` CLI token) and result extraction (CALL-E nests `result.{summary,transcript}`) along the way.
- **A4 · Live translation** — Gemini wired (`gemini-flash-latest`); verified in the app: English goal → real Spanish/Hindi/Arabic readback + narration, both directions. `.env` auto-loaded by the backend.
- **B1 · Voice in** 🎙️ — press-and-hold mic → `SFSpeechRecognizer` (native, on-device STT) → transcript rejoins the pipeline. Permission flow verified in the simulator.
- **B2 · Voice out** 🔊 — `AVSpeechSynthesizer` (native TTS) speaks the readback and the result in the user's language; confirmation numbers read digit-by-digit; "Play narration" replays. Verified end-to-end.

### ⬜ To do

**Later**

- **C1 · Multi-call comparison** — fan out N calls, rank, narrate a spoken comparison.
- **C2 · Polish + submit** — error/edge handling, backup demo video, submission PR to `CALLE-AI/awesome-phone-call-agents` (`apps/`).

## Layout

```
ios/                  native SwiftUI app (see ios/README.md)
  project.yml         XcodeGen spec → generates Speakeasy.xcodeproj
  Speakeasy/          app sources (Models, Networking, ViewModels, Views, Speech)
server/
  index.ts            Fastify HTTP API the app calls
  calle/              the ONLY place that touches CALL-E MCP
    client.ts         CalleClient: planCall/runCall/getCallRun, pollRun, runBrief
    oauth.ts          Streamable-HTTP + OAuth transport (token cache under .speakeasy/)
    types.ts          CallBrief, CallResult, real tool I/O, terminal statuses
  orchestrator/       session store + state machine (confirm gate, poll loop)
  language/           supported languages + translation layer (OpenAI or passthrough)
scripts/
  smoke-call.ts       CALL-E end-to-end smoke test (fake by default, --real to call)
```

## Run it (app + backend, no calls)

1. **Start the backend** (uses the fake CALL-E transport by default — zero calls):

   ```bash
   npm install
   cp .env.example .env
   npm run dev            # Fastify on :3000
   ```

2. **Run the app** (the simulator reaches the Mac's `localhost:3000`):

   ```bash
   cd ios && xcodegen generate
   xcodebuild -project Speakeasy.xcodeproj -scheme Speakeasy \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build
   xcrun simctl boot "iPhone 17 Pro"; open -a Simulator
   xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Speakeasy.app
   xcrun simctl launch booted com.speakeasy.app
   ```

   Type a goal → confirm → watch the (fake) call complete → result card. Pick a language
   from the globe menu; Arabic switches the UI to RTL.

**Real translation:** set `GEMINI_API_KEY` in `.env` (or `OPENAI_API_KEY`) to translate ES/HI/AR ⇄ EN (otherwise passthrough). Provider is auto-selected Gemini > OpenAI > passthrough; the backend logs which on startup.

**Real call** (spends one of your 20 free calls) — first authenticate the `calle` CLI
(see [call-e-integrations](https://github.com/CALLE-AI/call-e-integrations)):

```bash
SMOKE_TARGET_NUMBER=+1... npm run smoke:real
```

**iOS project details:** see [ios/README.md](ios/README.md).

## Guardrails (non-negotiable)

- **Confirm gate:** no paid call goes out without an explicit user "yes" — a mistranslation must never cost a call.
- **AI disclosure:** every brief identifies the caller as an AI assistant acting on the user's behalf (`CallBrief.agentDisclosure`).
- **Dry-run first, always.** Real calls only on deliberate smoke tests.
- **Sensitive data** (insurance, DOB) stays in session memory, is never logged in plaintext, and never appears in the public demo video.

## Roadmap

More language pairs (the pipeline is already language-agnostic), saved profiles for repeat facts, persistent callback-camping, and accessibility polish for Deaf and hard-of-hearing users.
