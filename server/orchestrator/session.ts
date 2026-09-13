/** Per-session orchestrator state, kept in memory (enough for the demo). */
import type { CallBrief, CallResult } from "../calle/types.js";
import type { LangCode } from "../language/languages.js";

export type SessionPhase =
  | "idle"
  | "collecting"
  | "confirming" // goal understood; waiting for the user's yes  ← hard gate
  | "calling"
  | "polling"
  | "narrating"
  | "pending" // call may still be active; only read-only recovery is allowed
  | "done"
  | "failed";

/** A business found by lookup, shown at the confirm gate before any call. */
export interface FoundBusiness {
  name: string;
  phone: string;
  address?: string;
}

/** What the app shows the user to confirm before any call goes out. */
export interface GoalUnderstanding {
  understoodGoalEnglish: string;
  readbackUserLang: string;
  targetNumber: string;
  /** Present when numbers were looked up (not user-supplied) — for confirm-gate display. */
  businesses?: FoundBusiness[];
}

/** CallResult (from server/calle) plus the translated narration for the user. */
export interface NarratedResult extends CallResult {
  outcomeUserLang: string | null;
  appointmentUserLang?: string;
  evidenceUserLang?: string[];
  gapsUserLang?: string[];
}

/** One place's result in a multi-call comparison (C1). */
export interface RankedResult {
  business?: FoundBusiness;
  number: string;
  result: NarratedResult;
}

export type SessionMode = "single" | "multi";

/** How the agent should book: place a real booking, or just find available times. */
export type CallIntent = "book" | "discover" | "compare";

/** Front-loaded booking preferences — the agent decides from these instead of
 *  putting anyone on hold (there is no live hold; CALL-E is one-shot async). */
export interface CallPreferences {
  preferredTimes?: string; // "Saturday 2–4pm"
  fallbackTimes?: string; // "any afternoon, or Sunday morning"
  avoid?: string; // "not before 10am"
  budget?: string; // "under $40"
  payment?: string; // "Pay on pickup" — a note the agent conveys; NEVER card data
}

/** An available appointment slot discovered on a "discover" call (C4). */
export interface SlotOption {
  id: string;
  label: string; // "Saturday 3:30pm"
  labelUserLang?: string; // translated for display
}

export interface Session {
  id: string;
  phase: SessionPhase;
  mode: SessionMode;
  intent: CallIntent;
  userLang: LangCode;
  preparing?: boolean; // blocks confirmation or a second submission while translating
  originalText?: string; // the user's goal in their own language
  englishGoal?: string; // translated goal
  brief?: CallBrief; // the English brief handed to CALL-E (single mode)
  numbers?: string[]; // destinations (multi mode)
  understanding?: GoalUnderstanding;
  facts?: Record<string, string>; // saved details the agent can share (single mode)
  preferences?: CallPreferences; // front-loaded booking preferences
  availability?: string; // the user's free times (from their calendar)
  runId?: string;
  statusLine?: string | null;
  activity?: string[]; // live transcript lines during the call (single mode)
  result?: NarratedResult; // single mode
  ranked?: RankedResult[]; // multi mode, best-first
  winnerReason?: string | null; // multi mode, in the user's language
  options?: SlotOption[]; // discover mode: available slots to pick from
  errorMessage?: string;
  updatedAt: number;
}

/** The wire shape the app polls (matches the iOS SessionState model). */
export interface SessionStateDTO {
  sessionId: string;
  phase: SessionPhase;
  mode: SessionMode;
  intent: CallIntent;
  statusLine: string | null;
  activity: string[] | null;
  understanding: GoalUnderstanding | null;
  result: NarratedResult | null;
  ranked: RankedResult[] | null;
  winnerReason: string | null;
  options: SlotOption[] | null;
  errorMessage: string | null;
}

export function toDTO(s: Session): SessionStateDTO {
  return {
    sessionId: s.id,
    phase: s.phase,
    mode: s.mode,
    intent: s.intent,
    statusLine: s.statusLine ?? null,
    activity: s.activity ?? null,
    understanding: s.understanding ?? null,
    result: s.result ?? null,
    ranked: s.ranked ?? null,
    winnerReason: s.winnerReason ?? null,
    options: s.options ?? null,
    errorMessage: s.errorMessage ?? null,
  };
}

export class SessionStore {
  private sessions = new Map<string, Session>();

  create(userLang: LangCode): Session {
    const id = `sess_${Math.random().toString(36).slice(2, 10)}`;
    const session: Session = { id, phase: "collecting", mode: "single", intent: "book", userLang, updatedAt: Date.now() };
    this.sessions.set(id, session);
    return session;
  }

  get(id: string): Session | undefined {
    return this.sessions.get(id);
  }

  update(id: string, patch: Partial<Session>): Session | undefined {
    const s = this.sessions.get(id);
    if (!s) return undefined;
    Object.assign(s, patch, { updatedAt: Date.now() });
    return s;
  }
}
