import {
  APPLE_ROOT_CA_G3,
  BUNDLE_ID,
  DAILY_CHECKS,
  MAX_BODY_BYTES,
  PRODUCT_IDS,
} from "./config";
import { RejectedByModel, UpstreamError, checkSentence } from "./checker";
import type { Env } from "./env";
import { InputError, cleanSentence, cleanWord, pickLanguage } from "./guard";
import { EntitlementError, authorize, base64ToBytes, verifyTransaction } from "./jws";
import type { Reservation } from "./quota";

/// The counters, behind an interface so a test can make them fail.
export interface QuotaPort {
  reserve(name: string, day: string, limit: number, nowMs: number, replayKey?: string): Promise<Reservation>;
  refund(name: string, day: string): Promise<void>;
}

export interface Deps {
  /// Outbound HTTP, which in practice means Anthropic. Injected so that tests
  /// can prove a request never left, and can never spend money by accident.
  fetch: typeof fetch;
  now: () => Date;
  quota?: QuotaPort;
}

const GLOBAL_COUNTER = "global";
const SANDBOX_COUNTER = "sandbox";

function reply(status: number, body: Record<string, unknown>, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      // No CORS headers, deliberately. The only caller is a native app; a
      // browser has no business here, and `*` would let any web page spend a
      // visitor's subscription (SCOPE.md 5B.4).
      ...headers,
    },
  });
}

/// One line per request, built only from this module's own vocabulary:
/// a status and a reason code. Never the sentence, never the feedback, never
/// a transaction id - the App Store privacy declaration says nothing is
/// collected, and a log line is a collection (SCOPE.md 5B.6).
function record(status: number, reason: string): void {
  console.log(JSON.stringify({ event: "check", status, reason }));
}

function durableQuota(env: Env): QuotaPort {
  const stub = (name: string) => env.QUOTA.get(env.QUOTA.idFromName(name));
  return {
    reserve: (name, day, limit, nowMs, replayKey) => stub(name).reserve(day, limit, nowMs, replayKey),
    refund: (name, day) => stub(name).refund(day),
  };
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/// Reads at most `limit` bytes. `Content-Length` is checked first because it
/// is free, but it is a claim, not a fact - so the stream is counted too.
async function readBody(request: Request, limit: number): Promise<string | null> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (!Number.isFinite(declared) || declared > limit) return null;
  if (!request.body) return "";

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > limit) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

/// Apple's root, except under test, where a generated chain stands in for it.
/// The override is read only when ENVIRONMENT is "test": a stray variable on a
/// deployed Worker changes nothing, and a test asserts exactly that.
function trustedRoot(env: Env): Uint8Array<ArrayBuffer> {
  if (env.ENVIRONMENT === "test" && env.TEST_TRUST_ROOT) return base64ToBytes(env.TEST_TRUST_ROOT);
  return base64ToBytes(APPLE_ROOT_CA_G3);
}

function nextUtcMidnight(now: Date): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
}

const cap = (value: string | undefined) => {
  const number = Number.parseInt(value ?? "", 10);
  return Number.isFinite(number) && number > 0 ? number : 0;
};

