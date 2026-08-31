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

export interface Session {
  id: string;
  phase: SessionPhase;
  userLang: LangCode;
  originalText?: string; // the user's goal in their own language
  brief?: CallBrief; // the English brief handed to CALL-E
  understanding?: GoalUnderstanding;
  runId?: string;
  statusLine?: string | null;
  result?: NarratedResult;
  errorMessage?: string;
  updatedAt: number;
}

/** The wire shape the app polls (matches the iOS SessionState model). */
export interface SessionStateDTO {
  sessionId: string;
  phase: SessionPhase;
  statusLine: string | null;
  understanding: GoalUnderstanding | null;
  result: NarratedResult | null;
  errorMessage: string | null;
}

export function toDTO(s: Session): SessionStateDTO {
  return {
    sessionId: s.id,
    phase: s.phase,
    statusLine: s.statusLine ?? null,
    understanding: s.understanding ?? null,
    result: s.result ?? null,
    errorMessage: s.errorMessage ?? null,
  };
}

export class SessionStore {
  private sessions = new Map<string, Session>();

  create(userLang: LangCode): Session {
    const id = `sess_${Math.random().toString(36).slice(2, 10)}`;
    const session: Session = { id, phase: "collecting", userLang, updatedAt: Date.now() };
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
