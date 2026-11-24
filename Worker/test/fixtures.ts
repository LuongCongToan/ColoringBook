// tsyringe, inside @peculiar/x509, refuses to load without this polyfill.
import "reflect-metadata";
import * as x509 from "@peculiar/x509";
import { env as bindings } from "cloudflare:workers";
import { vi } from "vitest";
import { BUNDLE_ID, MODEL } from "../src/config";
import type { Env } from "../src/env";
import { type Deps, handle } from "../src/handler";
import { OID_APPLE_RECEIPT_SIGNING, OID_APPLE_WWDR_INTERMEDIATE } from "../src/jws";

// A stand-in for Apple's certificate chain, generated fresh for each run.
//
// It has the same shape as the real one - P-384 root and intermediate, P-256
// leaf, Apple's marker extensions - so the verifier runs exactly the code it
// runs in production. The only difference is which root is trusted, and that
// difference is itself under test (see "a stray TEST_TRUST_ROOT").

const P384 = { name: "ECDSA", namedCurve: "P-384", hash: "SHA-384" } as const;
const P256 = { name: "ECDSA", namedCurve: "P-256", hash: "SHA-256" } as const;
const DAY = 86_400_000;
const NULL_DER = new Uint8Array([0x05, 0x00]);

const toBase64 = (buffer: ArrayBuffer) => btoa(String.fromCharCode(...new Uint8Array(buffer)));
const toBase64Url = (bytes: Uint8Array | string) =>
  btoa(typeof bytes === "string" ? unescape(encodeURIComponent(bytes)) : String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

export interface Chain {
  /// Base64 DER of the root - what TEST_TRUST_ROOT is set to.
  root: string;
  /// Leaf, intermediate, root - the `x5c` header.
  x5c: [string, string, string];
  leafKey: CryptoKey;
}

export interface ChainOptions {
  leafNotBefore?: Date;
  leafNotAfter?: Date;
  /// Leave Apple's marker extension off one certificate, as on one Apple
  /// issued for something other than receipts. Separate switches, because
  /// each marker is its own check and a test that drops both proves neither.
  withoutLeafMarker?: boolean;
  withoutIntermediateMarker?: boolean;
  intermediateIsCa?: boolean;
  /// Sign the leaf with a key that is not the intermediate's.
  brokenLink?: boolean;
}

const generate = (algorithm: typeof P384 | typeof P256) =>
  crypto.subtle.generateKey(algorithm, true, ["sign", "verify"]) as Promise<CryptoKeyPair>;

export async function makeChain(options: ChainOptions = {}): Promise<Chain> {
  const now = Date.now();
  const rootKeys = await generate(P384);
  const intermediateKeys = await generate(P384);
  const leafKeys = await generate(P256);

  const root = await x509.X509CertificateGenerator.createSelfSigned({
    name: "CN=Test Root CA - G3",
    notBefore: new Date(now - 3650 * DAY),
    notAfter: new Date(now + 3650 * DAY),
    signingAlgorithm: P384,
    keys: rootKeys,
    extensions: [new x509.BasicConstraintsExtension(true, undefined, true)],
  });

  const intermediate = await x509.X509CertificateGenerator.create({
    subject: "CN=Test Worldwide Developer Relations",
    issuer: root.subject,
    notBefore: new Date(now - 3400 * DAY),
    notAfter: new Date(now + 3400 * DAY),
    signingAlgorithm: P384,
    publicKey: intermediateKeys.publicKey,
    signingKey: rootKeys.privateKey,
    extensions: [
      new x509.BasicConstraintsExtension(options.intermediateIsCa ?? true, 0, true),
      ...(options.withoutIntermediateMarker
        ? []
        : [new x509.Extension(OID_APPLE_WWDR_INTERMEDIATE, false, NULL_DER)]),
    ],
  });

  const leafSigner = options.brokenLink ? (await generate(P384)).privateKey : intermediateKeys.privateKey;
  const leaf = await x509.X509CertificateGenerator.create({
    subject: "CN=Test Prod ECC Mac App Store and iTunes Store Receipt Signing",
    issuer: intermediate.subject,
    notBefore: options.leafNotBefore ?? new Date(now - 3000 * DAY),
    notAfter: options.leafNotAfter ?? new Date(now + 3000 * DAY),
    signingAlgorithm: P384,
    publicKey: leafKeys.publicKey,
    signingKey: leafSigner,
    extensions: options.withoutLeafMarker
      ? []
      : [new x509.Extension(OID_APPLE_RECEIPT_SIGNING, false, NULL_DER)],
  });

  return {
    root: toBase64(root.rawData),
    x5c: [toBase64(leaf.rawData), toBase64(intermediate.rawData), toBase64(root.rawData)],
    leafKey: leafKeys.privateKey,
  };
}

let nextTransaction = 2_000_000_000_000_000;
/// A fresh subscriber. Each test that cares about a counter uses its own, so
/// no test can pass or fail because of what another one spent.
export const freshTransactionId = () => String(nextTransaction++);

export function payload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  const now = Date.now();
  return {
    transactionId: "2000000999999999",
    originalTransactionId: freshTransactionId(),
    bundleId: BUNDLE_ID,
    productId: "pt.team.haru.pro.monthly",
    type: "Auto-Renewable Subscription",
    environment: "Production",
    purchaseDate: now - 2 * DAY,
    expiresDate: now + 28 * DAY,
    signedDate: now - 3_600_000,
    ...overrides,
  };
}

