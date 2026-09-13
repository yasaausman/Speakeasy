import assert from "node:assert/strict";
import { test } from "node:test";
import { CalleClient, FakeCalleTransport, type CalleTransport } from "./client.js";
import { safeCallLogArgs, assertNoCardData } from "../privacy.js";
import { Orchestrator } from "../orchestrator/orchestrator.js";
import { MockTranslator } from "../language/translate.js";
import { HeuristicRanker } from "../language/rank.js";
import { NaiveSlotExtractor } from "../language/slots.js";
import { MockBusinessSearch } from "../search/business.js";
import { HeuristicIntentClassifier } from "../language/intent.js";
import type { PlanCallInput } from "./types.js";

const brief = { objective: "Book a haircut", targetNumber: "+13125550123", targetRegion: "US", language: "English",
  constraints: [], facts: {}, successCondition: "Booking confirmed", fallback: "Report missing information", agentDisclosure: "I am an AI assistant." };
function setup(transport: CalleTransport) {
  const client = new CalleClient({ transport, log: () => {}, poll: { firstDelayMs: 1, intervalMs: 2, maxWaitMs: 12 } });
  const translator = new MockTranslator();
  const orch = new Orchestrator({ calle: client, translator, ranker: new HeuristicRanker(), slotExtractor: new NaiveSlotExtractor(),
    search: new MockBusinessSearch(), classifier: new HeuristicIntentClassifier() });
  return { client, orch, translator };
}
function delayedTransport() {
  let calls = 0, done = false;
  const transport: CalleTransport = {
    async planCall() { return { plan_id: "plan", confirm_token: "secret", ready_to_run: true, raw: {} }; },
    async runCall() { calls++; return { run_id: "run-original", raw: {} }; },
    async getCallRun() { return { run_id: "run-original", status: done ? "COMPLETED" : "IN_PROGRESS",
      summary: done ? "Appointment confirmed" : "Speaking to reception", details: { task_completed: done }, raw: {} }; },
    async close() {},
  };
  return { transport, finish: () => { done = true; }, calls: () => calls };
}
async function settle(orch: Orchestrator, id: string) {
  for (let i = 0; i < 200; i++) {
    const s = orch.getSession(id)!;
    if (["done", "pending", "failed"].includes(s.phase)) return s;
    await new Promise(r => setTimeout(r, 5));
  }
  throw new Error("Session did not settle");
}

test("monitoring timeout preserves an unknown outcome and resuming never redials", async () => {
  const t = delayedTransport(); const { client } = setup(t.transport);
  const pending = await client.runBrief(brief);
  assert.equal(pending.status, "pending");
  assert.equal(pending.runId, "run-original");
  assert.equal(pending.taskCompleted, undefined);
  assert.equal(pending.confirmationNumbers.length, 0);
  t.finish();
  const recovered = await client.resumeRun(pending.runId!);
  assert.equal(recovered.taskCompleted, true);
  assert.equal(t.calls(), 1);
});

test("uncertain dispatch and broken polling never become a retryable failure", async () => {
  const t = delayedTransport();
  t.transport.runCall = async () => { throw new Error("Disconnected after sending"); };
  const first = await setup(t.transport).client.runBrief(brief);
  assert.equal(first.status, "pending"); assert.equal(first.runId, undefined);
  const other = delayedTransport();
  other.transport.getCallRun = async () => { throw new Error("Network down"); };
  const second = await setup(other.transport).client.runBrief(brief);
  assert.equal(second.status, "pending"); assert.equal(second.runId, "run-original");
});

test("session recovery blocks both a second confirmation and a replacement goal", async () => {
  const t = delayedTransport(); const { orch } = setup(t.transport);
  const s = orch.createSession("en");
  await orch.submitGoal(s.id, "Book a haircut", "en", { numbers: [brief.targetNumber] });
  orch.confirmAndCall(s.id);
  assert.throws(() => orch.confirmAndCall(s.id));
  assert.equal((await settle(orch, s.id)).phase, "pending");
  await assert.rejects(() => orch.submitGoal(s.id, "Try again", "en"), /existing call/i);
  t.finish(); orch.resumeMonitoring(s.id);
  assert.throws(() => orch.resumeMonitoring(s.id));
  assert.equal((await settle(orch, s.id)).result?.taskCompleted, true);
  assert.equal(t.calls(), 1);
});

