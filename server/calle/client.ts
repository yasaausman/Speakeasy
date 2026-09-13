/**
 * The ONE module the rest of KindlyCall uses to talk to CALL-E.
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
import { assertNoCardData, safeCallLogArgs } from "../privacy.js";
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

/** Thrown when a call was DEFINITELY not placed (e.g. a 4xx from the REST API:
 *  bad key, insufficient balance, validation error). Unlike an ambiguous network
 *  failure, retrying is safe and the error should surface to the user verbatim
 *  instead of becoming a "call may have started" pending state. */
export class CallNotPlacedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CallNotPlacedError";
  }
}

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
    this.log("tools/call:req", { tool: name, args: safeCallLogArgs(args) });
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
  private plans = new Map<string, { number: string; userInput: string }>();
  private runs = new Map<string, { number: string; userInput: string; count: number }>();
  private seq = 0;
  constructor(private readonly log: Logger = defaultLogger) {}

  async planCall(input: PlanCallInput): Promise<PlanCallResult> {
    const planId = `fake-plan-${++this.seq}`;
    this.plans.set(planId, { number: input.to_phones?.[0] ?? "unknown", userInput: input.user_input ?? "" });
    this.log("fake:plan_call", safeCallLogArgs(input as unknown as Record<string, unknown>));
    return { plan_id: planId, confirm_token: "fake-confirm-token", ready_to_run: true, raw: { plan_id: planId, ready_to_run: true } };
  }

  async runCall(input: RunCallInput): Promise<RunCallResult> {
    const plan = this.plans.get(input.plan_id) ?? { number: "unknown", userInput: "" };
    const runId = `fake-run-${++this.seq}`;
    this.runs.set(runId, { number: plan.number, userInput: plan.userInput, count: 0 });
    this.log("fake:run_call", { plan_id: input.plan_id });
    return { run_id: runId, status: "QUEUED", raw: { run_id: runId, status: "QUEUED" } };
  }

  async getCallRun(input: GetCallRunInput): Promise<GetCallRunResult> {
    const st = this.runs.get(input.run_id) ?? { number: "unknown", userInput: "", count: 0 };
    st.count += 1;
    this.runs.set(input.run_id, st);
    const s = scenarioFor(st.number);

    // Discover intent (speculative two-call booking): report available times, book nothing.
    const isDiscover = /do not book|available for:|what appointment times/i.test(st.userInput);
    if (isDiscover) {
      const offered = [`${s.day} at ${s.time}`, "Wednesday at 3:30pm", "Saturday at 11:00am"];
      const script = [
        "Call is ringing…",
        "Call connected.",
        "Bot: Hi, I'm an AI assistant. What appointment times do you have available?",
        `Rep: We have ${offered.join(", ")}.`,
        "Bot: Thank you — I'll check with them and call back to book.",
      ];
      const revealed = Math.min(st.count * 2, script.length);
      const done = st.count >= 3;
      return {
        run_id: input.run_id,
        status: done ? "COMPLETED" : "IN_PROGRESS",
        summary: done
          ? `${s.provider} has these times available: ${offered.join(", ")}.`
          : "Asking about availability…",
        transcript: done ? script.join("\n") : "",
        activity: script.slice(0, revealed).map((message) => ({ kind: "callee_realtime", message })),
        details: done ? { provider: s.provider, available_times: offered, task_completed: true } : {},
        next_step: done ? null : { action: "poll" },
        raw: { run_id: input.run_id, status: done ? "COMPLETED" : "IN_PROGRESS" },
      };
    }

    // Demo of gap-surfacing: if the brief didn't include an insurance fact, the
    // office can't book yet and asks for it. Providing insurance completes it.
    const hasInsurance = /insurance:/i.test(st.userInput);
    const script = fakeScript(s, hasInsurance);
    const revealed = Math.min(st.count * 2, script.length);
    const done = st.count >= 4;
    const status = done ? "COMPLETED" : "IN_PROGRESS";
    this.log("fake:get_call_run", { run_id: input.run_id, status });

    const doneDetails: Record<string, unknown> = hasInsurance
      ? {
          appointment: `${s.day} ${s.time}`, provider: s.provider, accepts_insurance: true,
          confirmation: s.conf, soonest_rank: s.soonestRank, task_completed: true,
          confidence: { score: 0.9, label: "high" },
          evidence: [
            "A live receptionist answered and confirmed availability.",
            `They offered ${s.day} at ${s.time} with ${s.provider}.`,
            `The booking was confirmed with number ${s.conf}.`,
          ],
        }
      : {
          provider: s.provider, task_completed: false, soonest_rank: s.soonestRank,
          confidence: { score: 0.5, label: "medium" },
          gaps: ["insurance"],
          evidence: ["A receptionist answered but needs your insurance before booking."],
        };

    return {
      run_id: input.run_id,
      status,
      summary: done
        ? hasInsurance
          ? `Booked ${s.day} at ${s.time} with ${s.provider}. They accept Medicaid. Confirmation number ${s.conf}.`
          : `${s.provider} can see you ${s.day} at ${s.time}, but they need your insurance before booking. Add it and try again.`
        : "Speaking with reception…",
      transcript: done ? script.join("\n") : "",
      activity: script.slice(0, revealed).map((message) => ({ kind: "callee_realtime", message })),
      details: done ? doneDetails : {},
      next_step: done ? null : { action: "poll" },
      raw: { run_id: input.run_id, status },
    };
  }

  async close(): Promise<void> {
    /* nothing to close */
  }
}

