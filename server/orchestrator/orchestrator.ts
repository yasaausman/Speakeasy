/**
 * The orchestration state machine:
 *   collecting → confirming → calling → polling → narrating → done | failed
 *
 * Ties the language layer (translate) to the CALL-E client (server/calle). The
 * confirm gate lives here: confirmAndCall() is the ONLY path to a paid call.
 */
import { createCalleClient, type CalleClient } from "../calle/client.js";
import type { CallBrief } from "../calle/types.js";
import { createTranslator, type Translator } from "../language/translate.js";
import type { LangCode } from "../language/languages.js";
import { SessionStore, type GoalUnderstanding, type Session } from "./session.js";

export interface OrchestratorOptions {
  calle?: CalleClient;
  translator?: Translator;
  defaultTargetNumber?: string;
}

const DISCLOSURE =
  "This is an AI assistant calling on behalf of a user — I'm not a human. I'm placing this call for them.";

export class Orchestrator {
  readonly store = new SessionStore();
  private readonly calle: CalleClient;
  private readonly translator: Translator;
  private readonly defaultTargetNumber: string;

  constructor(opts: OrchestratorOptions = {}) {
    // Fake CALL-E transport by default; slower fake polling so live status is visible.
    this.calle =
      opts.calle ??
      createCalleClient({ poll: { firstDelayMs: 1500, intervalMs: 1500, maxWaitMs: 30_000 } });
    this.translator = opts.translator ?? createTranslator();
    this.defaultTargetNumber = opts.defaultTargetNumber || process.env.DEMO_TARGET_NUMBER || "+15555550123";
  }

  createSession(userLang: LangCode): Session {
    return this.store.create(userLang);
  }

  /** collecting → confirming. Translate the goal to English, draft the brief,
   *  and produce a readback in the user's language. No call is placed. */
  async submitGoal(
    sessionId: string,
    text: string,
    userLang: LangCode,
    targetNumber?: string,
  ): Promise<GoalUnderstanding> {
    const s = this.store.get(sessionId);
    if (!s) throw new Error("unknown session");

    const englishGoal = (await this.translator.toEnglish(text, userLang)).trim();
    const number = targetNumber?.trim() || this.defaultTargetNumber;
    const brief = buildBrief(englishGoal, number);

    const readbackEnglish = `You want me to call ${number} and: ${englishGoal}. Is that correct?`;
    const readbackUserLang = await this.translator.fromEnglish(readbackEnglish, userLang);

    const understanding: GoalUnderstanding = {
      understoodGoalEnglish: englishGoal,
      readbackUserLang,
      targetNumber: number,
    };

    this.store.update(sessionId, {
      phase: "confirming",
      userLang,
      originalText: text,
      brief,
      understanding,
    });
    return understanding;
  }

  /** confirming → calling. THE CONFIRM GATE. Kicks off plan→run→poll in the
   *  background and returns immediately; the app polls getSession for progress. */
  confirmAndCall(sessionId: string): void {
    const s = this.store.get(sessionId);
    if (!s) throw new Error("unknown session");
    if (s.phase !== "confirming" || !s.brief) throw new Error("session is not awaiting confirmation");

    this.store.update(sessionId, { phase: "calling", statusLine: "Starting the call…" });
    void this.runInBackground(sessionId, s.brief, s.userLang);
  }

  getSession(sessionId: string): Session | undefined {
    return this.store.get(sessionId);
  }

  private async runInBackground(sessionId: string, brief: CallBrief, userLang: LangCode): Promise<void> {
    try {
      const result = await this.calle.runBrief(brief, (r) => {
        this.store.update(sessionId, {
          phase: "polling",
          statusLine: r.summary?.trim() || `Status: ${r.status ?? "…"}`,
        });
      });

      this.store.update(sessionId, { phase: "narrating", statusLine: "Wrapping up…" });
      const outcomeUserLang = await this.translator.fromEnglish(result.outcome, userLang);

      this.store.update(sessionId, {
        phase: "done",
        statusLine: null,
        result: { ...result, outcomeUserLang },
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      const errorUserLang = await this.translator
        .fromEnglish(`The call could not be completed: ${message}`, userLang)
        .catch(() => message);
      this.store.update(sessionId, { phase: "failed", statusLine: null, errorMessage: errorUserLang });
    }
  }
}

/** Compose an English CallBrief from the translated goal. AI disclosure is
 *  always included (golden rule #6). Facts/constraints are minimal for now —
 *  a later milestone can collect them from the user. */
function buildBrief(englishGoal: string, targetNumber: string): CallBrief {
  return {
    objective: englishGoal,
    targetNumber,
    targetRegion: "US",
    language: "English",
    constraints: [],
    facts: {},
    successCondition: "the task in the objective is completed and any confirmation number is captured",
    fallback: "if the task cannot be completed, report clearly what was and wasn't possible",
    agentDisclosure: DISCLOSURE,
  };
}
