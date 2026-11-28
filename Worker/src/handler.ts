import {
  APPLE_ROOT_CA_G3,
  BOOK_PACK,
  BOOKS,
  BUNDLE_ID,
  DEFAULT_STYLE,
  LIMITS,
  MAX_BODY_BYTES,
  PROMPTS,
  PROMPT_VERSION,
  SUBSCRIPTIONS,
} from "./config";
import type { Env } from "./env";
import { Moderated, UpstreamError, generatePage } from "./generator";
import { InputError, checkPhoto, pickStyle } from "./image";
import { EntitlementError, type Transaction, authorize, base64ToBytes, verifyTransaction } from "./jws";
import type { Reservation } from "./quota";

/// The counters, behind an interface so a test can make them fail.
export interface QuotaPort {
  reserve(name: string, period: string, limit: number, nowMs: number, replayKey?: string): Promise<Reservation>;
  refund(name: string, period: string): Promise<void>;
}

export interface Deps {
  /// Outbound HTTP, which in practice means BFL. Injected so that tests can
  /// prove a request never left, and can never spend money by accident.
  fetch: typeof fetch;
  now: () => Date;
  sleep?: (ms: number) => Promise<void>;
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
      // browser has no business here (SCOPE.md 5B.4).
      ...headers,
    },
  });
}

/// One line per request, built only from this module's own vocabulary: a
/// status and a reason code. Never the photo, never the page, never a
/// transaction id (docs/privacy.md, SCOPE.md 5B.6).
function record(status: number, reason: string): void {
  console.log(JSON.stringify({ event: "generate", status, reason }));
}

function durableQuota(env: Env): QuotaPort {
  const stub = (name: string) => env.QUOTA.get(env.QUOTA.idFromName(name));
  return {
    reserve: (name, period, limit, nowMs, replayKey) => stub(name).reserve(period, limit, nowMs, replayKey),
    refund: (name, period) => stub(name).refund(period),
  };
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  // Chunked: spreading a few hundred KB into one call overflows the stack.
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
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

const cap = (value: string | undefined) => {
  const number = Number.parseInt(value ?? "", 10);
  return Number.isFinite(number) && number > 0 ? number : 0;
};

/// Which counter a verified purchase draws on (docs/app-store-products.md).
interface Plan {
  counter: string;
  period: string;
  limit: number;
  /// When the allowance comes back. None for a book or a trial: those are
  /// used up, and the app offers a purchase instead.
  resetAt?: Date;
  /// Per-person key for the daily ceiling.
  person: string;
  reason: string;
}

async function planFor(tx: Transaction, now: Date): Promise<Plan> {
  if (BOOKS.has(tx.productId)) {
    const book = await sha256Hex(`book:${tx.transactionId}`);
    const limit = tx.productId === BOOK_PACK ? LIMITS.bookPack : LIMITS.book;
    return { counter: `book:${book}`, period: "book", limit, person: book, reason: "book" };
  }
  const person = await sha256Hex(`sub:${tx.originalTransactionId}`);
  if (tx.offerType === 1) {
    return { counter: `trial:${person}`, period: "trial", limit: LIMITS.trial, person, reason: "trial" };
  }
  const family = tx.inAppOwnershipType === "FAMILY_SHARED";
  return {
    counter: `month:${person}`,
    period: now.toISOString().slice(0, 7),
    limit: family ? LIMITS.family : LIMITS.monthly,
    resetAt: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)),
    person,
    reason: family ? "family" : "monthly",
  };
}

