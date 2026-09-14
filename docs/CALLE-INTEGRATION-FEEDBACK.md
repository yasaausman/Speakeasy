# CALL-E integration feedback

Two reproducible integration gaps we hit building [KindlyCall](https://github.com/yasaausman/KindlyCall)
against the `/mcp/openagent_oauth` MCP endpoint. Both cost real debugging time and
have simple documentation (or example) fixes. This file is written to be filed
directly as an issue (or PR) on
[`CALLE-AI/call-e-integrations`](https://github.com/CALLE-AI/call-e-integrations).

---

## 1. A self-driven MCP OAuth client connects and lists tools, but is `Unauthorized` on `tools/call`

**What happens:** Following the TypeScript OAuth example
(`examples/mcp-oauth-client`), a client performs dynamic client registration +
PKCE, connects, and `tools/list` succeeds and returns `plan_call` / `run_call` /
`get_call_run`. But the first `tools/call` (`plan_call`) returns **`Unauthorized`**
— even though the connection and tool discovery were authorized.

```
{"event":"connected","tools":["plan_call","run_call","get_call_run", ...]}
{"event":"tools/call:req","tool":"plan_call", ...}
❌  Unauthorized
```

**Root cause / workaround we found:** tool invocation needs the account-linked
bearer token that `calle auth login` caches at
`~/.calle-mcp/cli/<hash>/token.json`. Reusing that token (as a static
`Authorization: Bearer` via the SDK's `authProvider`) makes `plan_call` /
`run_call` succeed immediately. The standalone OAuth example's freshly registered
token authorizes discovery but not the call tools.

**Suggested fix:** document that placing calls requires the token from
`calle auth login` (tie the account/quota to the token), and note that the
standalone `mcp-oauth-client` example is sufficient for `tools/list` but not for
`tools/call`; or clarify the scope / client registration needed so a from-scratch
OAuth client can be authorized for the call tools.

## 2. `get_call_run` nests `summary` / `transcript` / `outcome` under `result{}`, not at the top level

**What happens:** The MCP doc's handoff-fields table lists `summary`,
`transcript`, etc. A client that reads them at the top level of the
`structuredContent` gets **empty values on a `COMPLETED` run**. The real shape is:

```jsonc
{
  "status": "COMPLETED",
  "result": {
    "summary": "The test call completed successfully...",
    "transcript": "[00:00:00] BOT: Hi. ...",
    "outcome": { "task_completed": true, "completion_confidence": { "score": 0.86, "label": "high" }, "evidence": [ ... ] },
    "extracted": { "calling": { "duration_seconds": 26, "calls": [ ... ] }, "to_phones": [ ... ] }
  }
}
```

(A synthetic example with this shape, using reserved fictional data, is committed at
[`docs/sample-run.json`](./sample-run.json).)

**Suggested fix:** document the `result` envelope (`result.summary`,
`result.transcript`, `result.outcome.*`, `result.extracted.*`) in the
`get_call_run` section, or add a normalized example response, so clients don't
read the top level and silently get empty results.

---

### Environment
- Endpoint: `https://seleven-mcp-sg.airudder.com/mcp/openagent_oauth`
- `@modelcontextprotocol/sdk` ^1.29, `@call-e/cli` (auth via `calle auth login`)
- Repro'd on a TypeScript Streamable-HTTP MCP client.
