/**
 * CALL-E result normalization — the breadth that real calls can't cheaply prove.
 *
 * A real-call matrix across every terminal status is expensive and non-deterministic
 * (you can't reliably make a line ring BUSY on demand). These tests instead pin the
 * pure mapping from CALL-E's terminal statuses onto KindlyCall's normalized outcome,
 * plus the "COMPLETED ≠ success" reading and confirmation-number extraction — the
 * places a wrong mapping would quietly mislead the user.
 */
import assert from "node:assert/strict";
import { test } from "node:test";

import { CalleClient, FakeCalleTransport } from "./client.js";
import { normalizeStatus, isTerminalStatus, type GetCallRunResult } from "./types.js";

const client = new CalleClient({ transport: new FakeCalleTransport(() => {}), log: () => {} });
const norm = (r: Partial<GetCallRunResult>) => client.normalize({ raw: {}, ...r });

test("normalizeStatus maps every terminal status (and NO ANSWER with a space)", () => {
  assert.equal(normalizeStatus("COMPLETED"), "completed");
  assert.equal(normalizeStatus("NO_ANSWER"), "no_answer");
  assert.equal(normalizeStatus("NO ANSWER"), "no_answer");
  assert.equal(normalizeStatus("VOICEMAIL"), "voicemail");
  assert.equal(normalizeStatus("DECLINED"), "declined");
  assert.equal(normalizeStatus("BUSY"), "busy");
  assert.equal(normalizeStatus("CANCELED"), "canceled");
  assert.equal(normalizeStatus("CANCELLED"), "canceled");   // both spellings
  assert.equal(normalizeStatus("EXPIRED"), "expired");
  assert.equal(normalizeStatus("WEIRD_UNKNOWN"), "failed"); // anything else fails safe
  assert.equal(normalizeStatus(undefined), "failed");
});

test("isTerminalStatus is case/space tolerant and rejects in-flight statuses", () => {
  assert.ok(isTerminalStatus("completed"));
  assert.ok(isTerminalStatus(" No Answer "));
  assert.ok(isTerminalStatus("VOICEMAIL"));
  assert.equal(isTerminalStatus("IN_PROGRESS"), false);
  assert.equal(isTerminalStatus("QUEUED"), false);
  assert.equal(isTerminalStatus(undefined), false);
});

test("VOICEMAIL / BUSY / NO_ANSWER normalize with a readable outcome, not a success", () => {
  for (const raw of ["VOICEMAIL", "BUSY", "NO_ANSWER", "DECLINED"]) {
    const r = norm({ status: raw });
    assert.equal(r.rawStatus, raw);
    assert.notEqual(r.status, "completed");
    assert.ok(r.outcome.length > 0, "always has a human-readable outcome");
    assert.equal(r.confirmationNumbers.length, 0, "a non-answer never invents a confirmation");
  }
});

test("COMPLETED with task_completed:false is surfaced as not-done (COMPLETED ≠ success)", () => {
  const r = norm({
    status: "COMPLETED",
    summary: "They need your insurance before booking.",
    details: { task_completed: false, gaps: ["insurance"] },
  });
  assert.equal(r.status, "completed");        // the run ended
  assert.equal(r.taskCompleted, false);       // …but the task did not succeed
  assert.deepEqual(r.gaps, ["insurance"]);
});

test("confirmation numbers are pulled from structured fields and from summary text", () => {
  const structured = norm({ status: "COMPLETED", details: { confirmation: "4471" } });
  assert.deepEqual(structured.confirmationNumbers, ["4471"]);

  const fromText = norm({ status: "COMPLETED", summary: "Booked. Confirmation number 5562." });
  assert.deepEqual(fromText.confirmationNumbers, ["5562"]);

  // Must NOT capture the literal word when there's no actual number.
  const none = norm({ status: "COMPLETED", summary: "Please capture any confirmation number." });
  assert.equal(none.confirmationNumbers.length, 0);
});

test("nested CALL-E outcome{} (confidence/evidence/task_completed) is read like the real API", () => {
  const r = norm({
    status: "COMPLETED",
    summary: "Booked Tuesday 9:40am.",
    details: {
      outcome: {
        task_completed: true,
        completion_confidence: { score: 0.9, label: "high" },
        evidence: ["A live receptionist confirmed the booking."],
      },
    },
  });
  assert.equal(r.taskCompleted, true);
  assert.equal(r.confidence?.label, "high");
  assert.equal(r.evidence?.length, 1);
});

test("a real run with no transcript field rebuilds one from the activity feed", () => {
  const r = norm({
    status: "COMPLETED",
    activity: [{ kind: "callee_realtime", message: "Bot: Hello." }, { message: "Rep: Hi." }],
  });
  assert.match(r.transcript, /Bot: Hello\./);
  assert.match(r.transcript, /Rep: Hi\./);
});
