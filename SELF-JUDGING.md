# Speakeasy — evidence against the official rubric

Updated September 13, 2026. This replaces the earlier speculative seven-category numerical scorecard. Automated tests and code structure do not justify claiming “10/10” safety or technical completeness.

The official rubric has four equally weighted criteria: Real World Impact, Quality of the Idea, Technical Implementation, and Product Experience & Demo. Source: https://call-e.devpost.com/rules

| Criterion | Evidence we can show | What remains unproven |
|---|---|---|
| Real World Impact | A concrete Hindi appointment workflow, constraints, missing-information recovery, text and audio output. | No target-user study results have been recorded for this pass. Use the prepared protocol and report actual results. |
| Quality of the Idea | Language-to-task workflow with user approval, inquiry-only comparisons, discovery followed by a separate booking call. | Do not claim no competitor exists. Demonstrate why this particular user experience is useful. |
| Technical Implementation | CALL-E runtime integration, separate translation/search, regression tests, pending recovery by existing run ID, privacy-aware request logging. | Public hosting/authentication, durable sessions, broader live-call behavior and stronger local storage remain prototype limitations. |
| Product Experience & Demo | Native SwiftUI, Hindi task/recovery copy, honest outcome states, explicit calendar-date review, labeled UI rehearsal. | The final real-call recording, external-user feedback and public video URL still require the team. |

## Evidence boundaries

- Current tests use offline transports or a labeled local UI rehearsal. They prove specific control paths, not real appointment success or model compliance with every instruction.
- Prior milestones record a real CALL-E self-test and physical iPhone use. A test phone connection is not evidence that every proposed task works with a real business.
- `docs/sample-run.json` and the Debug Hindi scenarios are fictional.
- Long card-like input rejection is heuristic. Saved details/history still use UserDefaults. There is no basis for a blanket security/compliance claim.
- Native Apple speech does not mean on-device-only speech. Twelve language choices do not mean twelve equally tested/localized voice experiences.

## Remaining submission work

1. Test the actual Hindi appointment flow with an approved destination.
2. Record a clear, accurately labeled video under three minutes.
3. Fill in real user evidence if testing was conducted; otherwise state that it is still planned.
4. Verify the submission PR, enter the private CALL-E account email, and submit Devpost before the deadline.
5. Submit integration feedback through the separate official feedback survey if pursuing that prize.

See docs/submission/ for prepared drafts and the current verification record.
