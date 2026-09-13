# CALL-E feedback form draft

This is prepared text, not a submitted form. The official feedback survey is a separate entry requirement for the feedback prizes; a GitHub issue alone does not complete it.

## Account-linked OAuth clarification

Our TypeScript MCP client could connect and list tools after dynamic registration and PKCE, but tools/call returned Unauthorized. Reusing the account-linked token from calle auth login resolved invocation. Please clarify account linking and the necessary scopes/client setup in the standalone OAuth example, and distinguish discovery-only authentication from call authorization.

## Document the nested result envelope

Real get_call_run responses nested summary, transcript, and outcome under result, while a top-level interpretation produced empty summaries after COMPLETED. A canonical response example and typed schema would remove ambiguity. We now read result.summary, result.transcript, and result.outcome, with compatibility fallbacks.

## Outcome uncertainty and recovery

Please provide a documented idempotency key for run_call or a reconciliation endpoint keyed by plan_id/client request ID. If a network connection drops after dispatch but before receiving run_id, a client cannot safely infer whether a call started. We currently show an unknown outcome and ask the operator to inspect call history rather than retry.

An explicit structured distinction among call ended, task completed, booking confirmed, and follow-up needed would also help clients avoid false success UI. An appointment schema with ISO date/time, time zone, business identity and confirmation reference would improve calendar integrations.

Prior issue recorded in the repository: https://github.com/CALLE-AI/call-e-integrations/issues/126
Local reproduction details: ../CALLE-INTEGRATION-FEEDBACK.md

Official form is linked from https://call-e.devpost.com/rules . Feedback deadline: September 18, 2026, 11:45 p.m. SGT.
