/**
 * Extract available appointment slots from a "discover" call's summary/transcript
 * (speculative two-call booking, C4). Same provider creds as translation:
 * Gemini > OpenAI > naive regex fallback.
 */
export interface SlotExtractor {
  extract(goalEnglish: string, summary: string, transcript: string): Promise<string[]>;
  readonly name: string;
}

/** Grab things that look like "Tuesday 3:30pm" / "Sat 2pm" / "March 4 at 10am". */
export class NaiveSlotExtractor implements SlotExtractor {
  readonly name = "naive";
  async extract(_goal: string, summary: string, transcript: string): Promise<string[]> {
    const text = `${summary}\n${transcript}`;
    const re =
      /((?:mon|tues|wednes|thurs|fri|satur|sun)day|mon|tue|wed|thu|fri|sat|sun|tomorrow|today)[^.,;\n]*?\d{1,2}(?::\d{2})?\s*(?:am|pm)/gi;
    const found = new Set<string>();
    for (const m of text.matchAll(re)) found.add(m[0].trim().replace(/\s+/g, " "));
    return [...found].slice(0, 6);
  }
}

abstract class LLMSlotExtractor implements SlotExtractor {
  abstract readonly name: string;
  protected abstract complete(prompt: string): Promise<string>;

  async extract(goalEnglish: string, summary: string, transcript: string): Promise<string[]> {
    const prompt =
      `A phone call was made to find available appointment times for: ${goalEnglish}\n\n` +
      `Call summary:\n${summary}\n\nTranscript:\n${transcript}\n\n` +
      `List ONLY the specific appointment times the business said are available. ` +
      `Respond as minified JSON: {"slots":["Saturday 3:30pm","Saturday 4:30pm"]}. ` +
      `If none were offered, return {"slots":[]}. Keep each slot short and human-readable.`;
    try {
      const text = await this.complete(prompt);
      const json = JSON.parse(stripFences(text)) as { slots?: unknown };
      const slots = Array.isArray(json.slots)
        ? json.slots.filter((s): s is string => typeof s === "string" && s.trim().length > 0)
        : [];
      if (slots.length) return slots.slice(0, 8).map((s) => s.trim());
    } catch {
      /* fall through to naive */
    }
    return new NaiveSlotExtractor().extract(goalEnglish, summary, transcript);
  }
}

export class GeminiSlotExtractor extends LLMSlotExtractor {
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
    if (!res.ok) throw new Error(`Gemini slots HTTP ${res.status}`);
    const json = (await res.json()) as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> };
    return json.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  }
}

export class OpenAISlotExtractor extends LLMSlotExtractor {
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
    if (!res.ok) throw new Error(`OpenAI slots HTTP ${res.status}`);
    const json = (await res.json()) as { choices?: Array<{ message?: { content?: string } }> };
    return json.choices?.[0]?.message?.content ?? "";
  }
}

function stripFences(text: string): string {
  return text.trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
}

export function createSlotExtractor(): SlotExtractor {
  const gemini = process.env.GEMINI_API_KEY?.trim();
  if (gemini) return new GeminiSlotExtractor(gemini);
  const openai = process.env.OPENAI_API_KEY?.trim();
  if (openai) return new OpenAISlotExtractor(openai);
  return new NaiveSlotExtractor();
}
