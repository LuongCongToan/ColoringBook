import type { QuotaCounter } from "./quota";

export interface Env {
  /// `wrangler secret put ANTHROPIC_API_KEY`. Never in wrangler.toml, never in git.
  ANTHROPIC_API_KEY: string;
  QUOTA: DurableObjectNamespace<QuotaCounter>;
  ENVIRONMENT: "production" | "staging" | "test";
  /// The last fuse: checks per UTC day across every user.
  GLOBAL_DAILY_CAP: string;
  /// Checks per UTC day shared by ALL sandbox transactions. "0" refuses them.
  SANDBOX_DAILY_CAP: string;
  /// Base64 DER of a stand-in root. Read only when ENVIRONMENT is "test".
  TEST_TRUST_ROOT?: string;
}
