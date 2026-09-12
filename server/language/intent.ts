/**
 * Infer what the user wants when they don't say it explicitly — replaces the old
 * "compare" / "check availability" toggles.
 *   - book:     place a booking at one place ("book a 3pm haircut at Joe's").
 *   - compare:  they're unsure / want a recommendation ("find me a good dentist",
 *               "which clinic is best") → call a few places and pick the best.
 *   - discover: availability-first ("what times are open", "I'm flexible") → call
 *               to collect open slots, book nothing yet.
 *
 * Provider-agnostic like translate.ts: Gemini when keyed, else an offline
 * keyword heuristic so tests and keyless dev stay deterministic.
 */
export type GoalMode = "book" | "compare" | "discover";

export interface IntentClassifier {
  readonly name: string;
  classify(englishGoal: string): Promise<GoalMode>;
}

const DISCOVER_RE =
  /\b(availab|what times|which times|when can|when are|open slots?|free times?|flexible|any ?time|whenever|what.s open)\b/i;
const COMPARE_RE =
  /\b(recommend|suggest|which|compare|best|cheapest|nearest|closest|top|good|options?|a few|several|find me|not sure|somewhere)\b/i;

/** Offline, deterministic keyword classifier. */
export class HeuristicIntentClassifier implements IntentClassifier {
  readonly name = "heuristic(intent)";
  async classify(englishGoal: string): Promise<GoalMode> {
    const g = englishGoal.toLowerCase();
    if (DISCOVER_RE.test(g)) return "discover";
    if (COMPARE_RE.test(g)) return "compare";
    return "book";
  }
}

/** LLM classifier via Gemini — returns exactly one of the three modes. */
export class GeminiIntentClassifier implements IntentClassifier {
  readonly name: string;
  private readonly fallback = new HeuristicIntentClassifier();
  constructor(
    private readonly apiKey: string,
    private readonly model = process.env.GEMINI_MODEL || "gemini-flash-latest",
  ) {
    this.name = `gemini(intent:${this.model})`;
  }

  async classify(englishGoal: string): Promise<GoalMode> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json", "x-goog-api-key": this.apiKey },
        body: JSON.stringify({
          systemInstruction: {
            parts: [
              {
                text:
                  "Classify the user's phone-call goal into exactly one label. " +
                  'Reply with ONLY the label, no punctuation. Labels:\n' +
                  '"book" — they want to book/do a specific thing at one place.\n' +
                  '"compare" — they are unsure or want a recommendation; call a few places and pick best.\n' +
                  '"discover" — they want to know what times are available first, booking nothing yet.',
              },
            ],
          },
          contents: [{ parts: [{ text: englishGoal }] }],
          generationConfig: { temperature: 0 },
        }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = (await res.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      const label = json.candidates?.[0]?.content?.parts?.[0]?.text?.trim().toLowerCase() ?? "";
      if (label.includes("discover")) return "discover";
      if (label.includes("compare")) return "compare";
      if (label.includes("book")) return "book";
      return this.fallback.classify(englishGoal);
    } catch {
      return this.fallback.classify(englishGoal); // never block a goal on a classifier hiccup
    }
  }
}

/** Pick a classifier from the environment: Gemini > heuristic. */
export function createIntentClassifier(): IntentClassifier {
  const gemini = process.env.GEMINI_API_KEY?.trim();
  if (gemini) return new GeminiIntentClassifier(gemini);
  return new HeuristicIntentClassifier();
}
