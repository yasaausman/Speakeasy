/**
 * Speakeasy backend HTTP API. The iOS app talks only to this; all CALL-E logic
 * stays behind server/calle/. Endpoints:
 *
 *   GET  /health
 *   GET  /api/languages
 *   POST /api/sessions                 { lang? }              → { sessionId, phase }
 *   POST /api/sessions/:id/goal        { text, lang, number? } → GoalUnderstanding
 *   POST /api/sessions/:id/confirm                            → 202 (call starts)
 *   GET  /api/sessions/:id                                    → SessionStateDTO
 */
import "./env.js"; // must be first — loads .env before anything reads provider keys
import Fastify from "fastify";

import { LANGUAGES, coerceLang } from "./language/languages.js";
import { Orchestrator } from "./orchestrator/orchestrator.js";
import { toDTO } from "./orchestrator/session.js";

const app = Fastify({ logger: true });
const orchestrator = new Orchestrator();

app.get("/health", async () => ({ ok: true }));

app.get("/api/languages", async () => ({
  languages: Object.values(LANGUAGES).map((l) => ({
    code: l.code,
    name: l.name,
    endonym: l.endonym,
    rtl: l.rtl,
  })),
}));

app.post("/api/sessions", async (req) => {
  const body = (req.body ?? {}) as { lang?: string };
  const session = orchestrator.createSession(coerceLang(body.lang));
  return { sessionId: session.id, phase: session.phase };
});

app.post("/api/sessions/:id/goal", async (req, reply) => {
  const { id } = req.params as { id: string };
  const body = (req.body ?? {}) as {
    text?: string;
    lang?: string;
    numbers?: string[];
    number?: string;
    facts?: Record<string, string>;
  };
  if (!body.text?.trim()) {
    return reply.code(400).send({ error: "text is required" });
  }
  // Accept `numbers` (multi-call) or a single `number`.
  const numbers = Array.isArray(body.numbers) ? body.numbers : body.number ? [body.number] : undefined;
  const facts = body.facts && typeof body.facts === "object" ? body.facts : undefined;
  try {
    const understanding = await orchestrator.submitGoal(id, body.text, coerceLang(body.lang), numbers, facts);
    return understanding;
  } catch (err) {
    return reply.code(404).send({ error: err instanceof Error ? err.message : "unknown session" });
  }
});

app.post("/api/sessions/:id/confirm", async (req, reply) => {
  const { id } = req.params as { id: string };
  try {
    orchestrator.confirmAndCall(id);
    return reply.code(202).send({ ok: true });
  } catch (err) {
    return reply.code(409).send({ error: err instanceof Error ? err.message : "cannot confirm" });
  }
});

app.get("/api/sessions/:id", async (req, reply) => {
  const { id } = req.params as { id: string };
  const session = orchestrator.getSession(id);
  if (!session) return reply.code(404).send({ error: "unknown session" });
  return toDTO(session);
});

const port = Number(process.env.PORT || 3000);
app
  .listen({ port, host: "0.0.0.0" })
  .then(() => app.log.info(`Speakeasy backend listening on :${port} · translator=${orchestrator.translatorName}`))
  .catch((err) => {
    app.log.error(err);
    process.exit(1);
  });
