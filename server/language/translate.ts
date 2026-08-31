/**
 * Translation layer (user language ⇄ English). Provider-agnostic so it swaps.
 *   - OpenAITranslator: real translation when OPENAI_API_KEY is set.
 *   - MockTranslator: passthrough for keyless local dev (wiring + UI still work;
 *     text stays English until a key is provided).
 *
 * Only the user's side is translated — never the phone-call audio (that's CALL-E,
 * and the call is in English).
 */
import { LANGUAGES, type LangCode } from "./languages.js";

export interface Translator {
  /** User's language → English (for the call brief). */
  toEnglish(text: string, from: LangCode): Promise<string>;
  /** English → user's language (for the readback + result narration). */
  fromEnglish(text: string, to: LangCode): Promise<string>;
  readonly name: string;
}

export class MockTranslator implements Translator {
  readonly name = "mock(passthrough)";
  async toEnglish(text: string, _from: LangCode): Promise<string> {
    return text;
  }
  async fromEnglish(text: string, _to: LangCode): Promise<string> {
    return text;
  }
}

export class OpenAITranslator implements Translator {
  readonly name: string;
  constructor(
    private readonly apiKey: string,
    private readonly model = process.env.OPENAI_MODEL || "gpt-4o-mini",
  ) {
    this.name = `openai(${this.model})`;
  }

  async toEnglish(text: string, from: LangCode): Promise<string> {
    if (from === "en" || !text.trim()) return text;
    return this.translate(text, LANGUAGES[from].name, "English");
  }

  async fromEnglish(text: string, to: LangCode): Promise<string> {
    if (to === "en" || !text.trim()) return text;
    return this.translate(text, "English", LANGUAGES[to].name);
  }

  private async translate(text: string, fromName: string, toName: string): Promise<string> {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${this.apiKey}` },
      body: JSON.stringify({
        model: this.model,
        temperature: 0,
        messages: [
          {
            role: "system",
            content:
              `You are a translation engine. Translate the user's message from ${fromName} to ${toName}. ` +
              "Output ONLY the translation — no quotes, no notes, no preamble. Preserve numbers, names, and dates exactly.",
          },
          { role: "user", content: text },
        ],
      }),
    });
    if (!res.ok) {
      throw new Error(`OpenAI translate failed: HTTP ${res.status}`);
    }
    const json = (await res.json()) as { choices?: Array<{ message?: { content?: string } }> };
    return json.choices?.[0]?.message?.content?.trim() || text;
  }
}

export class GeminiTranslator implements Translator {
  readonly name: string;
  constructor(
    private readonly apiKey: string,
    private readonly model = process.env.GEMINI_MODEL || "gemini-2.0-flash",
  ) {
    this.name = `gemini(${this.model})`;
  }

  async toEnglish(text: string, from: LangCode): Promise<string> {
    if (from === "en" || !text.trim()) return text;
    return this.translate(text, LANGUAGES[from].name, "English");
  }

  async fromEnglish(text: string, to: LangCode): Promise<string> {
    if (to === "en" || !text.trim()) return text;
    return this.translate(text, "English", LANGUAGES[to].name);
  }

  private async translate(text: string, fromName: string, toName: string): Promise<string> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;
    const res = await fetch(url, {
      method: "POST",
      // Key goes in a header, never the URL (keeps it out of logs).
      headers: { "content-type": "application/json", "x-goog-api-key": this.apiKey },
      body: JSON.stringify({
        systemInstruction: {
          parts: [
            {
              text:
                `You are a translation engine. Translate the user's message from ${fromName} to ${toName}. ` +
                "Output ONLY the translation — no quotes, no notes, no preamble. Preserve numbers, names, and dates exactly.",
            },
          ],
        },
        contents: [{ parts: [{ text }] }],
        generationConfig: { temperature: 0 },
      }),
    });
    if (!res.ok) {
      throw new Error(`Gemini translate failed: HTTP ${res.status}`);
    }
    const json = (await res.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    return json.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || text;
  }
}

/** Pick a translator from the environment: Gemini > OpenAI > passthrough. */
export function createTranslator(): Translator {
  const gemini = process.env.GEMINI_API_KEY?.trim();
  if (gemini) return new GeminiTranslator(gemini);
  const openai = process.env.OPENAI_API_KEY?.trim();
  if (openai) return new OpenAITranslator(openai);
  return new MockTranslator();
}