/// The whole endpoint. The order of the steps is the security design:
/// nothing that costs money happens until the caller has been proven to be a
/// paying subscriber, and nothing is counted against them until their input
/// has been accepted (SCOPE.md 5B.0, I1).
export async function handle(request: Request, env: Env, deps: Deps): Promise<Response> {
  const url = new URL(request.url);
  if (request.method !== "POST" || url.pathname !== "/check") {
    return reply(404, { error: "not_found" });
  }

  const raw = await readBody(request, MAX_BODY_BYTES);
  if (raw === null) {
    record(413, "too-large");
    return reply(413, { error: "too_large" });
  }

  let body: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error();
    body = parsed as Record<string, unknown>;
  } catch {
    record(400, "json");
    return reply(400, { error: "bad_request" });
  }

  // 1. Who is this? Only `jws` is consulted. A `userId` or `deviceId` in the
  //    body is not read by anything below (SCOPE.md 5B.0, I2).
  const now = deps.now();
  const sandboxCap = cap(env.SANDBOX_DAILY_CAP);
  let transaction;
  try {
    if (typeof body.jws !== "string" || body.jws.length === 0) {
      throw new EntitlementError(401, "missing");
    }
    transaction = await verifyTransaction(body.jws, trustedRoot(env), now);
    authorize(
      transaction,
      { bundleId: BUNDLE_ID, productIds: PRODUCT_IDS, allowSandbox: sandboxCap > 0 },
      now,
    );
  } catch (error) {
    if (!(error instanceof EntitlementError)) throw error;
    record(error.status, error.reason);
    return reply(error.status, { error: error.status === 401 ? "unauthorized" : "forbidden" });
  }

  // 2. Is the input something this endpoint checks?
  let word: string;
  let sentence: string;
  try {
    word = cleanWord(body.word);
    sentence = cleanSentence(body.sentence);
  } catch (error) {
    if (!(error instanceof InputError)) throw error;
    record(error.status, error.reason);
    return reply(error.status, { error: error.status === 400 ? "bad_request" : "rejected" });
  }
  const language = pickLanguage(body.lang);

  // 3. Is there allowance left? The key comes out of the verified payload and
  //    is hashed before it is used as a name, so the raw id is never stored.
  const quota = deps.quota ?? durableQuota(env);
  const day = now.toISOString().slice(0, 10);
  const resetAt = nextUtcMidnight(now);
  const retryAfter = String(Math.max(1, Math.ceil((resetAt.getTime() - now.getTime()) / 1000)));
  const exhausted = () =>
    reply(429, { error: "quota", resetAt: resetAt.toISOString() }, { "retry-after": retryAfter });

  const user = `user:${await sha256Hex(transaction.originalTransactionId)}`;
  const replayKey = await sha256Hex(`${word}\n${sentence}`);
  const charged: string[] = [];
  let remaining: number;
  try {
    const own = await quota.reserve(user, day, DAILY_CHECKS, now.getTime(), replayKey);
    if (!own.ok) {
      record(429, "quota");
      return exhausted();
    }
    remaining = Math.max(0, DAILY_CHECKS - own.used);

    // A free retry is not counted anywhere: it was paid for the first time.
    if (own.charged) {
      charged.push(user);

      if (transaction.environment === "Sandbox") {
        const sandbox = await quota.reserve(SANDBOX_COUNTER, day, sandboxCap, now.getTime());
        if (!sandbox.ok) {
          await quota.refund(user, day);
          record(429, "sandbox-cap");
          return exhausted();
        }
        charged.push(SANDBOX_COUNTER);
      }

      // The fuse. If every layer above has a hole in it, the day's bill
      // still cannot pass this number (SCOPE.md 5B.2).
      const everyone = await quota.reserve(GLOBAL_COUNTER, day, cap(env.GLOBAL_DAILY_CAP), now.getTime());
      if (!everyone.ok) {
        for (const name of charged) await quota.refund(name, day);
        record(503, "global-cap");
        return reply(503, { error: "unavailable" }, { "retry-after": retryAfter });
      }
      charged.push(GLOBAL_COUNTER);
    }
  } catch {
    // The counter is unreachable. Fail closed: an uncounted call is an
    // unbounded bill, and "try again shortly" is a cheap thing to say.
    record(503, "quota-store");
    return reply(503, { error: "unavailable" });
  }

  // 4. Only now does anything leave for Anthropic.
  try {
    const feedback = await checkSentence({ word, sentence, language }, env.ANTHROPIC_API_KEY, deps.fetch);
    record(200, "ok");
    return reply(200, { ...feedback, remaining });
  } catch (error) {
    if (error instanceof RejectedByModel) {
      record(422, "model-rejected");
      return reply(422, { error: "rejected" });
    }
    // No answer, so no charge. Best effort: if the refund itself fails the
    // learner is one check short today, which is the lesser of the two wrongs.
    for (const name of charged) await quota.refund(name, day).catch(() => {});
    record(503, error instanceof UpstreamError ? error.message : "internal");
    return reply(503, { error: "unavailable" });
  }
}
