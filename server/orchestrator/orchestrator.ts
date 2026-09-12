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
import { createSlotExtractor, type SlotExtractor } from "../language/slots.js";
import { createIntentClassifier, type IntentClassifier, type GoalMode } from "../language/intent.js";
import { createBusinessSearch, type BusinessSearch } from "../search/business.js";
import type { LangCode } from "../language/languages.js";
import {
  SessionStore,
  type CallIntent,
  type CallPreferences,
  type FoundBusiness,
  type GoalUnderstanding,
  type RankedResult,
  type Session,
  type SlotOption,
} from "./session.js";

export interface OrchestratorOptions {
  calle?: CalleClient;
  translator?: Translator;
  ranker?: Ranker;
  slotExtractor?: SlotExtractor;
  search?: BusinessSearch;
  classifier?: IntentClassifier;
}

/** Everything that shapes a brief beyond the goal text. */
export interface GoalOptions {
  numbers?: string[];
  facts?: Record<string, string>;
  preferences?: CallPreferences;
  availability?: string;
  intent?: CallIntent;
  location?: string; // user's location, for business lookup ("near me")
}

/** Params for composing a CallBrief. */
interface BriefContext {
  facts?: Record<string, string>;
  preferences?: CallPreferences;
  availability?: string;
  intent?: CallIntent;
}

const DISCLOSURE =
  "This is an AI assistant calling on behalf of a user — I'm not a human. I'm placing this call for them.";

export class Orchestrator {
  readonly store = new SessionStore();
  readonly translatorName: string;
  readonly searchName: string;
  readonly classifierName: string;
  /** "real" places live phone calls; "fake" is the dry-run transport. */
  readonly calleMode: "fake" | "real" = process.env.CALLE_MODE === "real" ? "real" : "fake";
  private readonly calle: CalleClient;
  private readonly translator: Translator;
  private readonly ranker: Ranker;
  private readonly slotExtractor: SlotExtractor;
  private readonly search: BusinessSearch;
  private readonly classifier: IntentClassifier;

