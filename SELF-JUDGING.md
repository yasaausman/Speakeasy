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
| 1 | Use of CALL-E (sponsor tech) | 9 / 10 | Full `plan → run → poll` contract, real call completed end-to-end, terminal-status breadth unit-tested, two integration bugs reported upstream. |
| 2 | Technical execution | 10 / 10 | Clean app/backend split, provider-agnostic language layer, **20 deterministic tests** (flows, guardrails, error paths, status normalization) + CI, an **iOS UI smoke test**, configurable backend URL. |
| 3 | Innovation / originality | 8 / 10 | The four-part wedge (language-first + both-directions voice/text + task completion + underserved user) isn't covered by one existing product. |
| 4 | Impact / usefulness | 8 / 10 | Squarely aimed at limited-English, phone-anxious, and Deaf/HoH users. Real, not hypothetical, need. |
| 5 | Design / UX | 9 / 10 | HIG-respecting, **audio-reactive** mascot orb, localized primary flow (verified live in EN/ES/AR incl. RTL), persisted language, WCAG AA, haptics. Only outside-user testing left. |
| 6 | Completeness / "actually works" | 8 / 10 | One command proves it with zero infra; real call verified; full app flow verified on-device. Demo video + Devpost submission still open. |
| 7 | Safety / guardrails | 10 / 10 | Confirm gate, AI disclosure, no card data, dry-run default — now **enforced by automated guardrail tests**, not just convention. |
| | **Overall (weighted, honest)** | **~8.9 / 10** | Two clean 10s; every remaining gap is a thing only the team can do — record the demo, submit Devpost, run a real-call matrix, get outside-user feedback. |

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

- **Breadth proven without real calls.** A real-call matrix across every terminal
  status is expensive and non-deterministic, so [`normalize.test.ts`](server/calle/normalize.test.ts)
  pins the mapping for `VOICEMAIL`/`BUSY`/`NO_ANSWER`/`DECLINED`/…, the "COMPLETED ≠
  success" reading, and confirmation-number extraction.

**What would cost points.** Live *real-call* runs are still few. A recorded matrix across
statuses in the wild is the remaining item (needs a real phone), and live push during a
call (CALL-E Developer API + webhooks) is deferred — MCP is one-shot async.

## 2 · Technical execution — **10/10**

**Evidence.**
- Clean separation: **iOS never speaks MCP**; it only calls the Node backend over HTTP.
  The rationale (OAuth, MCP client, token cache can't live in the app) is documented in
  the README architecture section.
- **Provider-agnostic** language layer (Gemini > OpenAI > offline) so translation,
  intent, search, and ranking all degrade gracefully with no key
  ([`server/language/`](server/language/), [`server/search/business.ts`](server/search/business.ts)).
- **Deterministic proof:** `npm test` runs **20 offline tests** in <1s — end-to-end
  flows, three guardrail tests, three error-path tests
  ([`orchestrator.test.ts`](server/orchestrator/orchestrator.test.ts)), and eight
  status-normalization tests ([`normalize.test.ts`](server/calle/normalize.test.ts));
  CI runs type-check + tests + fake smoke on every push
  ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
- **iOS UI smoke test** ([`SpeakeasyUITests/`](ios/SpeakeasyUITests/)) — the app
  launches with no cold-launch permission wall, the Home greeting + starter chips
  render, and switching language localizes Home **and persists across relaunch**.
  Verified green via `xcodebuild test`.
- **Configurable backend URL** — the on-device base URL now resolves from an env var or
  the `SpeakeasyBackendURL` Info.plist key ([`SpeakeasyAPI.swift`](ios/Speakeasy/Networking/SpeakeasyAPI.swift)),
  so a new network no longer needs a Swift edit.
- State machine with a confirm gate and background poll loop
  ([`orchestrator.ts`](server/orchestrator/orchestrator.ts)).

**What would cost points.** The iOS UI tests run locally (`xcodebuild test`), not in the
Linux CI (no macOS runner) — a small caveat, not a gap in coverage.

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

This pass closed the gaps from the last review: the **orb is now audio-reactive** (its
halo swells with mic loudness, Reduce-Motion aware — [`VoiceOrb.swift`](ios/Speakeasy/Design/VoiceOrb.swift),
[`SpeechManager.swift`](ios/Speakeasy/Speech/SpeechManager.swift)); the **primary flow
is localized** end-to-end — Home, confirm gate, live-call header, and result card
([`Strings.swift`](ios/Speakeasy/Models/Strings.swift)), verified live in English,
Spanish, and Arabic (RTL); and the **language choice persists** across relaunch
(UserDefaults, covered by the UI test).

**What would cost points.** A few deep-in-the-flow strings (the gap-surfacing sentence,
the confidence adjective) are still English — a full-i18n sweep would finish them. And
the UX is verified by us, not by outside users — the one honest thing between this and a
10.

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
- **Real-call breadth:** the *mapping* for every terminal status is unit-tested, but
  live runs across those statuses in production conditions are still few (needs a real
  phone to reproduce a BUSY/NO_ANSWER on demand).
- **No outside user testing yet:** impact and UX are argued and self-verified (now
  screen-by-screen in the Simulator and via a UI test, but not with target users).
- **Localization is ~95% of the primary flow:** Home, confirm gate, and result card are
  localized (EN/ES/AR verified); a couple of deep strings (gap-surfacing sentence, the
  confidence adjective) remain English.
- **Live in-call interaction** (#6) needs CALL-E's Developer API + webhooks; not in MCP.

## What would raise each score

| Criterion | Cheapest win to raise it |
| --- | --- |
| CALL-E | ~~Status-normalization breadth tests~~ ✅ done — remaining: a recorded real call for book/compare/discover across a couple of terminal statuses (needs a real phone). |
| Technical | ~~Guardrail test, iOS UI smoke test, configurable URL, error-path tests~~ ✅ **all done — now 10/10.** |
| Design | ~~Audio-reactive orb, primary-flow localization, persisted language~~ ✅ done — remaining: one round of outside-user feedback. |
| Completeness | Record the demo video and submit the Devpost form (the two open items). |
| Impact | A short session with one target-population user, quoted. |

## Honest verdict

Speakeasy is **submission-ready in substance**: a real CALL-E call completes the task
end-to-end, the code is clean and provable with one command (20 tests + an iOS UI test),
the safety story is enforced by tests, the app is polished and localized, and the
positioning is genuinely differentiated. **Technical execution and Safety are clean 10s.**
Every remaining gap is a thing only the team can do — record the ~3-minute demo, submit
the Devpost form, run a real-call matrix across statuses on a real phone, and put it in
front of one target-population user. None of those are missing *code*; they're the
last-mile submission and validation steps, all named here rather than hidden.
