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
    return {
      run_id: str(s.run_id),
      status: str(s.status),
      activity: s.activity,
      summary: str(s.summary),
      details: s.details,
      transcript: str(s.transcript),
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
// to exercise the full plan → run → poll → terminal workflow.
export class FakeCalleTransport implements CalleTransport {
  private pollCounts = new Map<string, number>();
  constructor(private readonly log: Logger = defaultLogger) {}

  async planCall(input: PlanCallInput): Promise<PlanCallResult> {
    this.log("fake:plan_call", { goal: input.goal ?? null, to_phones: input.to_phones ?? null });
    return {
      plan_id: "fake-plan-1",
      confirm_token: "fake-confirm-token",
      ready_to_run: true,
      raw: { plan_id: "fake-plan-1", ready_to_run: true },
    };
  }

  async runCall(input: RunCallInput): Promise<RunCallResult> {
    this.log("fake:run_call", { plan_id: input.plan_id });
    return { run_id: "fake-run-1", status: "QUEUED", raw: { run_id: "fake-run-1", status: "QUEUED" } };
  }

  async getCallRun(input: GetCallRunInput): Promise<GetCallRunResult> {
    const count = (this.pollCounts.get(input.run_id) ?? 0) + 1;
    this.pollCounts.set(input.run_id, count);
    const done = count >= 2;
    const status = done ? "COMPLETED" : "IN_PROGRESS";
    this.log("fake:get_call_run", { run_id: input.run_id, status });
    return {
      run_id: input.run_id,
      status,
      summary: done
        ? "Booked a dentist appointment for Tuesday at 9:40am with Dr. Lee. They accept Medicaid. Confirmation number 4471."
        : "Dialing and navigating the phone menu…",
      transcript: done ? FAKE_TRANSCRIPT : "",
      details: done
        ? { appointment: "Tue 9:40am", provider: "Dr. Lee", accepts_insurance: true, confirmation: "4471" }
        : {},
      next_step: done ? null : { action: "poll" },
      raw: { run_id: input.run_id, status },
    };
  }

  async close(): Promise<void> {
    /* nothing to close */
  }
}

const FAKE_TRANSCRIPT = [
  "AGENT: Hi, I'm an AI assistant calling on behalf of a patient to book an appointment.",
  "REP: Sure — what insurance do you have?",
  "AGENT: The patient has Medicaid.",
  "REP: Great, we accept that. We have Tuesday at 9:40am with Dr. Lee.",
  "AGENT: That works. Please book it.",
  "REP: Done. Confirmation number is 4471.",
].join("\n");

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
    return {
      status: normalizeStatus(rawStatus),
      rawStatus,
      outcome,
      structured,
      confirmationNumbers,
      transcript: r.transcript ?? "",
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
