/**
 * OAuth plumbing for the CALL-E MCP endpoint.
 *
 * Adapted from call-e-integrations/examples/mcp-oauth-client/typescript. Adds
 * on-disk persistence of the dynamic client registration + tokens so repeated
 * real smoke tests don't force a fresh browser login every run.
 *
 * SECURITY: tokens/codes are never printed. The cache file is written 0600 and
 * lives under CALLE_TOKEN_PATH (default .speakeasy/, git-ignored).
 */
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { URL } from "node:url";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { UnauthorizedError } from "@modelcontextprotocol/sdk/client/auth.js";
import type {
  OAuthClientInformationMixed,
  OAuthClientMetadata,
  OAuthTokens,
} from "@modelcontextprotocol/sdk/shared/auth.js";
import type { OAuthClientProvider, OAuthDiscoveryState } from "@modelcontextprotocol/sdk/client/auth.js";

export type OAuthConfig = {
  serverUrl: string;
  redirectUri: string;
  scope: string;
  tokenPath: string;
};

type PersistedState = {
  clientInfo?: OAuthClientInformationMixed;
  tokens?: OAuthTokens;
};

class PersistentOAuthClientProvider implements OAuthClientProvider {
  private persisted: PersistedState = {};
  private savedCodeVerifier?: string;
  private savedDiscovery?: OAuthDiscoveryState;

  constructor(
    private readonly redirectUri: string,
    private readonly metadata: OAuthClientMetadata,
    private readonly tokenPath: string,
    private readonly onRedirect: (url: URL) => void,
  ) {
    try {
      const raw = fs.readFileSync(this.tokenPath, "utf8");
      this.persisted = JSON.parse(raw) as PersistedState;
    } catch {
      // No cache yet — first run.
    }
  }

  private persist(): void {
    fs.mkdirSync(path.dirname(this.tokenPath), { recursive: true, mode: 0o700 });
    fs.writeFileSync(this.tokenPath, JSON.stringify(this.persisted), { encoding: "utf8", mode: 0o600 });
    try {
      fs.chmodSync(this.tokenPath, 0o600);
    } catch {
      // Best effort.
    }
  }

  get redirectUrl(): string {
    return this.redirectUri;
  }

  get clientMetadata(): OAuthClientMetadata {
    return this.metadata;
  }

  clientInformation(): OAuthClientInformationMixed | undefined {
    return this.persisted.clientInfo;
  }

  saveClientInformation(clientInformation: OAuthClientInformationMixed): void {
    this.persisted.clientInfo = clientInformation;
    this.persist();
  }

  tokens(): OAuthTokens | undefined {
    return this.persisted.tokens;
  }

  saveTokens(tokens: OAuthTokens): void {
    this.persisted.tokens = tokens;
    this.persist();
  }

  redirectToAuthorization(authorizationUrl: URL): void {
    this.onRedirect(authorizationUrl);
  }

  saveCodeVerifier(codeVerifier: string): void {
    this.savedCodeVerifier = codeVerifier;
  }

  codeVerifier(): string {
    if (!this.savedCodeVerifier) {
      throw new Error("No OAuth code verifier has been saved.");
    }
    return this.savedCodeVerifier;
  }

  saveDiscoveryState(state: OAuthDiscoveryState): void {
    this.savedDiscovery = state;
  }

  discoveryState(): OAuthDiscoveryState | undefined {
    return this.savedDiscovery;
  }
}

/** Spin up a one-shot localhost server to catch the OAuth redirect code. */
function waitForLocalCallback(redirectUri: string, authorizationUrl: URL): Promise<string> {
  const callbackUrl = new URL(redirectUri);
  if (!["127.0.0.1", "localhost"].includes(callbackUrl.hostname)) {
    throw new Error("Only localhost redirect URIs can be handled automatically.");
  }

  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      try {
        const requestUrl = new URL(req.url || "/", callbackUrl.origin);
        if (requestUrl.pathname !== callbackUrl.pathname) {
          res.writeHead(404);
          res.end("Not found");
          return;
        }
        const error = requestUrl.searchParams.get("error");
        const code = requestUrl.searchParams.get("code");
        if (error) {
          res.writeHead(400, { "content-type": "text/plain" });
          res.end("Authorization failed.");
          reject(new Error(`OAuth authorization failed: ${error}`));
          server.close();
          return;
        }
        if (!code) {
          res.writeHead(400, { "content-type": "text/plain" });
          res.end("Missing code.");
          reject(new Error("OAuth callback did not include a code."));
          server.close();
          return;
        }
        res.writeHead(200, { "content-type": "text/plain" });
        res.end("Authorization complete. You can return to the terminal.");
        resolve(code);
        server.close();
      } catch (err) {
        reject(err);
        server.close();
      }
    });
    server.listen(Number(callbackUrl.port || 80), callbackUrl.hostname, () => {
      // NOTE: the auth URL is a secret-bearing browser login URL. We print it so
      // the user can open it, but never log tokens/codes/callback URLs.
      console.log(`\n[calle] Open this URL in your browser to authorize CALL-E:\n${authorizationUrl.toString()}\n`);
    });
  });
}