function fakeScript(s: FakeScenario, hasInsurance: boolean): string[] {
  if (!hasInsurance) {
    return [
      "Call is ringing…",
      "Call connected.",
      "Bot: Hi, I'm an AI assistant calling to book an appointment.",
      "Rep: Sure — what insurance does the patient have?",
      "Bot: I don't have that on file yet.",
      "Rep: We'll need it before we can book. Please call back with it.",
    ];
  }
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

// ── REST transport (CALL-E Developer API, api-key auth) ──────────────────────
// Uses the REST API at https://api.heycall-e.com instead of the OAuth MCP
// endpoint. Docs: https://docs.heycall-e.com/api-reference/calls
//   POST /v1/calls          → create (queues) a call; returns { id, status }
//   GET  /v1/calls/{id}      → poll the CallTask (status, summary, recipients…)
// There is no plan/confirm step in REST, so planCall is a local no-op that
// stashes the composed input; the user's approval is already enforced upstream
// by the orchestrator's confirm gate. runCall is what actually places the call.
type FetchLike = (url: string, init?: {
  method?: string; headers?: Record<string, string>; body?: string;
}) => Promise<{ ok: boolean; status: number; json: () => Promise<unknown>; text: () => Promise<string> }>;

/** One turn of the recipient conversation (docs: CallTaskRecipient). */
type TranscriptTurn = { speaker?: unknown; text?: unknown; offset_seconds?: unknown };
/** The CallTask object returned by GET /v1/calls/{id}. */
type CallTaskResponse = {
  id?: string;
  status?: string; // queued | in_progress | completed | failed | canceled
  summary?: string;
  task_completed?: boolean;
  completion_confidence?: { score?: unknown; label?: unknown };
  evidence?: unknown;
  structured_result?: Record<string, unknown>;
  recipients?: Array<{
    summary?: string;
    transcript_turns?: TranscriptTurn[];
    structured_result?: Record<string, unknown>;
  }>;
};

const truncate = (s: string, n = 300): string => (s.length > n ? `${s.slice(0, n)}…` : s);

/** Turn a REST error body into a legible sentence. CALL-E returns
 *  { error: { code, message, details: { questions: [...] } } } when it rejects a
 *  create-call (e.g. missing date/name, no balance). Prefer that human message,
 *  else the clarifying questions, else the truncated raw text — never the raw
 *  JSON envelope, which is unreadable once translated for the user. */
function describeCreateError(status: number, body: string): string {
  let detail = truncate(body);
  try {
    const j = JSON.parse(body) as { error?: { message?: unknown; details?: { questions?: unknown } } };
    const message = typeof j.error?.message === "string" ? j.error.message.trim() : "";
    const questions = Array.isArray(j.error?.details?.questions)
      ? (j.error!.details!.questions as unknown[]).filter((q): q is string => typeof q === "string")
      : [];
    if (message) detail = message;
    else if (questions.length) detail = questions.join(" ");
  } catch {
    // Not JSON — keep the truncated raw text.
  }
  return `CALL-E could not start the call (HTTP ${status}): ${detail}`;
}

/** Map a REST CallTask onto the transport-agnostic GetCallRunResult that
 *  CalleClient.normalize() already knows how to read. */
function mapCallTask(task: CallTaskResponse, runId: string): GetCallRunResult {
  const rec = Array.isArray(task.recipients) ? task.recipients[0] : undefined;
  const turns = Array.isArray(rec?.transcript_turns) ? rec!.transcript_turns : [];
  const lines = turns
    .map((t) => (typeof t.speaker === "string" && typeof t.text === "string" ? `${t.speaker}: ${t.text}` : ""))
    .filter(Boolean);
  // Shape a `details` object with the field names normalize() expects.
  const details: Record<string, unknown> = {
    ...(task.structured_result ?? {}),
    ...(rec?.structured_result ?? {}),
    task_completed: task.task_completed,
    confidence: task.completion_confidence,
    evidence: task.evidence,
  };
  return {
    run_id: task.id ?? runId,
    status: (task.status ?? "").toUpperCase(), // isTerminalStatus/normalizeStatus are case-insensitive
    summary: str(task.summary) ?? str(rec?.summary),
    details,
    transcript: lines.join("\n"),
    // Feed the same turns as the live activity feed so in-progress polls still
    // render a growing transcript.
    activity: lines.map((message) => ({ message })),
    raw: task as Record<string, unknown>,
  };
}

export class RestCalleTransport implements CalleTransport {
  private plans = new Map<string, PlanCallInput>();
  private seq = 0;
  constructor(
    private readonly apiKey: string,
    private readonly baseUrl: string = process.env.CALLE_API_URL || "https://api.heycall-e.com",
    private readonly log: Logger = defaultLogger,
    private readonly fetchImpl: FetchLike = fetch as unknown as FetchLike,
  ) {}

  private headers(): Record<string, string> {
    return { Authorization: `Bearer ${this.apiKey}`, "Content-Type": "application/json" };
  }

  // No network, no call placed — just record the composed input for runCall.
  async planCall(input: PlanCallInput): Promise<PlanCallResult> {
    const planId = `rest-plan-${++this.seq}`;
    this.plans.set(planId, input);
    this.log("rest:plan_call", safeCallLogArgs(input as unknown as Record<string, unknown>));
    return { plan_id: planId, confirm_token: "rest", ready_to_run: true, raw: { plan_id: planId } };
  }

  async runCall(input: RunCallInput): Promise<RunCallResult> {
    const planned = this.plans.get(input.plan_id);
    if (!planned) throw new CallNotPlacedError("No planned REST call for that id.");
    const lang = (planned.language ?? "").trim();
    const locale = /^[a-z]{2}(-[A-Za-z]{2})?$/.test(lang) ? lang : "en-US";
    const recipients = (planned.to_phones ?? []).filter(Boolean);
    const body = JSON.stringify({
      task: planned.user_input,
      ...(recipients.length ? { recipients: [{ phones: recipients, locale, region: planned.region ?? "US" }] } : {}),
    });
    let res;
    try {
      res = await this.fetchImpl(`${this.baseUrl}/v1/calls`, { method: "POST", headers: this.headers(), body });
    } catch (err) {
      // Network-level failure: the request may or may not have landed — ambiguous.
      throw new Error(`create-call request failed: ${err instanceof Error ? err.message : String(err)}`);
    }
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      const msg = describeCreateError(res.status, text);
      this.log("rest:run_call:error", { status: res.status });
      // 4xx = the request was rejected outright (bad key, no balance, invalid
      // input): definitely no call placed → surface it. 5xx = ambiguous.
      if (res.status >= 400 && res.status < 500) throw new CallNotPlacedError(msg);
      throw new Error(msg);
    }
    const j = (await res.json().catch(() => ({}))) as { id?: string; status?: string };
    this.log("rest:run_call", { run_id: j.id ?? null, status: j.status ?? null });
    return { run_id: str(j.id), status: (j.status ?? "queued").toUpperCase(), raw: j as Record<string, unknown> };
  }

  async getCallRun(input: GetCallRunInput): Promise<GetCallRunResult> {
    const res = await this.fetchImpl(`${this.baseUrl}/v1/calls/${encodeURIComponent(input.run_id)}`, {
      headers: this.headers(),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`CALL-E get-call failed (HTTP ${res.status})${text ? `: ${truncate(text)}` : ""}`);
    }
    const task = (await res.json().catch(() => ({}))) as CallTaskResponse;
    return mapCallTask(task, input.run_id);
  }

  async close(): Promise<void> {
    /* stateless HTTP — nothing to close */
  }
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
   * Compose KindlyCall's internal CallBrief into a single natural-language
   * `user_input` for plan_call, plus structured hints. The disclosure line is
   * always first and non-optional (golden rule #6).
   */
  static briefToUserInput(brief: CallBrief): PlanCallInput {
    assertNoCardData({ objective: brief.objective, facts: brief.facts, constraints: brief.constraints, fallback: brief.fallback });
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
    lines.push("Never request, provide, or read payment card numbers, security codes, or bank credentials.");
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

    let run: RunCallResult;
    try {
      run = await this.runCall({ plan_id: plan.plan_id, confirm_token: plan.confirm_token });
    } catch (err) {
      // A definite no-call rejection (4xx: bad key, no balance, invalid request)
      // should surface to the user — no call was placed, so retrying is safe.
      if (err instanceof CallNotPlacedError) throw err;
      // Otherwise the request may have reached CALL-E. Retrying could place a
      // second call, so keep the outcome UNKNOWN rather than redialing.
      return this.normalize({ status: "UNKNOWN", raw: {} });
    }
    this.log("run:started", { run_id: run.run_id ?? null, status: run.status ?? null });
    if (!run.run_id) {
      return this.normalize({ status: "UNKNOWN", raw: {} });
    }

    return this.resumeRun(run.run_id, onUpdate);
  }

  /** Read-only: reconnect to an existing call without plan_call or run_call. */
  async resumeRun(runId: string, onUpdate?: (r: GetCallRunResult) => void): Promise<CallResult> {
    let terminal: GetCallRunResult;
    try {
      terminal = await this.pollRun(runId, onUpdate);
    } catch {
      terminal = { run_id: runId, status: "UNKNOWN", raw: {} };
    }
    terminal.run_id ??= runId;
    this.log("run:terminal-raw", {
      status: terminal.status ?? null,
      hasTranscript: !!terminal.transcript,
      activityCount: Array.isArray(terminal.activity) ? terminal.activity.length : 0,
      detailKeys:
        terminal.details && typeof terminal.details === "object" ? Object.keys(terminal.details) : [],
    });
    const result = this.normalize(terminal);
    this.log("run:result", {
      status: result.status,
      rawStatus: result.rawStatus,
      taskCompleted: result.taskCompleted ?? null,
      transcriptChars: result.transcript.length,
    });
    return result;
  }

  /** Turn a terminal get_call_run response into KindlyCall's CallResult. */
  normalize(r: GetCallRunResult): CallResult {
    const rawStatus = (r.status ?? "").toString();
    if (!isTerminalStatus(rawStatus)) {
      return {
        runId: r.run_id, status: "pending", rawStatus,
        outcome: r.run_id
          ? "The call outcome is not confirmed yet. Check the existing call's status before trying again."
          : "The call may have started, but its status could not be recovered. Check CALL-E call history before making another call.",
        structured: {}, confirmationNumbers: [], transcript: activityToTranscript(r.activity),
      };
    }
    const structured = (r.details && typeof r.details === "object" ? r.details : {}) as Record<string, unknown>;
    const outcome = r.summary?.trim() || `Call ended with status ${rawStatus || "UNKNOWN"}.`;
    const confirmationNumbers = collectConfirmationNumbers(structured, outcome);
    const appointmentText = typeof structured.appointment === "string" ? structured.appointment : undefined;
    const provider = typeof structured.provider === "string" ? structured.provider : undefined;
    // CALL-E nests these under `outcome`; the fake puts them at the top level.
    const outcomeObj = (structured.outcome && typeof structured.outcome === "object" ? structured.outcome : {}) as Record<string, unknown>;
    const conf = (structured.confidence ?? outcomeObj.completion_confidence) as { score?: unknown; label?: unknown } | undefined;
    const confidence =
      conf && typeof conf.score === "number" && typeof conf.label === "string"
        ? { score: conf.score, label: conf.label }
        : undefined;
    const evidence = strArrayOf(structured.evidence ?? outcomeObj.evidence);
    const gaps = strArrayOf(structured.gaps ?? outcomeObj.gaps);
    const taskCompleted =
      typeof structured.task_completed === "boolean"
        ? structured.task_completed
        : typeof outcomeObj.task_completed === "boolean"
          ? (outcomeObj.task_completed as boolean)
          : undefined;
    return {
      runId: r.run_id,
      status: normalizeStatus(rawStatus),
      rawStatus,
      outcome,
      structured,
      confirmationNumbers,
      // Real runs often don't return a transcript field — reconstruct it from the
      // live activity feed so the user still sees the conversation.
      transcript: (r.transcript ?? "").trim() || activityToTranscript(r.activity),
      appointmentText,
      provider,
      confidence,
      evidence,
      gaps,
      taskCompleted,
    };
  }
}

/** Join a CALL-E activity feed into a readable transcript (fallback when the
 *  terminal result has no transcript field). */
function activityToTranscript(activity: unknown): string {
  if (!Array.isArray(activity)) return "";
  return activity
    .map((it) =>
      it && typeof it === "object" && typeof (it as { message?: unknown }).message === "string"
        ? (it as { message: string }).message
        : "",
    )
    .filter(Boolean)
    .join("\n");
}

function strArrayOf(v: unknown): string[] | undefined {
  if (!Array.isArray(v)) return undefined;
  const out = v.filter((x): x is string => typeof x === "string");
  return out.length ? out : undefined;
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
    // Require at least one digit, so we don't capture the literal word
    // "number"/"reference" from a sentence like "capture any confirmation number".
    if (m && /\d/.test(m[1])) found.add(m[1]);
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
    // Two real transports: REST (Developer API key) or MCP (OAuth). REST is
    // opt-in via CALLE_TRANSPORT=rest and needs CALLE_API_KEY.
    if ((process.env.CALLE_TRANSPORT ?? "").trim().toLowerCase() === "rest") {
      const apiKey = (process.env.CALLE_API_KEY ?? "").trim();
      if (!apiKey) throw new Error("CALLE_TRANSPORT=rest requires CALLE_API_KEY (your CALL-E Developer API key).");
      const baseUrl = process.env.CALLE_API_URL || "https://api.heycall-e.com";
      return new CalleClient({ transport: new RestCalleTransport(apiKey, baseUrl, opts.log), poll: opts.poll, log: opts.log });
    }
    const oauth: OAuthConfig = opts.oauth ?? {
      serverUrl: process.env.CALLE_MCP_URL || "https://seleven-mcp-sg.airudder.com/mcp/openagent_oauth",
      redirectUri: process.env.CALLE_OAUTH_REDIRECT_URI || "http://127.0.0.1:8090/callback",
      scope: process.env.CALLE_OAUTH_SCOPE || "openid email profile",
      tokenPath: process.env.CALLE_TOKEN_PATH || ".kindlycall/calle-oauth.json",
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
