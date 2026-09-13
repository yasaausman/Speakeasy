import assert from "node:assert/strict";
import { test } from "node:test";
import { CalleClient, RestCalleTransport, CallNotPlacedError } from "./client.js";
import type { CallBrief } from "./types.js";

const brief: CallBrief = {
  objective: "Book a haircut on Friday afternoon",
  targetNumber: "+13125550123",
  targetRegion: "US",
  language: "English",
  constraints: [],
  facts: {},
  successCondition: "Booking confirmed",
  fallback: "Report missing information",
  agentDisclosure: "I am an AI assistant.",
};

type Resp = { ok: boolean; status: number; body: unknown };
/** A minimal fetch double that records requests and returns programmed responses. */
function stubFetch(handler: (url: string, init: { method?: string; headers?: Record<string, string>; body?: string }) => Resp) {
  const calls: { url: string; init: { method?: string; headers?: Record<string, string>; body?: string } }[] = [];
  const fn = async (url: string, init: { method?: string; headers?: Record<string, string>; body?: string } = {}) => {
    calls.push({ url, init });
    const r = handler(url, init);
    return {
      ok: r.ok,
      status: r.status,
      json: async () => r.body,
      text: async () => (typeof r.body === "string" ? r.body : JSON.stringify(r.body)),
    };
  };
  return { fn, calls };
}

test("REST transport places a call, polls to completion, and normalizes the CallTask", async () => {
  let gets = 0;
  const { fn, calls } = stubFetch((url, init) => {
    if (init.method === "POST" && url.endsWith("/v1/calls")) {
      return { ok: true, status: 201, body: { id: "call_1", status: "queued" } };
    }
    // GET /v1/calls/call_1 — in_progress first, then completed.
    gets++;
    return gets >= 2
      ? {
          ok: true,
          status: 200,
          body: {
            id: "call_1",
            status: "completed",
            summary: "Booked Friday 3:00pm. Confirmation number 4471.",
            task_completed: true,
            completion_confidence: { score: 0.9, label: "high" },
            evidence: ["A receptionist confirmed the slot."],
            recipients: [
              {
                summary: "Booked",
                transcript_turns: [
                  { speaker: "Bot", text: "Hi, I'm an AI assistant." },
                  { speaker: "Rep", text: "Booked for Friday at 3." },
                ],
              },
            ],
          },
        }
      : { ok: true, status: 200, body: { id: "call_1", status: "in_progress" } };
  });

  const transport = new RestCalleTransport("test-key", "https://api.test", () => {}, fn);
  const client = new CalleClient({ transport, log: () => {}, poll: { firstDelayMs: 1, intervalMs: 1, maxWaitMs: 500 } });
  const result = await client.runBrief(brief);

  // The POST carried the composed task + recipient in E.164, with bearer auth.
  const post = calls.find((c) => c.init.method === "POST")!;
  assert.equal(post.url, "https://api.test/v1/calls");
  assert.equal(post.init.headers?.Authorization, "Bearer test-key");
  const sent = JSON.parse(post.init.body!);
  assert.ok(sent.task.includes("Book a haircut"), "task should carry the objective");
  assert.deepEqual(sent.recipients[0].phones, ["+13125550123"]);

  // The CallTask mapped cleanly onto the normalized result.
  assert.equal(result.status, "completed");
  assert.equal(result.taskCompleted, true);
  assert.deepEqual(result.confidence, { score: 0.9, label: "high" });
  assert.deepEqual(result.evidence, ["A receptionist confirmed the slot."]);
  assert.ok(result.transcript.includes("Rep: Booked for Friday at 3."));
  assert.deepEqual(result.confirmationNumbers, ["4471"]);
});

test("REST 4xx (e.g. insufficient balance) surfaces as CallNotPlacedError, not a pending call", async () => {
  const { fn } = stubFetch((_url, init) =>
    init.method === "POST"
      ? { ok: false, status: 402, body: "Insufficient CALL-E balance. Top up and retry." }
      : { ok: true, status: 200, body: {} },
  );
  const transport = new RestCalleTransport("bad-key", "https://api.test", () => {}, fn);
  const client = new CalleClient({ transport, log: () => {}, poll: { firstDelayMs: 1, intervalMs: 1, maxWaitMs: 50 } });

  await assert.rejects(
    () => client.runBrief(brief),
    (err: unknown) => {
      assert.ok(err instanceof CallNotPlacedError, "a 4xx must not become a pending/unknown call");
      assert.match((err as Error).message, /Insufficient CALL-E balance/);
      return true;
    },
  );
});

test("REST 422 clarifying-questions body surfaces CALL-E's message, not the raw JSON envelope", async () => {
  const { fn } = stubFetch((_url, init) =>
    init.method === "POST"
      ? {
          ok: false,
          status: 422,
          body: {
            error: {
              code: "call_not_ready",
              message: "Call task creation rejected: What date should the appointment be for?",
              details: { questions: ["What date should the appointment be for?", "What name?"] },
            },
          },
        }
      : { ok: true, status: 200, body: {} },
  );
  const transport = new RestCalleTransport("test-key", "https://api.test", () => {}, fn);
  const client = new CalleClient({ transport, log: () => {}, poll: { firstDelayMs: 1, intervalMs: 1, maxWaitMs: 50 } });

  await assert.rejects(
    () => client.runBrief(brief),
    (err: unknown) => {
      assert.ok(err instanceof CallNotPlacedError);
      const m = (err as Error).message;
      assert.match(m, /What date should the appointment be for\?/);
      assert.doesNotMatch(m, /call_not_ready|"error"|\{/); // no raw JSON envelope leaks through
      return true;
    },
  );
});

test("REST in-progress CallTask normalizes to a pending outcome (no false completion)", async () => {
  const { fn } = stubFetch((_url, init) =>
    init.method === "POST"
      ? { ok: true, status: 201, body: { id: "call_2", status: "queued" } }
      : { ok: true, status: 200, body: { id: "call_2", status: "in_progress" } },
  );
  const transport = new RestCalleTransport("test-key", "https://api.test", () => {}, fn);
  // maxWaitMs short so polling gives up while still in_progress.
  const client = new CalleClient({ transport, log: () => {}, poll: { firstDelayMs: 1, intervalMs: 1, maxWaitMs: 8 } });
  const result = await client.runBrief(brief);
  assert.equal(result.status, "pending");
  assert.equal(result.runId, "call_2");
});
