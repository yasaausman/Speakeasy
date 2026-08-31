/**
 * The ONE module the rest of Speakeasy uses to talk to CALL-E.
 * Golden rule #2: nothing outside server/calle/ touches MCP directly.
 *
 * Exposes a transport-agnostic CalleClient with:
 *   - planCall / runCall / getCallRun  (thin wrappers over the 3 MCP tools)
 *   - pollRun     (60s → 5-10s cadence to a terminal state)
 *   - runBrief    (plan → run → poll → normalized CallResult)
 * and two transports: real MCP (OAuth) and a local Fake for dry-run.
 */
import type { Client } from "@modelcontextprotocol/sdk/client/index.js";
import type { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

import { connectCalle, type OAuthConfig } from "./oauth.js";
import {
  type CallBrief,
  type CallResult,
  type GetCallRunInput,
  type GetCallRunResult,
  type PlanCallInput,
  type PlanCallResult,
  type RunCallInput,
  type RunCallResult,
  isTerminalStatus,
  normalizeStatus,
} from "./types.js";

// ── Logging (redacted) ───────────────────────────────────────────────────────
type Logger = (event: string, payload?: Record<string, unknown>) => void;

const defaultLogger: Logger = (event, payload = {}) => {
  console.log(JSON.stringify({ src: "calle", event, ...payload, ts: new Date().toISOString() }));
};

// ── Transport abstraction ────────────────────────────────────────────────────
export interface CalleTransport {
  planCall(input: PlanCallInput): Promise<PlanCallResult>;
  runCall(input: RunCallInput): Promise<RunCallResult>;
  getCallRun(input: GetCallRunInput): Promise<GetCallRunResult>;
  close(): Promise<void>;
}

/** Prefer structuredContent; fall back to a JSON-object text block (per MCP docs). */
function extractStructured(result: unknown): Record<string, unknown> {
  const r = result as Record<string, unknown>;
  const structured = r?.structuredContent;
  if (structured && typeof structured === "object" && !Array.isArray(structured)) {
    return structured as Record<string, unknown>;
  }
  const content = Array.isArray(r?.content) ? (r.content as Array<Record<string, unknown>>) : [];
  for (const block of content) {
    if (block?.type === "text" && typeof block.text === "string") {
      try {
        const parsed = JSON.parse(block.text);
        if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
          return parsed as Record<string, unknown>;
        }
      } catch {
        // Not JSON — ignore, per docs we only accept a JSON object text block.
      }
    }
  }
  return {};
}

const str = (v: unknown): string | undefined => (typeof v === "string" ? v : undefined);
const strArr = (v: unknown): string[] | undefined =>
  Array.isArray(v) && v.every((x) => typeof x === "string") ? (v as string[]) : undefined;

// ── Real MCP transport ───────────────────────────────────────────────────────
export class McpCalleTransport implements CalleTransport {
  private client: Client | null = null;
  private transport: StreamableHTTPClientTransport | null = null;

  constructor(
    private readonly oauth: OAuthConfig,
    private readonly log: Logger = defaultLogger,
  ) {}

  private async ensureConnected(): Promise<Client> {
    if (this.client) return this.client;
    const { client, transport } = await connectCalle(this.oauth);
    this.client = client;
    this.transport = transport;
    const tools = await client.listTools();
    const names = tools.tools.map((t) => t.name);
    this.log("connected", { session_id: transport.sessionId ?? null, tools: names });
    for (const required of ["plan_call", "run_call", "get_call_run"]) {
      if (!names.includes(required)) {
        throw new Error(`CALL-E endpoint is missing required tool: ${required}`);
      }
    }
    return client;
  }

  private async call(name: string, args: Record<string, unknown>): Promise<Record<string, unknown>> {
    const client = await this.ensureConnected();
    this.log("tools/call:req", { tool: name, args: redactArgs(name, args) });
    const result = await client.callTool({ name, arguments: args });
    const structured = extractStructured(result);
    this.log("tools/call:res", { tool: name, status: str(structured.status) ?? null });
    return structured;
  }

  async planCall(input: PlanCallInput): Promise<PlanCallResult> {
    const s = await this.call("plan_call", input as Record<string, unknown>);
    return {
      plan_id: str(s.plan_id),
      confirm_token: str(s.confirm_token),
      ready_to_run: typeof s.ready_to_run === "boolean" ? s.ready_to_run : undefined,
      clarifying_questions: strArr(s.clarifying_questions),
      raw: s,
    };
  }

