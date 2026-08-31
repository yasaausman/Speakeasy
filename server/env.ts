/**
 * Load .env into process.env with zero dependencies (Node >= 20.12).
 * Side-effect import — keep it FIRST in the entrypoint so provider keys are set
 * before anything reads them. Real environment variables still take precedence
 * over the file for anything already set.
 */
import fs from "node:fs";

const loadEnvFile = (process as unknown as { loadEnvFile?: (path?: string) => void }).loadEnvFile;
if (loadEnvFile && fs.existsSync(".env")) {
  try {
    loadEnvFile(".env");
  } catch {
    // Malformed/unreadable .env — fall back to real env vars.
  }
}
