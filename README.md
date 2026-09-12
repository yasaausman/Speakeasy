# Speakeasy

[![CI](https://github.com/yasaausman/Speakeasy/actions/workflows/ci.yml/badge.svg)](https://github.com/yasaausman/Speakeasy/actions/workflows/ci.yml)

**Speak or type what you need, in your language. Speakeasy finds the business, makes the English phone call, finishes the task, and tells you out loud — and in text — what happened, in your language.**

Just say *"book me a dentist near me"* or *"order from Dave's Hot Chicken"* — Speakeasy detects your language, looks up the real number, and calls. You never dial, and you never need to know the number.

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
│  • tap-to-talk / type    │ ─────▶ │  • intent classify +     │ ─────▶ │  places  │
│  • auto-detect language  │        │    business search       │        │  the real│
│  • location ("near me")  │        │  • orchestrator + confirm│        │  call    │
│  • confirm gate          │ ◀───── │  • server/calle/ client  │ ◀───── │          │
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

> The full, up-to-date checklist of everything built and what's left lives in
> **[MILESTONES.md](MILESTONES.md)**.

### ✅ Done

- **M0 · CALL-E proven** — `server/calle/` client (types, OAuth transport, `CalleClient`) drives `plan_call → run_call → poll get_call_run` and normalizes to a `CallResult`. `scripts/smoke-call.ts` runs the full workflow; **dry-run green** and **real calls verified** (OAuth authenticated, live call placed). Flip with `CALLE_MODE=real`.
- **M1 · iOS app shell** — SwiftUI app runs in the simulator (iPhone 17 Pro, iOS 26.5). Full loop verified on-device: goal → **confirm gate** → call → **result card**.
- **A1 · Backend API + orchestrator** — Fastify service (`POST /api/sessions`, `/goal`, `/confirm`, `GET /api/sessions/:id`) over the `server/calle/` client + the state-machine (confirm gate, background poll loop). Verified end-to-end with the fake transport — **zero calls**.
- **A2 · App wired to the backend** — app defaults to `LiveSpeakeasyAPI`; verified in the simulator app ⇄ backend ⇄ CALL-E (dry-run): goal → readback from the orchestrator → confirm → result card with confirmation number.
- **Multi-language** — **12 languages** (English, Spanish, Chinese, Hindi, Arabic, Vietnamese, French, Portuguese, Korean, Tagalog, Russian, Haitian Creole). Searchable picker; **RTL layout** for Arabic. All via the backend translation layer.
- **App features** — burger-menu navigation; **live call transcript** streamed during the call (chat bubbles); **Your details** vault (name/insurance/DOB/… auto-attached so the agent can answer the rep); **call history** (persisted); **Add to Calendar** (EventKit) from a booked appointment; a "How it works" onboarding screen.
- **Trust & completion** — **confidence + evidence badge** on results; **gap-surfacing** (when the rep needs info you didn't provide) with **Try again**; **editable brief** on the confirm screen (add a detail, change/pick the number from Contacts); **text-forward mode** (Deaf/HoH — no audio); **book the winner** one-tap after a comparison.
- **A3 · First real call** ☎️ — a real CALL-E call completed end-to-end (`COMPLETED`, real transcript, task confirmed). Fixed auth (reuse the `calle` CLI token) and result extraction (CALL-E nests `result.{summary,transcript}`) along the way.
- **A4 · Live translation** — Gemini wired (`gemini-flash-latest`); verified in the app: English goal → real Spanish/Hindi/Arabic readback + narration, both directions. `.env` auto-loaded by the backend.
- **B1 · Voice in** 🎙️ — press-and-hold mic → `SFSpeechRecognizer` (native, on-device STT) → transcript rejoins the pipeline. Permission flow verified in the simulator.
- **B2 · Voice out** 🔊 — `AVSpeechSynthesizer` (native TTS) speaks the readback and the result in the user's language; confirmation numbers read digit-by-digit; "Play narration" replays. Verified end-to-end.
- **C1 · Multi-call comparison** 🏆 — fans out N calls in parallel, Gemini ranks the outcomes for any goal ("soonest"/"cheapest"/…), and the app shows a ranked list + a highlighted best option, narrated aloud in the user's language.
- **Finds the number for you** 🔎 — business lookup via **Gemini Google-Search grounding** turns a goal + your location into real phone numbers. The confirm gate shows the business **name · number · address** before anything dials — so a wrong lookup never places a call. No need to know the number.
- **Infers the mode** — the backend classifies each goal into **book** (a specific task), **compare** (a recommendation / "which is best" → call a few and rank), or **discover** (availability-first). The old mode toggles are gone; you just say what you want.
- **Auto-detects your spoken language** — `NLLanguageRecognizer` picks up the language from the transcript, and the readback, translation, and voice follow it. Seeds from the device language; the picker still works as a manual override.
- **Location-aware** 📍 — CoreLocation resolves a coarse "City, ST" for "near me" lookups (permission-gated; a lookup still works without it, just less targeted).
- **Answers in text *and* audio** — every agent answer shows on-screen in your language and is spoken aloud (text-only in text-forward mode), with a play/stop replay.
- **Safe payments** 💳 — a **Pay on pickup / delivery / card-on-file** preference the agent conveys out loud. Speakeasy **never stores or reads card numbers** — the brief explicitly forbids it.
- **Runs on a physical iPhone** 📱 — signed with a personal team, installed over Wi-Fi, real on-device STT verified. A startup banner shows the live CALL-E mode + providers, with a loud warning when real calls are armed.

### ⬜ To do

- **Record the ~3-minute demo video** and **submit the Devpost form.** The submission PR to [`CALLE-AI/awesome-phone-call-agents`](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/449) is already open and passing their validator.

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
  search/             business lookup (Gemini Google-Search grounding + mock)
  language/           languages, translation, intent classifier, ranker, slots
                      (Gemini > OpenAI > offline passthrough/heuristics)
scripts/
  smoke-call.ts       CALL-E end-to-end smoke test (fake by default, --real to call)
```

## Verify it works (one command, zero infrastructure)

No Mac, Xcode, API keys, or real calls needed — the CALL-E layer runs on a fake
transport and the language layer runs offline. On any machine with Node:

```bash
npm install
npm test            # 5 deterministic end-to-end flow tests (<1s)
npm run smoke:fake  # full plan → run → poll → normalized result
```

`npm test` asserts the four headline flows — **booking, gap→complete, multi-call
ranking, and speculative discover→slots** — plus preferences composing into the
brief. The same commands run in [CI](.github/workflows/ci.yml) on every push.
A **synthetic** sample result (reserved fictional data) showing the shape of a
completed run is at [`docs/sample-run.json`](docs/sample-run.json), and two
reproducible integration issues we reported upstream are written up in
[`docs/CALLE-INTEGRATION-FEEDBACK.md`](docs/CALLE-INTEGRATION-FEEDBACK.md).
(No real call transcripts or identifiers are committed to this repository.)

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

**Real language + search:** set `GEMINI_API_KEY` in `.env` (or `OPENAI_API_KEY`) to power **translation**, **business-number search** (Google-Search grounding), and **intent classification**. Without a key everything falls back to offline passthrough/heuristics/mock numbers, so the app still runs. Providers are auto-selected Gemini > OpenAI > offline; the backend logs which on startup.

**Real calls (go-live).** First authenticate the `calle` CLI and place one harmless self-test call to your own phone (also proves auth):

```bash
SMOKE_TARGET_NUMBER=+1yourphone npm run smoke:real
```

Then set `CALLE_MODE=real` in `.env` and `npm run dev`. The startup banner shows `calle=real` and warns that confirmed goals now place **real** calls. The **confirm gate** still guards every call — nothing dials without your explicit "yes."

**On a physical device:** the app points at `http://localhost:3000`, which is the *phone itself* on-device — set the backend's LAN IP + an ATS exception (see [ios/README.md](ios/README.md)). The simulator needs no change.

**iOS project details:** see [ios/README.md](ios/README.md).

## Guardrails (non-negotiable)

- **Confirm gate:** no paid call goes out without an explicit user "yes" — a mistranslation must never cost a call.
- **AI disclosure:** every brief identifies the caller as an AI assistant acting on the user's behalf (`CallBrief.agentDisclosure`).
- **Dry-run first, always.** The backend is `CALLE_MODE=fake` by default; real calls need an explicit opt-in and are announced in the startup banner.
- **No card data, ever.** Speakeasy never stores or transmits card numbers. Payment is a spoken preference only (e.g. "pay on pickup"), and the brief explicitly forbids the agent from reading card details over the call.
- **Sensitive data** (insurance, DOB) stays in session memory, is never logged in plaintext, and never appears in the public demo video.

## Roadmap

More language pairs (the pipeline is already language-agnostic), saved profiles for repeat facts, persistent callback-camping, and accessibility polish for Deaf and hard-of-hearing users.