test("comparison briefs cannot book even with booking fallback preferences", async () => {
  const fake = new FakeCalleTransport(() => {}); const inputs: PlanCallInput[] = [];
  const plan = fake.planCall.bind(fake);
  fake.planCall = async input => { inputs.push(input); return plan(input); };
  const { orch } = setup(fake); const s = orch.createSession("en");
  await orch.submitGoal(s.id, "Find the best clinic and book a visit", "en", {
    numbers: ["+13125550123", "+13125550124"], preferences: { fallbackTimes: "any afternoon" },
  });
  orch.confirmAndCall(s.id); await settle(orch, s.id);
  assert.equal(inputs.length, 2);
  for (const input of inputs) {
    assert.match(input.user_input, /INQUIRY ONLY/);
    assert.match(input.user_input, /Do NOT book, reserve, order/);
    assert.doesNotMatch(input.user_input, /do not leave without booking/i);
  }
  assert.ok(orch.getSession(s.id)?.ranked?.every(x => x.result.confirmationNumbers.length === 0));
});

test("comparison with only one search match remains inquiry-only", async () => {
  // Use a one-result search provider, as happens with a sparse real lookup.
  const single = new Orchestrator({ calle: setup(new FakeCalleTransport(() => {})).client, translator: new MockTranslator(),
    search: { name: "one", async find() { return [{ name: "One Clinic", phone: brief.targetNumber }]; } },
    classifier: new HeuristicIntentClassifier(), ranker: new HeuristicRanker(), slotExtractor: new NaiveSlotExtractor() });
  const ss = single.createSession("en");
  await single.submitGoal(ss.id, "Find me the best clinic", "en");
  assert.equal(single.getSession(ss.id)?.intent, "compare");
  assert.match(single.getSession(ss.id)?.brief?.objective ?? "", /INQUIRY ONLY/);
});

test("payment digits in goals, details and preferences are rejected before translation", async () => {
  const { orch, translator } = setup(new FakeCalleTransport(() => {}));
  let translated = false;
  translator.toEnglish = async text => { translated = true; return text; };
  const card = "4111 1111 1111 1111";
  for (const options of [{ facts: { insurance: card } }, { preferences: { payment: card } }, { availability: card }]) {
    const s = orch.createSession("hi");
    await assert.rejects(() => orch.submitGoal(s.id, "Book", "hi", options), /card-like/);
  }
  await assert.rejects(() => orch.submitGoal(orch.createSession("hi").id, card, "hi"));
  assert.equal(translated, false);
  assert.throws(() => assertNoCardData("४१११ ११११ ११११ ११११"));
  assert.doesNotThrow(() => assertNoCardData({ phone: "+13125550123", dob: "1990-01-01" }));
});

test("call logging excludes goal, facts, phone, confirmation token and nested secrets", () => {
  const logged = safeCallLogArgs({ user_input: "name: PRIVATE; DOB: PRIVATE", goal: "PRIVATE", to_phones: ["PRIVATE"],
    confirm_token: "PRIVATE", unexpected: { secret: "PRIVATE" }, run_id: "run-1", language: "English" });
  assert.equal(JSON.stringify(logged).includes("PRIVATE"), false);
  assert.deepEqual(logged, { run_id: "run-1", language: "English", destinationCount: 1 });
});

test("a translation outage after a successful call does not turn it into a retryable failure", async () => {
  const t = delayedTransport(); t.finish(); const { orch, translator } = setup(t.transport);
  const s = orch.createSession("hi");
  await orch.submitGoal(s.id, "Book", "hi", { numbers: [brief.targetNumber] });
  translator.fromEnglish = async () => { throw new Error("Translation offline"); };
  orch.confirmAndCall(s.id);
  const done = await settle(orch, s.id);
  assert.equal(done.phase, "done"); assert.equal(done.result?.taskCompleted, true);
  assert.equal(t.calls(), 1);
});
