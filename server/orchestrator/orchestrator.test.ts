/**
 * Deterministic end-to-end tests for the orchestration state machine.
 *
 * Zero infrastructure, zero keys, zero real calls: the CALL-E layer runs on the
 * FakeCalleTransport and the language layer on offline passthrough/heuristic
 * providers, so a skeptical judge can reproduce every flow with one command:
 *
 *     npm test
 *
 * Covers the four headline flows: booking, gap → provide-and-complete,
 * multi-call comparison, and speculative discover → slot options.
 */
import assert from "node:assert/strict";
import { test } from "node:test";

import { CalleClient, FakeCalleTransport } from "../calle/client.js";
import { MockTranslator } from "../language/translate.js";
import { HeuristicRanker } from "../language/rank.js";
import { NaiveSlotExtractor } from "../language/slots.js";
import { Orchestrator, type GoalOptions } from "./orchestrator.js";
import type { Session } from "./session.js";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const silent = () => {};

/** An orchestrator wired entirely to offline, deterministic doubles. */
function makeOrchestrator(): Orchestrator {
  const calle = new CalleClient({
    transport: new FakeCalleTransport(silent),
    poll: { firstDelayMs: 5, intervalMs: 5, maxWaitMs: 4000 },
    log: silent,
  });
  return new Orchestrator({
    calle,
    translator: new MockTranslator(),      // passthrough (no network)
    ranker: new HeuristicRanker(),         // completed-first (no network)
    slotExtractor: new NaiveSlotExtractor(), // regex slots (no network)
  });
}

async function runFlow(orch: Orchestrator, text: string, opts: GoalOptions): Promise<Session> {
  const session = orch.createSession("en");
  await orch.submitGoal(session.id, text, "en", opts);
  orch.confirmAndCall(session.id);
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    const s = orch.getSession(session.id)!;
    if (s.phase === "done" || s.phase === "failed") return s;
    await sleep(20);
  }
  throw new Error("flow did not reach a terminal state in time");
}

test("single booking completes with a confirmation number when insurance is known", async () => {
  const orch = makeOrchestrator();
  const s = await runFlow(orch, "book a dentist appointment", {
    numbers: ["+13120001111"],
    facts: { insurance: "Medicaid" },
  });
  assert.equal(s.phase, "done");
  assert.equal(s.result?.status, "completed");
  assert.ok((s.result?.confirmationNumbers.length ?? 0) > 0, "should capture a confirmation number");
  assert.ok(s.result?.appointmentText, "should capture the appointment time");
});

test("gap is surfaced when insurance is missing, then completes once provided", async () => {
  const orch = makeOrchestrator();
  const gap = await runFlow(orch, "book a dentist appointment", { numbers: ["+13120001111"] });
  assert.equal(gap.phase, "done");
  assert.ok(gap.result?.gaps?.includes("insurance"), "should surface the insurance gap");
  assert.equal(gap.result?.confirmationNumbers.length, 0, "no booking without insurance");

  const booked = await runFlow(orch, "book a dentist appointment", {
    numbers: ["+13120001111"],
    facts: { insurance: "Medicaid" },
  });
  assert.ok((booked.result?.confirmationNumbers.length ?? 0) > 0, "completes once insurance is provided");
});

test("multi-call comparison returns a ranked list with a winner and varied results", async () => {
  const orch = makeOrchestrator();
  const s = await runFlow(orch, "which of you can see me soonest", {
    numbers: ["+13120001111", "+13120002222", "+13120003333"],
    facts: { insurance: "Medicaid" },
  });
  assert.equal(s.phase, "done");
  assert.equal(s.mode, "multi");
  assert.equal(s.ranked?.length, 3, "one result per place");
  assert.ok((s.winnerReason?.length ?? 0) > 0, "names a best option");
  const distinct = new Set(s.ranked!.map((r) => r.result.outcome));
  assert.ok(distinct.size >= 2, "results genuinely vary by place");
});

test("speculative discover returns available slots and books nothing", async () => {
  const orch = makeOrchestrator();
  const s = await runFlow(orch, "a haircut this week", {
    numbers: ["+13120009999"],
    intent: "discover",
  });
  assert.equal(s.phase, "done");
  assert.equal(s.intent, "discover");
  assert.ok((s.options?.length ?? 0) >= 1, "returns at least one available slot");
  assert.equal(s.result?.confirmationNumbers.length ?? 0, 0, "discovery books nothing");
});

test("front-loaded preferences flow into the brief as constraints", async () => {
  const orch = makeOrchestrator();
  const session = orch.createSession("en");
  await orch.submitGoal(session.id, "book a haircut", "en", {
    numbers: ["+13120001111"],
    preferences: { preferredTimes: "Saturday 2-4pm", fallbackTimes: "Sunday morning", avoid: "before 10am" },
  });
  const brief = orch.getSession(session.id)?.brief;
  assert.ok(brief, "brief is built at submit time");
  assert.ok(brief!.constraints.some((c) => /Saturday 2-4pm/.test(c)), "preferred time is a constraint");
  assert.ok(/Sunday morning/.test(brief!.fallback), "fallback times drive the brief fallback");
});
