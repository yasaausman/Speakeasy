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
  | "done"
  | "failed";

/** What the app shows the user to confirm before any call goes out. */
export interface GoalUnderstanding {
  understoodGoalEnglish: string;
  readbackUserLang: string;
  targetNumber: string;
}

/** CallResult (from server/calle) plus the translated narration for the user. */
export interface NarratedResult extends CallResult {
  outcomeUserLang: string | null;
}

/** One place's result in a multi-call comparison (C1). */
export interface RankedResult {
  number: string;
  result: NarratedResult;
}

export type SessionMode = "single" | "multi";

export interface Session {
  id: string;
  phase: SessionPhase;
  mode: SessionMode;
  userLang: LangCode;
  originalText?: string; // the user's goal in their own language
  englishGoal?: string; // translated goal
  brief?: CallBrief; // the English brief handed to CALL-E (single mode)
  numbers?: string[]; // destinations (multi mode)
  understanding?: GoalUnderstanding;
  facts?: Record<string, string>; // saved details the agent can share (single mode)
  runId?: string;
  statusLine?: string | null;
  activity?: string[]; // live transcript lines during the call (single mode)
  result?: NarratedResult; // single mode
  ranked?: RankedResult[]; // multi mode, best-first
  winnerReason?: string | null; // multi mode, in the user's language
  errorMessage?: string;
  updatedAt: number;
}

/** The wire shape the app polls (matches the iOS SessionState model). */
export interface SessionStateDTO {
  sessionId: string;
  phase: SessionPhase;
  mode: SessionMode;
  statusLine: string | null;
  activity: string[] | null;
  understanding: GoalUnderstanding | null;
  result: NarratedResult | null;
  ranked: RankedResult[] | null;
  winnerReason: string | null;
  errorMessage: string | null;
}

export function toDTO(s: Session): SessionStateDTO {
  return {
    sessionId: s.id,
    phase: s.phase,
    mode: s.mode,
    statusLine: s.statusLine ?? null,
    activity: s.activity ?? null,
    understanding: s.understanding ?? null,
    result: s.result ?? null,
    ranked: s.ranked ?? null,
    winnerReason: s.winnerReason ?? null,
    errorMessage: s.errorMessage ?? null,
  };
}

export class SessionStore {
  private sessions = new Map<string, Session>();

  create(userLang: LangCode): Session {
    const id = `sess_${Math.random().toString(36).slice(2, 10)}`;
    const session: Session = { id, phase: "collecting", mode: "single", userLang, updatedAt: Date.now() };
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
