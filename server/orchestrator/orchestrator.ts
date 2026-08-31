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
import { createRanker, type Ranker } from "../language/rank.js";
import type { LangCode } from "../language/languages.js";
import { SessionStore, type GoalUnderstanding, type RankedResult, type Session } from "./session.js";

export interface OrchestratorOptions {
  calle?: CalleClient;
  translator?: Translator;
  ranker?: Ranker;
  defaultTargetNumber?: string;
}

const DISCLOSURE =
  "This is an AI assistant calling on behalf of a user — I'm not a human. I'm placing this call for them.";

export class Orchestrator {
  readonly store = new SessionStore();
  readonly translatorName: string;
  private readonly calle: CalleClient;
  private readonly translator: Translator;
  private readonly ranker: Ranker;
  private readonly defaultTargetNumber: string;

  constructor(opts: OrchestratorOptions = {}) {
    // Fake CALL-E transport by default; slower fake polling so live status is visible.
    this.calle =
      opts.calle ??
      createCalleClient({ poll: { firstDelayMs: 1500, intervalMs: 1500, maxWaitMs: 30_000 } });
    this.translator = opts.translator ?? createTranslator();
    this.ranker = opts.ranker ?? createRanker();
    this.translatorName = this.translator.name;
    this.defaultTargetNumber = opts.defaultTargetNumber || process.env.DEMO_TARGET_NUMBER || "+15555550123";
  }

  createSession(userLang: LangCode): Session {
    return this.store.create(userLang);
  }

  /** collecting → confirming. Translate the goal to English, draft the brief(s),
   *  and produce a readback in the user's language. No call is placed.
   *  One number → single mode; several → multi-call comparison (C1). */
  async submitGoal(
    sessionId: string,
    text: string,
    userLang: LangCode,
    numbers?: string[],
  ): Promise<GoalUnderstanding> {
    const s = this.store.get(sessionId);
    if (!s) throw new Error("unknown session");

    const englishGoal = (await this.translator.toEnglish(text, userLang)).trim();
    const cleaned = (numbers ?? []).map((n) => n.trim()).filter(Boolean);
    const multi = cleaned.length > 1;
    const targets = cleaned.length ? cleaned : [this.defaultTargetNumber];

    const readbackEnglish = multi
      ? `You want me to call ${targets.length} places and, for each: ${englishGoal}. Then I'll tell you the best option. Is that correct?`
      : `You want me to call ${targets[0]} and: ${englishGoal}. Is that correct?`;
    const readbackUserLang = await this.translator.fromEnglish(readbackEnglish, userLang);

    const understanding: GoalUnderstanding = {
      understoodGoalEnglish: englishGoal,
      readbackUserLang,
      targetNumber: multi ? `${targets.length} places` : targets[0],
    };

    this.store.update(sessionId, {
      phase: "confirming",
      mode: multi ? "multi" : "single",
      userLang,
      originalText: text,
      englishGoal,
      numbers: targets,
      brief: multi ? undefined : buildBrief(englishGoal, targets[0]),
      understanding,
    });
    return understanding;
  }

  /** confirming → calling. THE CONFIRM GATE. Kicks off the call(s) in the
   *  background and returns immediately; the app polls getSession for progress. */
  confirmAndCall(sessionId: string): void {
    const s = this.store.get(sessionId);
    if (!s) throw new Error("unknown session");
    if (s.phase !== "confirming") throw new Error("session is not awaiting confirmation");

    if (s.mode === "multi" && s.englishGoal && s.numbers) {
      this.store.update(sessionId, { phase: "calling", statusLine: `Calling ${s.numbers.length} places…` });
      void this.runFanout(sessionId, s.englishGoal, s.numbers, s.userLang);
      return;
    }
    if (!s.brief) throw new Error("session has no brief");
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

  /** Multi-call (C1): call every number in parallel, then rank the outcomes. */
  private async runFanout(
    sessionId: string,
    englishGoal: string,
    numbers: string[],
    userLang: LangCode,
  ): Promise<void> {
    try {
      this.store.update(sessionId, { phase: "polling", statusLine: `Calling ${numbers.length} places…` });

      const results: RankedResult[] = await Promise.all(
        numbers.map(async (number): Promise<RankedResult> => {
          try {
            const result = await this.calle.runBrief(buildBrief(englishGoal, number));
            const outcomeUserLang = await this.translator.fromEnglish(result.outcome, userLang);
            return { number, result: { ...result, outcomeUserLang } };
          } catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            const outcomeUserLang = await this.translator.fromEnglish(msg, userLang).catch(() => msg);
            return {
              number,
              result: {
                status: "failed",
                rawStatus: "FAILED",
                outcome: msg,
                outcomeUserLang,
                structured: {},
                confirmationNumbers: [],
                transcript: "",
              },
            };
          }
        }),
      );

      this.store.update(sessionId, { phase: "narrating", statusLine: "Comparing the results…" });

      const ranking = await this.ranker.rank(
        englishGoal,
        results.map((r) => ({ label: r.number, status: r.result.status, summary: r.result.outcome })),
      );
      const ranked = ranking.order.map((i) => results[i]).filter(Boolean);
      const winnerReason = await this.translator
        .fromEnglish(ranking.winnerReason, userLang)
        .catch(() => ranking.winnerReason);

      this.store.update(sessionId, { phase: "done", statusLine: null, ranked, winnerReason });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      const errorUserLang = await this.translator
        .fromEnglish(`The comparison could not be completed: ${message}`, userLang)
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