  async runCall(input: RunCallInput): Promise<RunCallResult> {
    const s = await this.call("run_call", input as Record<string, unknown>);
    return { run_id: str(s.run_id), status: str(s.status), next_step: s.next_step, raw: s };
  }

  async getCallRun(input: GetCallRunInput): Promise<GetCallRunResult> {
    const s = await this.call("get_call_run", input as Record<string, unknown>);
    // CALL-E nests the payload under `result`; fall back to top-level fields
    // (the fake transport puts them there directly).
    const result = s.result && typeof s.result === "object" ? (s.result as Record<string, unknown>) : {};
    const hasResult = Object.keys(result).length > 0;
    return {
      run_id: str(s.run_id),
      status: str(s.status),
      activity: s.activity,
      summary: str(result.summary) ?? str(result.post_summary) ?? str(s.summary) ?? str(s.message),
      details: hasResult ? result : s.details,
      transcript: str(result.transcript) ?? str(s.transcript),
      next_step: s.next_step,
      raw: s,
    };
  }

  async close(): Promise<void> {
    await this.transport?.close().catch(() => {});
    this.client = null;
    this.transport = null;
  }
}

/** Never log opaque secrets (confirm_token) or full personal facts. */
function redactArgs(_name: string, args: Record<string, unknown>): Record<string, unknown> {
  const out = { ...args };
  if ("confirm_token" in out) out.confirm_token = "<redacted>";
  return out;
}

// ── Fake transport (dry-run: no network, no auth, no real call) ──────────────
// Mirrors examples/shared/fake-mcp-broker-server.mjs behaviour closely enough
// to exercise the full plan → run → poll → terminal workflow. Results VARY by
// destination number (via a hash) so multi-call fan-out (C1) has real differences
// to rank. Uses unique plan/run ids so a shared instance is safe for concurrency.
type FakeScenario = { day: string; time: string; provider: string; conf: string; soonestRank: number };

const FAKE_SCENARIOS: FakeScenario[] = [
  { day: "Monday", time: "8:15am", provider: "City Dental", conf: "3120", soonestRank: 1 },
  { day: "Tuesday", time: "9:40am", provider: "Dr. Lee", conf: "4471", soonestRank: 2 },
  { day: "Wednesday", time: "11:00am", provider: "Bright Smiles", conf: "5562", soonestRank: 3 },
  { day: "Thursday", time: "2:00pm", provider: "Family Dentistry", conf: "7788", soonestRank: 4 },
  { day: "next Monday", time: "10:30am", provider: "Sunset Dental", conf: "9013", soonestRank: 5 },
];

function scenarioFor(number: string): FakeScenario {
  let h = 0;
  for (const ch of number) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return FAKE_SCENARIOS[h % FAKE_SCENARIOS.length];
}

export class FakeCalleTransport implements CalleTransport {
  private plans = new Map<string, string>(); // plan_id -> first to_phone
  private runs = new Map<string, { number: string; count: number }>();
  private seq = 0;
  constructor(private readonly log: Logger = defaultLogger) {}

  async planCall(input: PlanCallInput): Promise<PlanCallResult> {
    const planId = `fake-plan-${++this.seq}`;
    this.plans.set(planId, input.to_phones?.[0] ?? "unknown");
    this.log("fake:plan_call", { goal: input.goal ?? null, to_phones: input.to_phones ?? null });
    return { plan_id: planId, confirm_token: "fake-confirm-token", ready_to_run: true, raw: { plan_id: planId, ready_to_run: true } };
  }

  async runCall(input: RunCallInput): Promise<RunCallResult> {
    const number = this.plans.get(input.plan_id) ?? "unknown";
    const runId = `fake-run-${++this.seq}`;
    this.runs.set(runId, { number, count: 0 });
    this.log("fake:run_call", { plan_id: input.plan_id });
    return { run_id: runId, status: "QUEUED", raw: { run_id: runId, status: "QUEUED" } };
  }

