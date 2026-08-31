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

// Hardcoded English brief for Phase 0. Deliberately a HARMLESS self-test so the
// first real call to your own phone is clean and predictable — no fake booking,
// no personal data. Set SMOKE_TARGET_NUMBER to your own phone before a real run.
const brief: CallBrief = {
  objective:
    "Make a short test call. Greet the person, confirm they can hear you clearly, thank them, then end the call.",
  targetNumber: process.env.SMOKE_TARGET_NUMBER || "+15555550123",
  targetRegion: "US",
  language: "English",
  constraints: ["keep it under about 30 seconds", "do not ask for or collect any personal information"],
  facts: {},
  successCondition: "the person confirmed they can hear the call clearly",
  fallback: "if no one answers or it goes to voicemail, just end the call without leaving a message",
  agentDisclosure:
    "This is an automated test call from an AI assistant — I'm not a human. I'm just checking that this call connects.",
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
