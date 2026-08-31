/**
 * Phase 0 smoke test: build a hardcoded English brief and drive the full
 * CALL-E workflow (plan_call → run_call → poll get_call_run → terminal),
 * printing the normalized CallResult.
 *
 *   npm run smoke:fake     # dry-run, no network/auth/real call  (default)
 *   npm run smoke:real     # places ONE real call — costs a call from your quota
 *
 * The real path first requires CALL-E browser auth (see README).
 */
import { createCalleClient } from "../server/calle/client.js";
import type { CallBrief } from "../server/calle/types.js";

const REAL = process.argv.includes("--real") || process.env.CALLE_MODE === "real";

// Hardcoded English brief for Phase 0. Replace targetNumber before a real run.
const brief: CallBrief = {
  objective: "Book a dentist appointment for my son next week",
  targetNumber: process.env.SMOKE_TARGET_NUMBER || "+15555550123",
  targetRegion: "US",
  language: "English",
  constraints: ["mornings only", "next week"],
  facts: {
    "patient name": "Alex",
    insurance: "Medicaid",
    "callback number": process.env.SMOKE_CALLBACK_NUMBER || "+15555550100",
  },
  successCondition: "appointment booked and confirmation number captured; confirm they accept Medicaid",
  fallback: "if no morning slots, take the earliest afternoon; if closed, report their hours",
  agentDisclosure:
    "This is an AI assistant calling on behalf of a patient. I'm not a human; I'm placing this call for them.",
};

async function main() {
  console.log(`\n=== Speakeasy Phase 0 smoke test — mode: ${REAL ? "REAL ☎️" : "FAKE (dry-run)"} ===\n`);
  if (REAL) {
    console.log(`This will place a REAL call to ${brief.targetNumber} and spend one call from your quota.\n`);
  }

  const client = createCalleClient({ mode: REAL ? "real" : "fake" });
  try {
    const result = await client.runBrief(brief, (r) => {
      console.log(`  … status=${r.status ?? "?"}${r.summary ? ` — ${r.summary}` : ""}`);
    });

    console.log("\n=== Normalized CallResult ===");
    console.log(JSON.stringify(result, null, 2));
    console.log(
      `\n✅ Done. status=${result.status} (raw=${result.rawStatus}), ` +
        `confirmations=[${result.confirmationNumbers.join(", ")}]`,
    );
  } finally {
    await client.close();
  }
}

main().catch((err) => {
  console.error("\n❌ Smoke test failed:", err?.message || err);
  process.exitCode = 1;
});
