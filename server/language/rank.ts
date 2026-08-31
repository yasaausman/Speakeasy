/**
 * Rank multiple call outcomes against the user's goal (multi-call mode, C1).
 * Uses the same provider creds as translation: Gemini > OpenAI > heuristic.
 * The LLM path handles any goal ("soonest", "cheapest", "closest") in English;
 * the heuristic fallback just keeps completed calls first, original order.
 */
export interface RankItem {
  label: string; // e.g. the place / phone number
  status: string; // normalized status ("completed", ...)
  summary: string; // English outcome summary
}

export interface RankResult {
  order: number[]; // item indices, best first
  winnerReason: string; // one English sentence about the top pick
}

export interface Ranker {
  rank(goalEnglish: string, items: RankItem[]): Promise<RankResult>;
  readonly name: string;
}

/** Completed-first, otherwise original order. No cross-item reasoning. */
export class HeuristicRanker implements Ranker {
  readonly name = "heuristic";
  async rank(_goal: string, items: RankItem[]): Promise<RankResult> {
    const order = items
      .map((it, i) => ({ i, done: it.status === "completed" }))
      .sort((a, b) => Number(b.done) - Number(a.done))
      .map((x) => x.i);
    const top = items[order[0]];
    return { order, winnerReason: top ? `${top.label}: ${top.summary}` : "No results." };
  }
}

abstract class LLMRanker implements Ranker {
  abstract readonly name: string;
  protected abstract complete(prompt: string): Promise<string>;

  async rank(goalEnglish: string, items: RankItem[]): Promise<RankResult> {
    if (items.length <= 1) {
      return { order: items.map((_, i) => i), winnerReason: items[0]?.summary ?? "No results." };
    }
    const list = items.map((it, i) => `${i}) [${it.status}] ${it.label}: ${it.summary}`).join("\n");
    const prompt =
      `Goal: ${goalEnglish}\n\nOutcomes from calling several places:\n${list}\n\n` +
      `Rank the outcomes from best to worst for achieving the goal. Prefer completed calls. ` +
      `Respond ONLY with minified JSON: {"order":[indices best-first],"winner_reason":"one short sentence naming the best place and why"}.`;
    try {
      const text = await this.complete(prompt);
      const json = JSON.parse(stripFences(text)) as { order?: number[]; winner_reason?: string };
      const order = sanitizeOrder(json.order, items.length);
      return { order, winnerReason: (json.winner_reason || items[order[0]]?.summary || "").trim() };
    } catch {
      return new HeuristicRanker().rank(goalEnglish, items);
    }
  }
}

export class GeminiRanker extends LLMRanker {
  readonly name: string;
  constructor(private readonly apiKey: string, private readonly model = process.env.GEMINI_MODEL || "gemini-flash-latest") {
    super();
    this.name = `gemini(${this.model})`;
  }
  protected async complete(prompt: string): Promise<string> {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": this.apiKey },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { temperature: 0 } }),
    });
    if (!res.ok) throw new Error(`Gemini rank HTTP ${res.status}`);
    const json = (await res.json()) as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> };
    return json.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  }
}

export class OpenAIRanker extends LLMRanker {
  readonly name: string;
  constructor(private readonly apiKey: string, private readonly model = process.env.OPENAI_MODEL || "gpt-4o-mini") {
    super();
    this.name = `openai(${this.model})`;
  }
  protected async complete(prompt: string): Promise<string> {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${this.apiKey}` },
      body: JSON.stringify({ model: this.model, temperature: 0, messages: [{ role: "user", content: prompt }] }),
    });
    if (!res.ok) throw new Error(`OpenAI rank HTTP ${res.status}`);
    const json = (await res.json()) as { choices?: Array<{ message?: { content?: string } }> };
    return json.choices?.[0]?.message?.content ?? "";
  }
}

function stripFences(text: string): string {
  return text.trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
}

function sanitizeOrder(order: number[] | undefined, n: number): number[] {
  const seen = new Set<number>();
  const clean = (order ?? []).filter((i) => Number.isInteger(i) && i >= 0 && i < n && !seen.has(i) && (seen.add(i), true));
  for (let i = 0; i < n; i++) if (!seen.has(i)) clean.push(i);
  return clean;
}

export function createRanker(): Ranker {
  const gemini = process.env.GEMINI_API_KEY?.trim();
  if (gemini) return new GeminiRanker(gemini);
  const openai = process.env.OPENAI_API_KEY?.trim();
  if (openai) return new OpenAIRanker(openai);
  return new HeuristicRanker();
}