export async function sign(
  chain: Chain,
  body: Record<string, unknown>,
  header: Record<string, unknown> = {},
): Promise<string> {
  const head = toBase64Url(JSON.stringify({ alg: "ES256", x5c: chain.x5c, ...header }));
  const claims = toBase64Url(JSON.stringify(body));
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    chain.leafKey,
    new TextEncoder().encode(`${head}.${claims}`),
  );
  return `${head}.${claims}.${toBase64Url(new Uint8Array(signature))}`;
}

// ---------------------------------------------------------------------------
// A stand-in for Anthropic. No test ever reaches the real API.

export interface ModelCall {
  url: string;
  headers: Headers;
  body: Record<string, unknown>;
}

export interface FakeModel {
  fetch: typeof fetch;
  calls: ModelCall[];
}

type Responder = (call: ModelCall, index: number) => Response;

export function envelope(text: string, stopReason = "end_turn"): Response {
  return Response.json({
    id: "msg_test",
    type: "message",
    role: "assistant",
    model: MODEL,
    content: [{ type: "text", text }],
    stop_reason: stopReason,
    stop_sequence: null,
    usage: { input_tokens: 400, output_tokens: 250 },
  });
}

export const CHECKED = {
  verdict: "checked",
  corrected: "저는 학교에 가요.",
  notes: [{ span: "학교를", issue: "particle", explanation: "Dùng 에 cho nơi đến, không dùng 를." }],
};

export function fakeModel(respond: Responder | Record<string, unknown> = CHECKED): FakeModel {
  const calls: ModelCall[] = [];
  const responder: Responder =
    typeof respond === "function" ? respond : () => envelope(JSON.stringify(respond));
  return {
    calls,
    fetch: (async (input: RequestInfo | URL, init?: RequestInit) => {
      const request = new Request(input, init);
      const call: ModelCall = {
        url: request.url,
        headers: request.headers,
        body: (await request.json()) as Record<string, unknown>,
      };
      calls.push(call);
      return responder(call, calls.length - 1);
    }) as typeof fetch,
  };
}

// ---------------------------------------------------------------------------

export function testEnv(chain: Chain, overrides: Partial<Env> = {}): Env {
  return {
    ANTHROPIC_API_KEY: "test-key-never-sent",
    QUOTA: (bindings as unknown as Env).QUOTA,
    ENVIRONMENT: "test",
    GLOBAL_DAILY_CAP: "100000",
    SANDBOX_DAILY_CAP: "50",
    TEST_TRUST_ROOT: chain.root,
    ...overrides,
  };
}

export interface PostOptions {
  env: Env;
  model: FakeModel;
  now?: Date;
  quota?: Deps["quota"];
  headers?: Record<string, string>;
}

export function post(body: unknown, options: PostOptions): Promise<Response> {
  const request = new Request("https://haru-check.example/check", {
    method: "POST",
    headers: { "content-type": "application/json", ...options.headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
  return handle(request, options.env, {
    fetch: options.model.fetch,
    now: () => options.now ?? new Date(),
    quota: options.quota,
  });
}

/// Everything the Worker wrote to the console while `run` was in flight.
export async function captureLogs(run: () => Promise<unknown>): Promise<string> {
  const lines: string[] = [];
  const spies = (["log", "info", "warn", "error", "debug"] as const).map((level) =>
    vi.spyOn(console, level).mockImplementation((...args: unknown[]) => {
      lines.push(args.map((a) => (typeof a === "string" ? a : JSON.stringify(a))).join(" "));
    }),
  );
  try {
    await run();
  } finally {
    for (const spy of spies) spy.mockRestore();
  }
  return lines.join("\n");
}