/// The whole endpoint. The order of the steps is the security design:
/// nothing that costs money happens until the caller has been proven to have
/// paid, and nothing is counted against them until their input has been
/// accepted (SCOPE.md 5B.0, I1).
export async function handle(request: Request, env: Env, deps: Deps): Promise<Response> {
  const url = new URL(request.url);
  if (request.method !== "POST" || url.pathname !== "/generate") {
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
  let transaction: Transaction;
  try {
    if (typeof body.jws !== "string" || body.jws.length === 0) {
      throw new EntitlementError(401, "missing");
    }
    transaction = await verifyTransaction(body.jws, trustedRoot(env), now);
    authorize(
      transaction,
      {
        bundleId: BUNDLE_ID,
        subscriptions: SUBSCRIPTIONS,
        consumables: BOOKS,
        allowSandbox: sandboxCap > 0,
      },
      now,
    );
  } catch (error) {
    if (!(error instanceof EntitlementError)) throw error;
    record(error.status, error.reason);
    return reply(error.status, { error: error.status === 401 ? "unauthorized" : "forbidden" });
  }

  // 2. Is the upload something this endpoint draws?
  let photo;
  try {
    photo = checkPhoto(body.image);
  } catch (error) {
    if (!(error instanceof InputError)) throw error;
    record(error.status, error.reason);
    return reply(error.status, { error: error.status === 400 ? "bad_request" : "rejected" });
  }
  const style = pickStyle(body.style, PROMPTS, DEFAULT_STYLE);
  const prompt = PROMPTS[style]!;

  // 3. Is there allowance left? Keys come out of the verified payload and are
  //    hashed before use, so no raw transaction id is ever stored.
  const quota = deps.quota ?? durableQuota(env);
  const plan = await planFor(transaction, now);
  const day = now.toISOString().slice(0, 10);
  const midnight = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
  const secondsUntil = (when: Date) => String(Math.max(1, Math.ceil((when.getTime() - now.getTime()) / 1000)));
  const exhausted = (resetAt?: Date) =>
    resetAt
      ? reply(429, { error: "quota", resetAt: resetAt.toISOString() }, { "retry-after": secondsUntil(resetAt) })
      : reply(429, { error: "quota" });

  const dailyCounter = `day:${plan.person}`;
  const replayKey = await sha256Hex(`${style}\n${photo.base64}`);
  const charged: [string, string][] = [];
  let remaining: number;
  try {
    const own = await quota.reserve(plan.counter, plan.period, plan.limit, now.getTime(), replayKey);
    if (!own.ok) {
      record(429, `quota-${plan.reason}`);
      return exhausted(plan.resetAt);
    }
    remaining = Math.max(0, plan.limit - own.used);

    // A free retry is not counted anywhere: it was paid for the first time.
    if (own.charged) {
      charged.push([plan.counter, plan.period]);
      const refundAll = async () => {
        for (const [name, period] of charged) await quota.refund(name, period);
      };

      const daily = await quota.reserve(dailyCounter, day, LIMITS.daily, now.getTime());
      if (!daily.ok) {
        await refundAll();
        record(429, "quota-daily");
        return exhausted(midnight);
      }
      charged.push([dailyCounter, day]);

      if (transaction.environment === "Sandbox") {
        const sandbox = await quota.reserve(SANDBOX_COUNTER, day, sandboxCap, now.getTime());
        if (!sandbox.ok) {
          await refundAll();
          record(429, "sandbox-cap");
          return exhausted(midnight);
        }
        charged.push([SANDBOX_COUNTER, day]);
      }

      // The fuse. If every layer above has a hole in it, the day's bill
      // still cannot pass this number (SCOPE.md 5B.2).
      const everyone = await quota.reserve(GLOBAL_COUNTER, day, cap(env.GLOBAL_DAILY_CAP), now.getTime());
      if (!everyone.ok) {
        await refundAll();
        record(503, "global-cap");
        return reply(503, { error: "unavailable" }, { "retry-after": secondsUntil(midnight) });
      }
      charged.push([GLOBAL_COUNTER, day]);
    }
  } catch {
    // The counter is unreachable. Fail closed: an uncounted call is an
    // unbounded bill, and "try again shortly" is a cheap thing to say.
    record(503, "quota-store");
    return reply(503, { error: "unavailable" });
  }

  // 4. Only now does anything leave for the model.
  try {
    const page = await generatePage(photo, prompt, env.BFL_API_KEY, {
      fetch: deps.fetch,
      sleep: deps.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms))),
      now: () => deps.now().getTime(),
    });
    record(200, "ok");
    return reply(200, { image: bytesToBase64(page.png), remaining, style, promptVersion: PROMPT_VERSION });
  } catch (error) {
    if (error instanceof Moderated) {
      record(422, "moderated");
      return reply(422, { error: "rejected" });
    }
    // No page, so no charge. Best effort: if the refund itself fails the
    // parent is one page short, which is the lesser of the two wrongs.
    for (const [name, period] of charged) await quota.refund(name, period).catch(() => {});
    record(503, error instanceof UpstreamError ? error.message : "internal");
    return reply(503, { error: "unavailable" });
  }
}
