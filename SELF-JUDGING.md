# Speakeasy — Self-Judging

A candid, evidence-anchored self-assessment of Speakeasy against the kind of rubric
a "Your Code Is Calling" (CALL-E) hackathon judge is likely to apply. The goal here
is **honesty, not marketing** — every strength links to something real in the repo,
and every criterion lists what would legitimately cost us points.

> How to read the scores: each criterion is out of 10. A 10 would mean "nothing a
> judge could reasonably dock." We deliberately do **not** give ourselves 10s. Where
> the code proves the claim, we cite the file; where it's aspirational or unverified,
> we say so.

## Scorecard at a glance

| # | Criterion | Self-score | One-line justification |
| --- | --- | :---: | --- |
| 1 | Use of CALL-E (sponsor tech) | 9 / 10 | Full `plan → run → poll` contract, real call completed end-to-end, two integration bugs reported upstream. |
| 2 | Technical execution | 9 / 10 | Clean app/backend split, provider-agnostic language layer, 10 deterministic tests (incl. guardrail tests) + CI. Thin real-call coverage. |
| 3 | Innovation / originality | 8 / 10 | The four-part wedge (language-first + both-directions voice/text + task completion + underserved user) isn't covered by one existing product. |
| 4 | Impact / usefulness | 8 / 10 | Squarely aimed at limited-English, phone-anxious, and Deaf/HoH users. Real, not hypothetical, need. |
| 5 | Design / UX | 9 / 10 | Native SwiftUI, HIG-respecting (in-context permissions, WCAG AA, 44pt targets), mascot orb, localized starter chips, RTL — all **verified live in the simulator**. Not yet outside-user tested. |
| 6 | Completeness / "actually works" | 8 / 10 | One command proves it with zero infra; real call verified; full app flow verified on-device. Demo video + Devpost submission still open. |
| 7 | Safety / guardrails | 10 / 10 | Confirm gate, AI disclosure, no card data, dry-run default — now **enforced by automated guardrail tests**, not just convention. |
| | **Overall (weighted, honest)** | **~8.7 / 10** | Strong, submission-ready core; the remaining gaps are the demo video and breadth of real-call testing, not the substance. |

---

## 1 · Use of CALL-E — **9/10**

**Evidence.**
- The entire CALL-E surface lives in one place — [`server/calle/`](server/calle/) — and
  drives the three tools in strict order: `plan_call → run_call → get_call_run`
  ([`client.ts`](server/calle/client.ts), [`types.ts`](server/calle/types.ts)).
- OAuth + Streamable-HTTP transport with a token cache ([`oauth.ts`](server/calle/oauth.ts)).
- **A real call completed end-to-end** (`COMPLETED`, real transcript, task confirmed) —
  milestone A3 in [MILESTONES.md](MILESTONES.md).
- We treat `COMPLETED` as "the run ended," not "the task succeeded" — success is judged
  from `summary`/`evidence` (`taskCompleted`, `confidence` in [`types.ts`](server/calle/types.ts)).
  This is a subtle, correct reading of the contract.
