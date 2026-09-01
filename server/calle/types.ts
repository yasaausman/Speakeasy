/**
 * CALL-E MCP contract types.
 *
 * Ground truth: call-e-integrations repo, docs/mcp/openagent-oauth.md.
 * The build-plan doc's original CallBrief was NOT the plan_call input shape —
 * the repo wins (golden rule #1). plan_call takes `user_input` plus optional
 * hints; our CallBrief is Speakeasy's *internal* representation, which we
 * compose into that `user_input` string (see client.ts::briefToUserInput).
 */

// ── Speakeasy's internal brief (composed into plan_call input) ───────────────
export type CallBrief = {
  objective: string; // "Book a dentist appointment for my son"
  targetNumber: string; // E.164, e.g. "+15551234567"
  targetRegion: string; // two-letter region code, e.g. "US"
  language: string; // call language, e.g. "English" / "en-US"
  constraints: string[]; // ["mornings only", "next week"]
  facts: Record<string, string>; // rep may ask for these: insurance, DOB, callback number
  successCondition: string; // "appointment booked and confirmation number captured"
  fallback: string; // "if no morning slots, take earliest afternoon; if closed, report hours"
  agentDisclosure: string; // REQUIRED: identify as an AI assistant calling on behalf of the user
};

// ── plan_call ────────────────────────────────────────────────────────────────
export type PlanCallInput = {
  user_input: string; // the user's latest message / instruction, verbatim
  to_phones?: string[]; // destination numbers, only when known & unambiguous
  region?: string; // region hint, only when known
  language?: string; // call language, only when known
  goal?: string; // call goal, only when known
  scheduled_at?: string; // optional one-time execution time
  plan_id?: string; // when refining an existing plan
  ttl_seconds?: number; // optional retention TTL
};

export type PlanCallResult = {
  plan_id?: string;
  confirm_token?: string;
  ready_to_run?: boolean;
  clarifying_questions?: string[];
  raw: Record<string, unknown>;
};

// ── run_call ─────────────────────────────────────────────────────────────────
export type RunCallInput = {
  plan_id: string;
  confirm_token: string;
  ttl_seconds?: number;
};

export type RunCallResult = {
  run_id?: string;
  status?: string;
  next_step?: unknown;
  raw: Record<string, unknown>;
};

// ── get_call_run ─────────────────────────────────────────────────────────────
export type GetCallRunInput = {
  run_id: string;
  cursor?: string;
  limit?: number;
};

export type GetCallRunResult = {
  run_id?: string;
  status?: string;
  activity?: unknown;
  summary?: string;
  details?: unknown;
  transcript?: string;
  next_step?: unknown;
  raw: Record<string, unknown>;
};

// ── Terminal statuses (docs/mcp/openagent-oauth.md) ──────────────────────────
// "NO ANSWER" (space) is treated the same as NO_ANSWER.
export const TERMINAL_STATUSES = new Set([
  "COMPLETED",
  "FAILED",
  "NO_ANSWER",
  "NO ANSWER",
  "DECLINED",
  "CANCELED",
  "CANCELLED",
  "VOICEMAIL",
  "BUSY",
  "EXPIRED",
]);

export function isTerminalStatus(status: string | undefined): boolean {
  if (!status) return false;
  return TERMINAL_STATUSES.has(status.trim().toUpperCase());
}

// ── Speakeasy's normalized final result (build-plan section 6) ───────────────
export type CallOutcomeStatus =
  | "completed"
  | "failed"
  | "no_answer"
  | "voicemail"
  | "declined"
  | "busy"
  | "canceled"
  | "expired";

export type CallResult = {
  status: CallOutcomeStatus;
  rawStatus: string; // the exact terminal status CALL-E returned
  outcome: string; // human-readable, English (from summary)
  structured: Record<string, unknown>; // schema-validated structured data when present
  confirmationNumbers: string[];
  transcript: string; // English, for debugging and the demo video
  appointmentText?: string; // e.g. "Tuesday 9:40am" — for Add to Calendar
  provider?: string; // e.g. "Dr. Lee"
  confidence?: { score: number; label: string }; // completion confidence
  evidence?: string[]; // why we believe the task was done
  gaps?: string[]; // info the rep asked for that wasn't provided
  taskCompleted?: boolean; // whether the task itself succeeded (COMPLETED ≠ success)
};

/** Map a raw CALL-E terminal status onto our normalized outcome status. */
export function normalizeStatus(rawStatus: string | undefined): CallOutcomeStatus {
  switch ((rawStatus ?? "").trim().toUpperCase()) {
    case "COMPLETED":
      return "completed";
    case "NO_ANSWER":
    case "NO ANSWER":
      return "no_answer";
    case "VOICEMAIL":
      return "voicemail";
    case "DECLINED":
      return "declined";
    case "BUSY":
      return "busy";
    case "CANCELED":
    case "CANCELLED":
      return "canceled";
    case "EXPIRED":
      return "expired";
    default:
      return "failed";
  }
}
