# Speakeasy

**Speak or type what you need, in your language. Speakeasy makes the English phone calls, finishes the task, and tells you out loud — and in text — what happened, in your language.**

Built for the [CALL-E "Your Code Is Calling"](https://devpost.com) hackathon. CALL-E places and holds the live English phone call; Speakeasy is the language bridge and orchestration around it.

## Why it's defensible — the four-part wedge

No existing product sits on all four at once:

1. **Language-first UX** — built around *not* speaking English, not a language flag bolted onto an English app.
2. **Voice and text in, voice and text out** — both modes, both directions.
3. **Actually finishes the task** — books, confirms, and captures the reference number. Not just a price lookup.
4. **Built for the underserved user** — limited English, phone anxiety, disability, or no time during business hours.

## Architecture

```
User speaks/types (their language)
  → STT (if voice) → translate to English
  → read the goal back in their language → WAIT for confirm   ← hard gate, no paid call without an explicit yes
  → build English CallBrief
  → CALL-E: plan_call → run_call → poll get_call_run           ← the phone layer (isolated behind server/calle/)
  → receive structured result + transcript (English)
  → translate → speak + show text + save summary
```

Speakeasy is a **stateful orchestrator** wrapping a **stateless phone layer**. Everything that touches CALL-E's MCP tools lives behind `server/calle/` — the rest of the app never speaks MCP directly.

## The CALL-E contract (ground truth)

Speakeasy talks to CALL-E's OAuth-protected MCP endpoint over Streamable HTTP, using three tools in strict order:

| Tool | Purpose | Key I/O |
| --- | --- | --- |
| `plan_call` | Prepare a call plan (no call placed) | in: `user_input` (+ `to_phones`, `region`, `language`, `goal`); out: `plan_id`, `confirm_token`, `ready_to_run` |
| `run_call` | Place the real call | in: `plan_id`, `confirm_token`; out: `run_id`, `status` |
| `get_call_run` | Poll status/result (read-only) | in: `run_id`; out: `status`, `summary`, `details`, `transcript` |

Poll cadence: first check ~60s after `run_call`, then every 5–10s until a terminal status
(`COMPLETED`, `FAILED`, `NO_ANSWER`, `DECLINED`, `CANCELED`, `VOICEMAIL`, `BUSY`, `EXPIRED`).
`COMPLETED` means the run ended — success is judged from the summary/details, not the status alone.

## Setup

```bash
npm install
cp .env.example .env    # fill in as you reach each phase
```

### Dry-run (no auth, no network, no real call)

```bash
npm run smoke:fake
```

Drives the full `plan → run → poll → terminal` workflow against a local fake and prints a normalized `CallResult`. Use this for all iteration.

### Real smoke test (spends one call from your quota)

CALL-E auth is a one-time browser OAuth flow. Install and authenticate the `calle` CLI first
(see [call-e-integrations](https://github.com/CALLE-AI/call-e-integrations)), then:

```bash
SMOKE_TARGET_NUMBER=+1... npm run smoke:real
```

The first real run opens a browser to authorize; the token is cached under `.speakeasy/` (git-ignored) so later runs skip it. **Each account has 20 free calls — spend them only on deliberate smoke tests and the demo.**

## Build phases

| Phase | Scope | Status |
| --- | --- | --- |
| **0** | Prove CALL-E: hardcoded brief → `plan → run → poll` → structured result | ✅ dry-run green; real call pending auth |
| 1 | Orchestration loop, English only, text only (confirm gate + poll loop) | ⬜ |
| 2 | Add translation (Spanish text in/out) | ⬜ |
| 3 | Add voice (STT in, TTS narration) — **this is the demo** | ⬜ |
| 4 | Multi-call comparison mode | ⬜ |
| 5 | Polish, error handling, demo prep, submission PR | ⬜ |

## Layout

```
server/calle/     the ONLY place that touches CALL-E MCP
  types.ts        CallBrief, CallResult, the real tool I/O, terminal statuses
  oauth.ts        Streamable-HTTP + OAuth transport (token cache under .speakeasy/)
  client.ts       CalleClient: planCall/runCall/getCallRun, pollRun, runBrief, briefToUserInput
scripts/
  smoke-call.ts   Phase 0 end-to-end smoke test (fake by default, --real to call)
```

## Guardrails (non-negotiable)

- **Confirm gate:** no paid call goes out without an explicit user "yes" — a mistranslation must never cost a call.
- **AI disclosure:** every brief identifies the caller as an AI assistant acting on the user's behalf (`CallBrief.agentDisclosure`).
- **Dry-run first, always.** Real calls only on deliberate smoke tests.
- **Sensitive data** (insurance, DOB) stays in session memory, is never logged in plaintext, and never appears in the public demo video.

## Roadmap

More language pairs (the pipeline is already language-agnostic), saved profiles for repeat facts, persistent callback-camping, and accessibility polish for Deaf and hard-of-hearing users.