  constructor(opts: OrchestratorOptions = {}) {
    // Fake CALL-E transport by default; slower fake polling so live status is visible.
    this.calle =
      opts.calle ??
      createCalleClient({ poll: { firstDelayMs: 1800, intervalMs: 2200, maxWaitMs: 30_000 } });
    this.translator = opts.translator ?? createTranslator();
    this.ranker = opts.ranker ?? createRanker();
    this.slotExtractor = opts.slotExtractor ?? createSlotExtractor();
    this.search = opts.search ?? createBusinessSearch();
    this.classifier = opts.classifier ?? createIntentClassifier();
    this.translatorName = this.translator.name;
    this.searchName = this.search.name;
    this.classifierName = this.classifier.name;
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
    opts: GoalOptions = {},
  ): Promise<GoalUnderstanding> {
    const s = this.store.get(sessionId);
    if (!s) throw new Error("unknown session");

    const englishGoal = (await this.translator.toEnglish(text, userLang)).trim();
    const cleaned = (opts.numbers ?? []).map((n) => n.trim()).filter(Boolean);

    // Decide who to call. If the app supplied number(s) (a Contacts pick), respect
    // them. Otherwise infer the mode from the goal and look up real business
    // numbers from the goal + the user's location.
    let targets: string[];
    let multi: boolean;
    let intent: CallIntent;
    let businesses: FoundBusiness[] | undefined;

    if (cleaned.length > 0) {
      targets = cleaned;
      multi = cleaned.length > 1;
      intent = opts.intent === "discover" ? "discover" : "book";
    } else {
      const mode: GoalMode =
        opts.intent === "discover" ? "discover" : await this.classifier.classify(englishGoal);
      const limit = mode === "compare" ? 3 : 1;
      const matches = await this.search.find(englishGoal, { near: opts.location, limit });
      if (matches.length === 0) {
        throw new Error("I couldn't find a phone number for that. Try naming the place, or add a location.");
      }
      businesses = matches.map((m) => ({ name: m.name, phone: m.phone, address: m.address }));
      targets = matches.map((m) => m.phone);
      multi = mode === "compare" && targets.length > 1;
      intent = mode === "discover" ? "discover" : "book";
    }

    const cleanFacts = cleanupFacts(opts.facts);
    const preferences = cleanupPreferences(opts.preferences);
    const availability = opts.availability?.trim() || undefined;
    const ctx: BriefContext = { facts: cleanFacts, preferences, availability, intent };

    // Prefer business names in the readback when we looked the numbers up.
    const primaryLabel = businesses?.[0] ? `${businesses[0].name} (${targets[0]})` : targets[0];
    const placesLabel = businesses ? businesses.map((b) => b.name).join(", ") : `${targets.length} places`;

    const readbackEnglish = multi
      ? `You want me to call ${placesLabel} and, for each: ${englishGoal}. Then I'll tell you the best option. Is that correct?`
      : intent === "discover"
        ? `You want me to call ${primaryLabel} and ask what appointment times are available for: ${englishGoal}. I won't book anything yet — I'll bring you the options. Is that correct?`
        : `You want me to call ${primaryLabel} and: ${englishGoal}. Is that correct?`;
    const readbackUserLang = await this.translator.fromEnglish(readbackEnglish, userLang);

    const understanding: GoalUnderstanding = {
      understoodGoalEnglish: englishGoal,
      readbackUserLang,
      targetNumber: multi ? `${targets.length} places` : targets[0],
      businesses,
    };

    this.store.update(sessionId, {
      phase: "confirming",
      mode: multi ? "multi" : "single",
      intent,
      userLang,
      originalText: text,
      englishGoal,
      numbers: targets,
      facts: cleanFacts,
      preferences,
      availability,
      options: undefined,
      brief: multi ? undefined : buildBrief(englishGoal, targets[0], ctx),
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
      const ctx: BriefContext = { facts: s.facts, preferences: s.preferences, availability: s.availability, intent: "book" };
      this.store.update(sessionId, { phase: "calling", statusLine: `Calling ${s.numbers.length} places…` });
      void this.runFanout(sessionId, s.englishGoal, s.numbers, s.userLang, ctx);
      return;
    }
    if (!s.brief) throw new Error("session has no brief");
    const startLine = s.intent === "discover" ? "Calling to check availability…" : "Starting the call…";
    this.store.update(sessionId, { phase: "calling", statusLine: startLine });
    void this.runInBackground(sessionId, s.brief, s.userLang, s.intent, s.englishGoal ?? "");
  }

  getSession(sessionId: string): Session | undefined {
    return this.store.get(sessionId);
  }

  private async runInBackground(
    sessionId: string,
    brief: CallBrief,
    userLang: LangCode,
    intent: CallIntent,
    englishGoal: string,
  ): Promise<void> {
    try {
      const result = await this.calle.runBrief(brief, (r) => {
        this.store.update(sessionId, {
          phase: "polling",
          statusLine: r.summary?.trim() || `Status: ${r.status ?? "…"}`,
          activity: extractActivity(r.activity),
        });
      });

      const outcomeUserLang = await this.translator.fromEnglish(result.outcome, userLang);

      // Speculative discovery: pull available slots for the user to choose from.
      if (intent === "discover") {
        this.store.update(sessionId, { phase: "narrating", statusLine: "Finding available times…" });
        const slots = await this.slotExtractor
          .extract(englishGoal, result.outcome, result.transcript)
          .catch(() => [] as string[]);
        const options: SlotOption[] = await Promise.all(
          slots.map(async (label, i) => ({
            id: `slot-${i}`,
            label,
            labelUserLang: await this.translator.fromEnglish(label, userLang).catch(() => label),
          })),
        );
        this.store.update(sessionId, {
          phase: "done",
          statusLine: null,
          result: { ...result, outcomeUserLang },
          options,
        });
        return;
      }

      this.store.update(sessionId, { phase: "narrating", statusLine: "Wrapping up…" });
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
    ctx: BriefContext,
  ): Promise<void> {
    try {
      this.store.update(sessionId, { phase: "polling", statusLine: `Calling ${numbers.length} places…` });

      const results: RankedResult[] = await Promise.all(
        numbers.map(async (number): Promise<RankedResult> => {
          try {
            const result = await this.calle.runBrief(buildBrief(englishGoal, number, ctx));
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

/** Compose an English CallBrief from the translated goal + front-loaded context.
 *  AI disclosure is always included (golden rule #6). Preferences and the user's
 *  availability become constraints + a ranked fallback, so the agent handles an
 *  unavailable slot itself instead of needing a (nonexistent) live hold. */
function buildBrief(englishGoal: string, targetNumber: string, ctx: BriefContext = {}): CallBrief {
  const { facts, preferences: p, availability, intent = "book" } = ctx;
  const constraints: string[] = [];
  if (p?.preferredTimes) constraints.push(`Preferred time: ${p.preferredTimes}`);
  if (availability) constraints.push(`The user is free at these times — prefer these: ${availability}`);
  if (p?.avoid) constraints.push(`Do NOT book these times: ${p.avoid}`);
  if (p?.budget) constraints.push(`Budget: keep it within ${p.budget}`);

  if (intent === "discover") {
    return {
      objective: `Call and ask what appointment times are available for: ${englishGoal}. Do NOT book anything — just collect the specific available dates and times and report them.`,
      targetNumber,
      targetRegion: "US",
      language: "English",
      constraints,
      facts: facts ?? {},
      successCondition: "a clear list of the specific available appointment times is collected (no booking made)",
      fallback: "if they will not share availability over the phone, report that and note their hours",
      agentDisclosure: DISCLOSURE,
    };
  }

  const fallback = p?.fallbackTimes
    ? `If the preferred time isn't available, use these alternatives in order of preference: ${p.fallbackTimes}. Book the best acceptable slot — do not leave without booking if any acceptable time exists. Only if nothing acceptable is available, report the options they offered.`
    : "if the task cannot be completed, report clearly what was and wasn't possible, including any times they did offer";

  return {
    objective: englishGoal,
    targetNumber,
    targetRegion: "US",
    language: "English",
    constraints,
    facts: facts ?? {},
    successCondition: "the task in the objective is completed and any confirmation number is captured",
    fallback,
    agentDisclosure: DISCLOSURE,
  };
}

/** Drop empty keys/values from the saved-details facts. */
function cleanupFacts(facts?: Record<string, string>): Record<string, string> | undefined {
  if (!facts) return undefined;
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(facts)) {
    const key = k.trim();
    const val = typeof v === "string" ? v.trim() : "";
    if (key && val) out[key] = val;
  }
  return Object.keys(out).length ? out : undefined;
}

/** Trim empty preference fields; return undefined if nothing is set. */
function cleanupPreferences(p?: CallPreferences): CallPreferences | undefined {
  if (!p) return undefined;
  const t = (v?: string) => {
    const s = (v ?? "").trim();
    return s.length ? s : undefined;
  };
  const out: CallPreferences = {
    preferredTimes: t(p.preferredTimes),
    fallbackTimes: t(p.fallbackTimes),
    avoid: t(p.avoid),
    budget: t(p.budget),
  };
  return Object.values(out).some(Boolean) ? out : undefined;
}

/** Pull human-readable message strings out of CALL-E's activity feed. */
function extractActivity(activity: unknown): string[] {
  if (!Array.isArray(activity)) return [];
  const lines: string[] = [];
  for (const item of activity) {
    if (item && typeof item === "object" && typeof (item as { message?: unknown }).message === "string") {
      lines.push((item as { message: string }).message);
    }
  }
  return lines.slice(-14); // keep the most recent lines
}