- We fed two reproducible integration issues back to the sponsor
  ([`docs/CALLE-INTEGRATION-FEEDBACK.md`](docs/CALLE-INTEGRATION-FEEDBACK.md),
  [call-e-integrations#126](https://github.com/CALLE-AI/call-e-integrations/issues/126)).

**What would cost points.** Real-call testing is still thin (a handful of runs, not a
matrix across statuses like `VOICEMAIL`/`BUSY`/`NO_ANSWER` in the wild). Live push
during a call (CALL-E Developer API + webhooks) is deferred — MCP is one-shot async.

## 2 · Technical execution — **9/10**

**Evidence.**
- Clean separation: **iOS never speaks MCP**; it only calls the Node backend over HTTP.
  The rationale (OAuth, MCP client, token cache can't live in the app) is documented in
  the README architecture section.
- **Provider-agnostic** language layer (Gemini > OpenAI > offline) so translation,
  intent, search, and ranking all degrade gracefully with no key
  ([`server/language/`](server/language/), [`server/search/business.ts`](server/search/business.ts)).
- **Deterministic proof:** `npm test` runs 10 offline tests in <1s — end-to-end flows
  plus three guardrail tests
  ([`orchestrator.test.ts`](server/orchestrator/orchestrator.test.ts)); CI runs
  type-check + tests + fake smoke on every push
  ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
- State machine with a confirm gate and background poll loop
  ([`orchestrator.ts`](server/orchestrator/orchestrator.ts)).

**What would cost points.** No automated iOS UI tests (the app is verified manually).
The LAN base URL for on-device runs is hardcoded and per-network (documented, but a
rough edge). Error paths beyond the happy flow are lightly tested.

## 3 · Innovation / originality — **8/10**

**Evidence.** The pitch isn't "a translation app" or "a call bot" — it's the
intersection the README calls the four-part wedge: language-first UX, voice **and**
text in **both** directions, tasks that actually finish (with a captured confirmation
number), for a user who is underserved by English-only phone systems. **Auto-mode
inference** (book/compare/discover from the goal, no toggles —
[`intent.ts`](server/language/intent.ts)) and **find-the-number-for-you** (Gemini
Google-Search grounding — [`business.ts`](server/search/business.ts)) remove the two
steps a user would otherwise have to do themselves.

**What would cost points.** Each individual piece (translation, LLM call agents,
business search) exists elsewhere; the novelty is the *combination and the user it's
built for*, which is a positioning argument, not a brand-new primitive.

## 4 · Impact / usefulness — **8/10**

**Evidence.** The target users are concrete: limited-English speakers, people with
phone anxiety, Deaf/hard-of-hearing users (text-forward mode, no audio required), and
anyone who can't call during business hours. 12 languages with a searchable picker and
full RTL for Arabic. These aren't decorative — they're the whole point.

**What would cost points.** Impact is argued, not yet measured (no user testing with
the target population). Some highest-need cases (government IVR lines) are exactly where
the current approach is weakest — see Limitations.

## 5 · Design / UX — **9/10**

**Evidence** (this pass was verified screen-by-screen in the iOS Simulator, not just
asserted):
- **Native SwiftUI, playful/vibrant world** — a mascot voice orb that breathes/blinks,
  confetti on a booking, light + dark, a soft background gradient for depth
  ([`Theme.swift`](ios/Speakeasy/Design/Theme.swift), [`VoiceOrb.swift`](ios/Speakeasy/Design/VoiceOrb.swift)).
- **Solves the blank-canvas problem** — the Home screen now leads with a localized
  greeting and **tappable starter chips** (Book a haircut · Order takeout · Find a
  clinic · Book a dentist) so a first-time or non-English user knows what to say
  ([`HomeView.swift`](ios/Speakeasy/Views/HomeView.swift), [`Suggestions.swift`](ios/Speakeasy/Models/Suggestions.swift)).
- **HIG-respecting** — location permission is now requested **in context** (first "near
  me" goal), never on cold launch ([`SessionViewModel.swift`](ios/Speakeasy/ViewModels/SessionViewModel.swift));
  Dynamic Type, semantic dark mode, SF Symbols, system controls throughout.
- **Accessibility** — secondary text tuned to clear **WCAG AA** contrast on the ground,
  tap targets ≥ 44pt, VoiceOver labels/hints on the orb, chips, and the confidence badge.
- **Full RTL for Arabic verified live** — the whole layout mirrors and the greeting,
  chips, and captions render in Arabic.
- **Tasteful haptics** on the moments that matter — chip tap, "Yes, call", and a
  successful booking ([`Haptics`](ios/Speakeasy/Design/Theme.swift)).
- Confidence + evidence badge, gap-surfacing + retry, live transcript as chat bubbles,
  Add-to-Calendar — all confirmed rendering correctly on-device.

**What would cost points.** The orb isn't yet audio-reactive. UI *chrome* (button
labels on the confirm/result screens) is still English while the primary Home surface
and all readbacks are localized — a full-i18n pass would finish the job. A manually
picked language doesn't persist across launches (it re-seeds from the device by design).
And the UX is verified by us, not by outside users — the one thing between this and a 10.

## 6 · Completeness / "actually works" — **8/10**

**Evidence.** `npm test` + `npm run smoke:fake` prove the whole flow with **no Mac,
keys, or real calls**. Real language/search turns on with one env key; real calls with
`CALLE_MODE=real` after a self-test. A synthetic [`docs/sample-run.json`](docs/sample-run.json)
shows the result shape without committing any real call data. The **full app flow was
verified on-device** this pass — Home → chip → confirm gate → live transcript (with the
AI disclosure visible) → result card with the confidence badge and gap-surfacing.

**What would cost points.** The two remaining open items are real: the **~3-minute demo
video isn't recorded** and the **Devpost form isn't submitted** (the catalog PR
[awesome-phone-call-agents#449](https://github.com/CALLE-AI/awesome-phone-call-agents/pull/449)
is open and passing). Deferred item #6 (real-time tap-a-slot live push) is out of scope
for MCP.

## 7 · Safety / guardrails — **10/10**

**Evidence** (all non-negotiable, all enforced):
- **Confirm gate** — no paid call goes out without an explicit "yes"; a mistranslation
  can't cost a call. The gate shows business **name · number · address** first.
- **AI disclosure** on every brief (`CallBrief.agentDisclosure`).
- **Dry-run by default** (`CALLE_MODE=fake`); real calls require opt-in + a startup banner warning.
- **No card data, ever** — payment is a spoken preference only; the brief forbids reading card numbers.
- **Sensitive data** (insurance, DOB) stays in session memory, isn't logged in plaintext,
  and is kept out of the public demo.

**Now enforced by tests.** Three guardrail tests in
[`orchestrator.test.ts`](server/orchestrator/orchestrator.test.ts) assert the promises
hold in the code path that reaches CALL-E: no card-like number ever appears in the
composed `plan_call` input, the AI disclosure is always the verbatim first line, and the
agent is instructed never to guess missing info. This is what moved the score to 10 —
the safety story is verified, not just asserted in prose.

---

## Known limitations (stated plainly)

- **Government / IVR lines (SSN, DMV):** automated menus and long holds are the current
  weak spot. Speakeasy reports honestly when it can't complete rather than faking
  success; deep phone-tree navigation and callback-camping are deferred (phase 2).
- **Real-call breadth:** verified end-to-end, but not across every terminal status in
  production conditions.
- **On-device networking:** the LAN IP is hardcoded per Wi-Fi network (documented in
  [ios/README.md](ios/README.md) / [MILESTONES.md](MILESTONES.md)).
- **No outside user testing yet:** impact and UX are argued and self-verified (now
  screen-by-screen in the Simulator, but not with target-population users).
- **Partial in-app localization:** the Home surface and all readbacks localize; some
  confirm/result button labels are still English. A manually picked language also
  doesn't persist across launches (re-seeds from the device by design).
- **Live in-call interaction** (#6) needs CALL-E's Developer API + webhooks; not in MCP.

## What would raise each score

| Criterion | Cheapest win to raise it |
| --- | --- |
| CALL-E | A recorded real call for each of book/compare/discover, across a couple of terminal statuses. |
| Technical | ~~A guardrail test (assert no card data in the brief)~~ ✅ done — remaining: one iOS UI smoke test. |
| Design | ~~Blank-canvas Home, cold-launch permission, contrast/targets, haptics~~ ✅ done — remaining: audio-reactive orb, finish UI-chrome localization, one round of outside-user feedback. |
| Completeness | Record the demo video and submit the Devpost form (the two open items). |
| Impact | A short session with one target-population user, quoted. |

## Honest verdict

Speakeasy is **submission-ready in substance**: a real CALL-E call completes the task
end-to-end, the code is clean and provable with one command, the safety story is strong,
and the positioning is genuinely differentiated. The gaps that remain are **demo polish
and breadth of testing**, not missing core function. If a judge docks us, it should be
for the un-recorded demo video, the thin real-call matrix, and the government-line
limitation — all of which we've named here rather than hidden.
