/**
 * Business lookup: turn a goal ("a dentist near me") + a location into real
 * phone numbers to call. Provider-agnostic so it swaps, mirroring translate.ts.
 *   - GeminiBusinessSearch: Google Search grounding on the Gemini key.
 *   - MockBusinessSearch: reserved fictional numbers (555-01xx) for keyless local
 *     dev and deterministic tests — never dials anything real.
 *
 * SAFETY: numbers found here are surfaced at the confirm gate before any call, so
 * a wrong lookup can never place a call on its own.
 */

export interface BusinessMatch {
  name: string;
  phone: string; // best-effort E.164, e.g. +15125550142
  address?: string;
  source?: string; // where the number came from (grounding url), if known
}

export interface SearchOptions {
  near?: string; // "Austin, TX" — the user's location
  limit?: number; // how many results to return (1 for book, 3 for compare)
}

export interface BusinessSearch {
  readonly name: string;
  find(query: string, opts?: SearchOptions): Promise<BusinessMatch[]>;
}

/** Deterministic offline double — synthetic reserved numbers, no network. */
export class MockBusinessSearch implements BusinessSearch {
  readonly name = "mock(business)";
  async find(query: string, opts: SearchOptions = {}): Promise<BusinessMatch[]> {
    const limit = Math.max(1, Math.min(opts.limit ?? 1, 3));
    const near = opts.near?.trim();
    const base = query.trim().replace(/\s+/g, " ").slice(0, 40) || "Business";
    // 555-0100..555-0199 is the reserved range for fictional use.
    return Array.from({ length: limit }, (_, i) => ({
      name: `${titleCase(base)} ${String.fromCharCode(65 + i)}`,
      phone: `+1555010${(140 + i).toString().padStart(3, "0")}`,
      address: near ? `${100 + i} Main St, ${near}` : undefined,
      source: "mock",
    }));
  }
}

/** Real lookup via Gemini with Google Search grounding. */
export class GeminiBusinessSearch implements BusinessSearch {
  readonly name: string;
  constructor(
    private readonly apiKey: string,
    private readonly model = process.env.GEMINI_MODEL || "gemini-flash-latest",
  ) {
    this.name = `gemini-search(${this.model})`;
  }

  async find(query: string, opts: SearchOptions = {}): Promise<BusinessMatch[]> {
    const limit = Math.max(1, Math.min(opts.limit ?? 1, 5));
    const near = opts.near?.trim();
    const where = near ? ` near ${near}` : "";
    const prompt =
      `Find up to ${limit} real businesses matching this request${where}: "${query}". ` +
      `Use Google Search for current, real phone numbers. ` +
      `Respond with ONLY a JSON array (no prose, no code fences) of objects with keys ` +
      `"name", "phone", "address". Phone MUST be a dialable US number in E.164 form ` +
      `(e.g. +15125550142). Omit any business whose phone number you cannot verify.`;

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": this.apiKey },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        tools: [{ google_search: {} }],
        generationConfig: { temperature: 0 },
      }),
    });
    if (!res.ok) throw new Error(`Gemini search failed: HTTP ${res.status}`);
    const json = (await res.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = json.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("") ?? "";
    return parseMatches(text).slice(0, limit);
  }
}

/** Pull a JSON array of matches out of a (possibly fenced) model response. */
function parseMatches(text: string): BusinessMatch[] {
  const start = text.indexOf("[");
  const end = text.lastIndexOf("]");
  if (start === -1 || end === -1 || end <= start) return [];
  let parsed: unknown;
  try {
    parsed = JSON.parse(text.slice(start, end + 1));
  } catch {
    return [];
  }
  if (!Array.isArray(parsed)) return [];
  const out: BusinessMatch[] = [];
  for (const item of parsed) {
    if (!item || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;
    const name = typeof o.name === "string" ? o.name.trim() : "";
    const phone = normalizePhone(typeof o.phone === "string" ? o.phone : "");
    if (!name || !phone) continue;
    out.push({
      name,
      phone,
      address: typeof o.address === "string" && o.address.trim() ? o.address.trim() : undefined,
      source: "gemini",
    });
  }
  return out;
}

/** Best-effort US phone → E.164; returns "" if it doesn't look dialable. */
function normalizePhone(raw: string): string {
  const trimmed = raw.trim();
  if (/^\+\d{8,15}$/.test(trimmed)) return trimmed;
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith("1")) return `+${digits}`;
  return "";
}

function titleCase(s: string): string {
  return s.replace(/\w\S*/g, (w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase());
}

/** Pick a search provider from the environment: Gemini > Mock. */
export function createBusinessSearch(): BusinessSearch {
  const gemini = process.env.GEMINI_API_KEY?.trim();
  if (gemini) return new GeminiBusinessSearch(gemini);
  return new MockBusinessSearch();
}
