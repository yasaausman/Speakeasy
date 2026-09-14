# KindlyCall, Appointments in your language

**Tagline:** Your words. We make the call.

**One line:** A native iOS assistant that lets you request an everyday appointment in your own language, approve exactly who gets called, and have CALL-E carry out the English phone conversation, then returns an honest outcome back in your language.

---

## How KindlyCall meets the judging criteria

The official rubric is four equally weighted criteria
([source](https://call-e.devpost.com/rules)). Each row is verifiable in the repo
at commit `babfc61`. Our demo video uses Hindi, but the product is multilingual
(a dozen selectable languages); Hindi is one example, not the only language.

| Criterion | What we built (verifiable) | Honest boundary |
|---|---|---|
| **Real-World Impact** | End-to-end appointment flow in the user's own language: spoken or typed request, approval, English call, then a spoken and text result back in their language. Handles the real failure mode with a preferred time plus ranked fallback in the brief, and missing-info recovery (the rep asks for insurance or date of birth, the app asks the user, saves it, and calls back). | No target-user study is recorded yet; the participant protocol is prepared but results are still **[to be filled]**. |
| **Quality of the Idea** | Not just translation. A language-to-task workflow with a mandatory confirm gate, plus two non-obvious modes: inquiry-only comparison across businesses (books nothing) and availability discovery followed by a separate approved booking call. | We claim usefulness, not category exclusivity. |
| **Technical Implementation** | Runtime CALL-E via OAuth MCP tools `plan_call`, `run_call`, `get_call_run` (plus an optional REST Developer-API transport with an API key); separate translation, search, intent, and ranking layers; 28 backend regression tests plus 8 iOS tests; pending-outcome recovery by existing run id (never a duplicate call); privacy-aware logging (allowlisted metadata only, with a test that feeds a card number and asserts it never reaches a provider). | Prototype limits: no public auth or hosting, in-memory sessions, `UserDefaults` local storage, no mid-call intervention. |
| **Product Experience & Demo** | Native SwiftUI; audio-reactive orb; live call transcript; localized task and recovery copy in text and speech (the demo is in Hindi); honest result states, where success shows only when `status == completed && taskCompleted && no gaps`, otherwise "Needs your answer" or "Not completed", with explicit calendar-date review. | Final real-call recording and public video URL still **[to be filled]**. |

---

## Inspiration

Everyday appointments often hinge on one English phone call. Someone can know
exactly what they need and still stall on explaining it, following the
receptionist's questions, or negotiating another time. We wanted that task to
happen in the language the user is comfortable with, without handing over
control of who gets called or what gets committed.

## What it does

Speak or type a request in your own language. KindlyCall translates it, finds a
business, and shows you the business, number, and a plain-language readback to
approve. Only after approval does CALL-E place the English call. The result comes
back in your language as text and speech: a confirmation when the task is
genuinely done, or the specific missing information when it isn't.

Three task shapes: direct booking, inquiry-only comparison (ask several places,
commit to none, you choose), and availability discovery (collect open slots, then
a separate approved call books the one you pick). Saved details and preferences
pre-answer predictable questions; an uncertain call outcome stays pending and is
re-checked by run id rather than redialed. A dozen languages are selectable, with
right-to-left layout for Arabic; the phone call itself is always in English while
the user's side is translated. Voice and localization coverage varies by
language, and our demo happens to use Hindi.

## How we built it

- **iOS (SwiftUI):** Apple Speech (STT), AVSpeech (TTS), Location, EventKit
  calendar. Talks HTTP to the backend.
- **Backend (TypeScript, Fastify):** translation, intent classification,
  grounded business search, brief composition, session state machine with the
  confirm gate, background polling.
- **CALL-E:** invoked at runtime through OAuth-protected MCP tools
  (`plan_call`, `run_call`, `get_call_run`), with an optional REST Developer-API
  transport (`POST /v1/calls`, `GET /v1/calls/{id}`) selectable by API key.
- **Models:** Gemini for translation, search grounding, classification, and
  ranking. Keyless fake transports make the whole workflow reproducible offline,
  which is how the 28 backend tests run without spending call quota.

## Challenges we ran into

The core insight: CALL-E's call status is not the same as the user's task
outcome. A call can reach `COMPLETED` while the appointment was not booked. We
preserve both and only celebrate on explicit task completion; monitoring
timeouts and uncertain network responses hold a pending state instead of inviting
a duplicate call. We also hit account-linked OAuth requirements and a nested
result envelope in CALL-E responses, both documented as reproducible integration
feedback in the repo.

## Accomplishments we're proud of

- A complete native path: request, approval, live call progress, honest outcome.
- Comparison briefs that prohibit any commitment before the user chooses.
- Recovery that re-checks an existing run id rather than starting a second call.
- Guardrails enforced in code and tests: AI disclosure in every brief, card-like
  input rejected before it leaves the device, redacted operational logging.

## What we learned

The hard part isn't making the call. It is knowing when the task is truly done
and communicating uncertainty honestly, while never taking away the user's
authority to approve each call or their chosen business and constraints.

## What's next

Validate the full real-call flow with intended users across languages; expand
localization from that feedback; stronger structured appointment extraction;
authenticated hosting, durable sessions, and encrypted local storage before any
public launch. Mid-call intervention and robust hold or IVR handling are future
work.

## Evidence and links

- Repo: `github.com/yasaausman/KindlyCall` at `babfc61`, CI green, MIT.
- Tests: 28 backend (`server/**/*.test.ts`) plus 8 iOS (`ios/KindlyCallTests`,
  `ios/KindlyCallUITests`).
- Integration feedback: `docs/CALLE-INTEGRATION-FEEDBACK.md`.
- Sample run (`docs/sample-run.json`) and the Debug Hindi scenarios are
  fictional and labeled; no real transcript is committed.

## Team must fill before submitting

- **[Demo video URL]** public YouTube or Vimeo, under 3:00.
- **[CALL-E account email]** entered privately in the Devpost form.
- **[Submission PR state]** repo records
  `CALLE-AI/awesome-phone-call-agents#449` (merged) and the rename follow-up
  `#590`; verify current status.
- **[Real-user results]** add measured results, or state testing is still
  planned. Never present a simulated run as a real business booking.