/**
 * Reuse the `calle` CLI's cached bearer token. The CLI (calle auth login) is the
 * blessed way to authenticate; its token is tied to the user's account + call
 * quota. We prefer it so we don't run a second, separate OAuth flow (which can
 * connect but is not authorized to place calls). Cache: ~/.calle-mcp/cli/<hash>/token.json.
 */
function findCliToken(serverUrl: string): string | null {
  const base = path.join(os.homedir(), ".calle-mcp", "cli");
  let dirs: string[];
  try {
    dirs = fs.readdirSync(base);
  } catch {
    return null;
  }
  const now = Date.now();
  for (const dir of dirs) {
    try {
      const raw = fs.readFileSync(path.join(base, dir, "token.json"), "utf8");
      const j = JSON.parse(raw) as {
        server_url?: string;
        expires_at?: string;
        token?: { access_token?: string };
      };
      if (j.server_url && serverUrl && j.server_url !== serverUrl) continue;
      if (j.expires_at && Date.parse(j.expires_at) <= now) continue;
      const accessToken = j.token?.access_token;
      if (typeof accessToken === "string" && accessToken) return accessToken;
    } catch {
      // Skip unreadable/other entries.
    }
  }
  return null;
}

/** An OAuth provider that just hands back a pre-issued bearer token — no flow. */
class StaticTokenOAuthProvider implements OAuthClientProvider {
  constructor(private readonly accessToken: string) {}
  get redirectUrl(): string {
    return "";
  }
  get clientMetadata(): OAuthClientMetadata {
    return { redirect_uris: [] };
  }
  clientInformation(): OAuthClientInformationMixed | undefined {
    return undefined;
  }
  saveClientInformation(): void {}
  tokens(): OAuthTokens {
    return { access_token: this.accessToken, token_type: "Bearer" };
  }
  saveTokens(): void {}
  redirectToAuthorization(): void {
    throw new Error("CALL-E rejected the calle CLI token. Run `calle auth login` again.");
  }
  saveCodeVerifier(): void {}
  codeVerifier(): string {
    throw new Error("No code verifier for a static token.");
  }
  saveDiscoveryState(): void {}
  discoveryState(): OAuthDiscoveryState | undefined {
    return undefined;
  }
}

/**
 * Connect an MCP client to CALL-E over Streamable HTTP.
 * Prefers the `calle` CLI's cached token; falls back to a browser OAuth flow.
 */
export async function connectCalle(
  config: OAuthConfig,
): Promise<{ client: Client; transport: StreamableHTTPClientTransport }> {
  const cliToken = findCliToken(config.serverUrl);
  if (cliToken) {
    const provider = new StaticTokenOAuthProvider(cliToken);
    const client = new Client({ name: "speakeasy", version: "0.0.0" }, { capabilities: {} });
    const transport = new StreamableHTTPClientTransport(new URL(config.serverUrl), { authProvider: provider });
    await client.connect(transport);
    return { client, transport };
  }

  // No CLI token — fall back to a self-contained browser OAuth flow.
  let authorizationUrl: URL | null = null;
  const clientMetadata: OAuthClientMetadata = {
    client_name: "Speakeasy CALL-E client",
    redirect_uris: [config.redirectUri],
    grant_types: ["authorization_code", "refresh_token"],
    response_types: ["code"],
    token_endpoint_auth_method: "none",
    scope: config.scope,
  };
  const provider = new PersistentOAuthClientProvider(
    config.redirectUri,
    clientMetadata,
    config.tokenPath,
    (url) => {
      authorizationUrl = url;
    },
  );

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const client = new Client({ name: "speakeasy", version: "0.0.0" }, { capabilities: {} });
    const transport = new StreamableHTTPClientTransport(new URL(config.serverUrl), { authProvider: provider });
    try {
      await client.connect(transport);
      return { client, transport };
    } catch (error) {
      if (!(error instanceof UnauthorizedError)) {
        throw error;
      }
      if (!authorizationUrl) {
        throw new Error("OAuth authorization was required, but no authorization URL was produced.");
      }
      const code = await waitForLocalCallback(config.redirectUri, authorizationUrl);
      await transport.finishAuth(code);
      await transport.close().catch(() => {});
      authorizationUrl = null;
    }
  }

  throw new Error("OAuth connection did not complete after multiple attempts.");
}
