# Devpost submission draft

Working title: **KindlyCall — Appointments in your language**

Tagline: **Your words. We make the call.**

Short description:
Speak or type in Hindi, approve the business and request, and let an AI assistant handle the English phone call. Get a clear outcome back in Hindi, with confirmations or the missing information needed to continue.

## Inspiration

Everyday appointments often depend on an English phone conversation. Someone can know exactly what they need and still struggle to explain it, understand follow-up questions, or negotiate another time. We wanted to make that task accessible through the language the user is comfortable using.

## What it does

KindlyCall is a native iOS assistant for everyday phone tasks. It translates a user's request, finds a business, and presents the business and a readback for approval. CALL-E then makes the English call. Results return in the user's language as text and speech.

The app supports direct tasks, inquiry-only comparisons, and availability discovery followed by a separately approved booking call. Saved details and preferences help the agent answer predictable questions. Missing information is surfaced for the user to answer. An unknown call outcome stays pending and can be checked without redialing.

Our headline demonstration focuses on a Hindi-speaking appointment user. Twelve language choices exist, with varying voice availability and localization coverage; we do not claim equal validation across all twelve.

## How we built it

The SwiftUI iOS app uses Apple's speech, location and calendar frameworks. It talks over HTTP to a TypeScript/Fastify service. The backend translates requests and outcomes, classifies intent, searches for businesses, composes call briefs and tracks sessions.

CALL-E is invoked at runtime through its OAuth-protected MCP tools: plan_call → run_call → get_call_run. Gemini supports translation, search grounding, classification and ranking. Some language functions have OpenAI alternatives; keyless test doubles make offline verification reproducible.

## Challenges

CALL-E's returned call status and the user's task outcome are different. We preserve both, and only show successful completion when the task is explicitly confirmed. Monitoring timeouts and uncertain network responses retain a pending outcome rather than inviting a duplicate call.

We also encountered account-linked OAuth requirements and a nested result envelope in CALL-E responses. The repository includes reproducible integration feedback.

## What we are proud of

- A complete native interface from request to confirmation, call progress and outcome.
- Hindi task and recovery copy, plus text and audio output.
- Inquiry-only comparison briefs that prohibit commitments before the user chooses a business.
- Recovery that checks existing call IDs instead of starting another call.
- Automated regression tests for workflow behavior, sensitive-input handling and iOS outcome/calendar logic.

## What we learned

The difficult part is knowing when the task is truly done and communicating uncertainty clearly. Helpful automation must preserve the user's chosen business, constraints, and authority to approve calls.

## What's next

Validate the full real-call flow with intended users, expand localization based on that feedback, improve structured appointment extraction, and add authenticated hosting, durable sessions and stronger local storage before a public launch. Live user intervention during a phone call and robust long-hold/IVR handling are future work.

## Required team inputs before submission

- Final project name.
- Public YouTube or Vimeo link to the under-three-minute demonstration.
- Email associated with the team's CALL-E account (enter privately in Devpost).
- Submission PR URL: repository previously records https://github.com/CALLE-AI/awesome-phone-call-agents/pull/449 ; verify its current state before use.
- Confirm the team/contributor information and the footage permissions.
- Replace this draft's evidence section with the actual recording/test results; do not describe a simulated run as a real business booking.

See VERIFICATION.md for automated results and USER-TEST.md for the blank participant protocol.