  async getCallRun(input: GetCallRunInput): Promise<GetCallRunResult> {
    const st = this.runs.get(input.run_id) ?? { number: "unknown", count: 0 };
    st.count += 1;
    this.runs.set(input.run_id, st);
    const s = scenarioFor(st.number);
    const script = fakeScript(s);
    // Reveal ~2 conversation lines per poll → a live-feeling transcript feed.
    const revealed = Math.min(st.count * 2, script.length);
    const done = st.count >= 4;
    const status = done ? "COMPLETED" : "IN_PROGRESS";
    this.log("fake:get_call_run", { run_id: input.run_id, status });
    return {
      run_id: input.run_id,
      status,
      summary: done
        ? `Appointment available ${s.day} at ${s.time} with ${s.provider}. They accept Medicaid. Confirmation number ${s.conf}.`
        : "Speaking with reception…",
      transcript: done ? script.join("\n") : "",
      activity: script.slice(0, revealed).map((message) => ({ kind: "callee_realtime", message })),
      details: done
        ? { appointment: `${s.day} ${s.time}`, provider: s.provider, accepts_insurance: true, confirmation: s.conf, soonest_rank: s.soonestRank }
        : {},
      next_step: done ? null : { action: "poll" },
      raw: { run_id: input.run_id, status },
    };
  }

  async close(): Promise<void> {
    /* nothing to close */
  }
}

function fakeScript(s: FakeScenario): string[] {
  return [
    "Call is ringing…",
    "Call connected.",
    "Bot: Hi, I'm an AI assistant calling on behalf of a patient.",
    "Rep: Sure — what insurance do you have?",
    "Bot: The patient has Medicaid.",
    `Rep: We can do ${s.day} at ${s.time} with ${s.provider}.`,
    "Bot: That works — please book it.",
    `Rep: Booked. Confirmation number is ${s.conf}.`,
  ];
}

// ── High-level client ────────────────────────────────────────────────────────
export type PollOptions = {
  firstDelayMs: number; // wait before the first poll (docs: ~60s for real runs)
  intervalMs: number; // cadence after that (docs: 5-10s)
  maxWaitMs: number; // client-side monitoring deadline (does NOT cancel the call)
};

export type CalleClientOptions = {
  transport: CalleTransport;
  poll?: Partial<PollOptions>;
  log?: Logger;
};

const DEFAULT_POLL: PollOptions = { firstDelayMs: 60_000, intervalMs: 7_000, maxWaitMs: 12 * 60_000 };

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export class CalleClient {
  private readonly transport: CalleTransport;
  private readonly poll: PollOptions;
  private readonly log: Logger;

  constructor(opts: CalleClientOptions) {
    this.transport = opts.transport;
    this.poll = { ...DEFAULT_POLL, ...opts.poll };
    this.log = opts.log ?? defaultLogger;
  }

  planCall(input: PlanCallInput) {
    return this.transport.planCall(input);
  }
  runCall(input: RunCallInput) {
    return this.transport.runCall(input);
  }
  getCallRun(input: GetCallRunInput) {
    return this.transport.getCallRun(input);
  }
  close() {
    return this.transport.close();
  }

  /** Poll get_call_run until a terminal status or the monitoring deadline. */
  async pollRun(runId: string, onUpdate?: (r: GetCallRunResult) => void): Promise<GetCallRunResult> {
    const started = Date.now();
    await sleep(this.poll.firstDelayMs);
    let last: GetCallRunResult | null = null;
    while (Date.now() - started < this.poll.maxWaitMs) {
      const r = await this.getCallRun({ run_id: runId });
      last = r;
      onUpdate?.(r);
      if (isTerminalStatus(r.status)) return r;
      await sleep(this.poll.intervalMs);
    }
    this.log("poll:deadline", { run_id: runId, note: "monitoring deadline hit; call NOT cancelled" });
    return last ?? { run_id: runId, raw: {} };
  }

  /**
   * Compose Speakeasy's internal CallBrief into a single natural-language
   * `user_input` for plan_call, plus structured hints. The disclosure line is
   * always first and non-optional (golden rule #6).
   */
  static briefToUserInput(brief: CallBrief): PlanCallInput {
    const lines: string[] = [];
    lines.push(brief.agentDisclosure.trim());
    lines.push(`Goal: ${brief.objective.trim()}`);
    if (brief.constraints.length) lines.push(`Constraints: ${brief.constraints.join("; ")}.`);
    const facts = Object.entries(brief.facts);
    if (facts.length) {
      lines.push(
        `If the representative asks, here are the details I can share: ${facts
          .map(([k, v]) => `${k}: ${v}`)
          .join("; ")}.`,
      );
    }
    lines.push(
      "If they ask for information not listed above, do not guess — say you'll have to check and follow up.",
    );
    lines.push(`Success means: ${brief.successCondition.trim()}`);
    if (brief.fallback.trim()) lines.push(`If that isn't possible: ${brief.fallback.trim()}`);

    return {
      user_input: lines.join("\n"),
      to_phones: [brief.targetNumber],
      region: brief.targetRegion,
      language: brief.language,
      goal: brief.objective,
    };
  }

  /**
   * The full Phase 0 workflow: plan → (confirm handled by caller) → run → poll.
   * NOTE: this places a REAL call in real mode. Callers must have the user's
   * explicit confirmation before invoking (the orchestrator's confirm gate).
   */
  async runBrief(
    brief: CallBrief,
    onUpdate?: (r: GetCallRunResult) => void,
  ): Promise<CallResult> {
    const planInput = CalleClient.briefToUserInput(brief);
    const plan = await this.planCall(planInput);
    this.log("plan:done", { plan_id: plan.plan_id ?? null, ready_to_run: plan.ready_to_run ?? null });

    if (!plan.ready_to_run || !plan.plan_id || !plan.confirm_token) {
      throw new Error(
        `plan_call not ready to run. clarifying_questions=${JSON.stringify(plan.clarifying_questions ?? [])}`,
      );
    }

    const run = await this.runCall({ plan_id: plan.plan_id, confirm_token: plan.confirm_token });
    this.log("run:started", { run_id: run.run_id ?? null, status: run.status ?? null });
    if (!run.run_id) {
      throw new Error("run_call returned no run_id; cannot poll. Do NOT retry automatically — escalate.");
    }

    const terminal = await this.pollRun(run.run_id, onUpdate);
    return this.normalize(terminal);
  }

  /** Turn a terminal get_call_run response into Speakeasy's CallResult. */
  normalize(r: GetCallRunResult): CallResult {
    const rawStatus = (r.status ?? "").toString();
    const structured = (r.details && typeof r.details === "object" ? r.details : {}) as Record<string, unknown>;
    const outcome = r.summary?.trim() || `Call ended with status ${rawStatus || "UNKNOWN"}.`;
    const confirmationNumbers = collectConfirmationNumbers(structured, outcome);
    const appointmentText = typeof structured.appointment === "string" ? structured.appointment : undefined;
    const provider = typeof structured.provider === "string" ? structured.provider : undefined;
    return {
      status: normalizeStatus(rawStatus),
      rawStatus,
      outcome,
      structured,
      confirmationNumbers,
      transcript: r.transcript ?? "",
      appointmentText,
      provider,
    };
  }
}

