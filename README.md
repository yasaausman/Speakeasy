# KindlyCall

[![CI](https://github.com/yasaausman/KindlyCall/actions/workflows/ci.yml/badge.svg)](https://github.com/yasaausman/KindlyCall/actions/workflows/ci.yml)

**Book everyday appointments in your language, even when the business only speaks English.**

Speak or type a request, review the business and the plan, and approve the call. KindlyCall uses CALL-E to handle the English conversation, then explains the outcome in your language through text and speech.

Built for **CALL-E: Your Code Is Calling**. The product is multilingual (a dozen selectable languages); the demo video uses Hindi as one example.

## The experience

1. **Ask in your language.** Native iOS speech recognition or typed input.
2. **Review before calling.** Business name, number, address when available, translated readback, and the saved details attached to the request.
3. **Approve.** The backend's confirmation gate starts the CALL-E workflow.
4. **Follow the call.** Status and English transcript snippets arrive through polling.
5. **Understand the outcome.** A completed task, a request for missing information, or an uncertain outcome that needs checking.

Example Hindi request:
> मेरे लिए मंगलवार दोपहर तीन बजे दाँतों की जाँच का अपॉइंटमेंट बुक कर दीजिए। अगर तीन बजे समय न मिले, तो साढ़े तीन बजे भी ठीक है।

“Book a dental checkup Tuesday at 3 p.m. If 3 isn't available, 3:30 is fine too.”

This is an example request, not a claim that an appointment has been made.

## Three workflows

| Workflow | Behavior |
|---|---|
| Book | Perform a task with one business, using supplied constraints and fallback preferences. |
| Compare | Ask several businesses for information. Briefs explicitly prohibit bookings, orders and other commitments. Review an option before a separate booking call. |
| Discover | Collect available times without booking; select a slot and review the next call. The app retains the original business number. |

Additional features: local saved details, history, payment-method preferences, calendar free/busy context, text-only mode, and Arabic right-to-left layout. Twelve languages are selectable. Speech availability depends on Apple's language/device support. Localization coverage varies; Hindi received an additional task/recovery pass.

## Architecture

```text
SwiftUI iOS app
  Apple speech recognition/synthesis · location · calendar · local history
        │ HTTP / session polling
TypeScript + Fastify backend
  translation · intent · business search · call orchestration
        │ OAuth + Streamable HTTP MCP
CALL-E
  plan_call → run_call → get_call_run
```

CALL-E owns the phone conversation. Translation handles the user's request, readback and result; this is not live translation of the phone audio.

Gemini provides translation, Google Search-grounded business lookup, intent classification, ranking and slot extraction. OpenAI alternatives exist for translation, ranking and extraction. **Business search and intent classification do not have an OpenAI implementation.** Without provider keys, offline doubles preserve the wiring but do not perform real translation or real business search.

## Verify without calls or API keys

Node 20.12+ and npm:

```bash
npm ci
npm run check
npm test
npm run smoke:fake
```

The fake smoke command explicitly overrides real mode, even if `.env` contains `CALLE_MODE=real`. Fixtures use fictional data. A green smoke run proves the transport workflow, not a real booking. The fake transport currently models appointment scenarios rather than arbitrary user goals.

The tests cover booking, missing details, inquiry-only comparisons, discovery, pending-call recovery without redialing, terminal-status normalization, sensitive-input rejection, operational log filtering, and translation failure after a completed call.

Current validation details: [VERIFICATION.md](docs/submission/VERIFICATION.md).

## Run the iOS app

Requires Xcode, an iOS simulator or signed physical device, and XcodeGen.

```bash
xcodegen generate --spec ios/project.yml
open ios/KindlyCall.xcodeproj
```

The normal app uses the backend. Start a fully offline backend explicitly:

```bash
CALLE_MODE=fake GEMINI_API_KEY='' OPENAI_API_KEY='' npm run dev
```

The simulator defaults to `http://localhost:3000`. For an iPhone, set the Xcode scheme environment variable `KINDLYCALL_BACKEND_URL` or the Info.plist `KindlyCallBackendURL` key to your Mac's LAN URL, on the same Wi-Fi. This is a local-development service, not an authenticated public deployment.

### Labeled Hindi UI rehearsal

In a **Debug** scheme, set:

```text
KINDLYCALL_DEMO_SCENARIO=success
KINDLYCALL_DEMO_LANGUAGE=hi
```

Other scenarios: `gap`, `pending`. To hear native narration, set `KINDLYCALL_DEMO_AUDIO=1`.

The app displays a persistent simulated-call banner and uses a separate details/history store. It does not use the backend, translation API, or CALL-E. These fixtures test and rehearse UI; never present them as real phone-call evidence. Remove the environment variables to return to the backend.

### iOS tests

```bash
xcodebuild -project ios/KindlyCall.xcodeproj -scheme KindlyCall \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath ios/build test
```

The test scheme includes outcome/calendar/slot-retention unit tests and labeled Hindi UI flows. UI tests use no real calls.

## Real calls

Set a valid Gemini key for real business lookup and translation. CALL-E authentication stays on the backend. Two transports are selectable with `CALLE_TRANSPORT`:

- `rest` (recommended): the [CALL-E Developer REST API](https://docs.heycall-e.com/api-reference/calls) with an API key, no browser or OAuth. Set `CALLE_TRANSPORT=rest` and `CALLE_API_KEY=<your key>` (from the CALL-E dashboard) in `.env`. The backend places calls via `POST /v1/calls` and polls `GET /v1/calls/{id}`.
- `mcp` (default, local development only): OAuth via the account-linked `calle auth login` token. This reuses the same machine's `calle` CLI token cache, which is a private, per-user credential store, not a supported token-distribution API; the backend reads it locally and never copies, logs, or transmits it. Prefer `rest` for anything beyond local dev. See [integration notes](docs/CALLE-INTEGRATION-FEEDBACK.md).

Either way, keep `CALLE_MODE=real` off for dry runs. The startup banner shows the active transport, e.g. `calle=real(rest)`.

A real self-test explicitly places a phone call:

```bash
SMOKE_TARGET_NUMBER=+1YOUR_OWN_NUMBER npm run smoke:real
```

For calls approved in the app, configure `CALLE_MODE=real`, start the backend, review the destination and approve the request. Inspect the startup provider/mode banner. Do not use real mode with mock business lookup results.

## Completion and recovery

- `COMPLETED` means the call ended. Successful UI requires `taskCompleted == true` and no reported gaps.
- A timeout or lost response after dispatch produces a **pending** outcome. Check status polls the existing run ID; it never plans or starts another call.
- If dispatch succeeded but no run ID was received, inspect CALL-E call history before making another call.
- Comparisons with unresolved calls do not offer a booking action. Failed/unconfirmed inquiry results cannot become the recommended winner.
- Automatic calendar creation requires a confirmed task and an explicit ISO timestamp with a time-zone offset. Relative/free-text dates require the user to select and confirm the date/time.

## Data handling and limits

All briefs identify the caller as an AI and instruct it not to guess missing information. Long card-like digit sequences are rejected before sending a goal/details/preferences to providers; this is a conservative heuristic, not comprehensive financial-data detection. Payment should be a method such as pay on pickup, never card credentials.

Call request logs use an allowlist of operational metadata. They exclude the goal, personal facts, destination numbers, transcripts and confirmation tokens. Supplied details are sent to the calling service as part of the brief; the confirmation screen exposes what is attached.

This remains a prototype:

- Backend sessions are in memory and do not survive a server restart. There is no account authentication or durable job queue.
- Details/history use local UserDefaults JSON, not an encrypted vault. Use non-sensitive demonstration data.
- Search results still require human review. Prompt-based restrictions do not guarantee the behavior of an external voice model.
- Apple speech recognition is native; the implementation does not require recognition to run entirely on-device.
- Detailed localization, voice availability, real-call outcomes and business types need broader user validation.
- Deep IVR navigation, very long holds, live user intervention and callback scheduling are deferred.

## Submission and evidence

The repository's earlier milestones record a successful real CALL-E self-test and physical-device use. Those historical notes are separate from the current automated verification. `docs/sample-run.json` is synthetic. The new Hindi UI fixtures are simulated. Neither proves a real appointment booking.

- [Demo recording script](docs/submission/DEMO-SCRIPT.md)
- [Devpost text draft](docs/submission/DEVPOST-DRAFT.md)
- [User-test protocol](docs/submission/USER-TEST.md)
- [Feedback survey draft](docs/submission/FEEDBACK-DRAFT.md)
- [Name shortlist](docs/submission/NAME-OPTIONS.md)
- [Current rubric assessment](SELF-JUDGING.md)
- [Historical milestones](MILESTONES.md)

The team still needs to record and upload the actual submission video, enter the private account/team details, and submit the Devpost form. Preparing these documents does not submit them.