/** Pull confirmation numbers from structured fields, else from the summary text. */
function collectConfirmationNumbers(structured: Record<string, unknown>, outcome: string): string[] {
  const found = new Set<string>();
  for (const [key, value] of Object.entries(structured)) {
    if (/confirm|reference|booking|ticket/i.test(key) && (typeof value === "string" || typeof value === "number")) {
      found.add(String(value));
    }
  }
  if (found.size === 0) {
    const m = outcome.match(/(?:confirmation|reference|booking)\s*(?:number|no\.?|#)?\s*[:#]?\s*([A-Z0-9-]{3,})/i);
    if (m) found.add(m[1]);
  }
  return [...found];
}

// ── Factory ──────────────────────────────────────────────────────────────────
export type CreateClientOptions = {
  mode?: "fake" | "real";
  oauth?: OAuthConfig;
  poll?: Partial<PollOptions>;
  log?: Logger;
};

export function createCalleClient(opts: CreateClientOptions = {}): CalleClient {
  const mode = opts.mode ?? (process.env.CALLE_MODE === "real" ? "real" : "fake");
  if (mode === "real") {
    const oauth: OAuthConfig = opts.oauth ?? {
      serverUrl: process.env.CALLE_MCP_URL || "https://seleven-mcp-sg.airudder.com/mcp/openagent_oauth",
      redirectUri: process.env.CALLE_OAUTH_REDIRECT_URI || "http://127.0.0.1:8090/callback",
      scope: process.env.CALLE_OAUTH_SCOPE || "openid email profile",
      tokenPath: process.env.CALLE_TOKEN_PATH || ".speakeasy/calle-oauth.json",
    };
    return new CalleClient({ transport: new McpCalleTransport(oauth, opts.log), poll: opts.poll, log: opts.log });
  }
  // Fake mode: fast polling so dry-runs finish instantly.
  return new CalleClient({
    transport: new FakeCalleTransport(opts.log),
    poll: { firstDelayMs: 100, intervalMs: 100, maxWaitMs: 10_000, ...opts.poll },
    log: opts.log,
  });
}
