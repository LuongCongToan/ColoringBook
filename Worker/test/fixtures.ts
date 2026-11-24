// tsyringe, inside @peculiar/x509, refuses to load without this polyfill.
import "reflect-metadata";
import * as x509 from "@peculiar/x509";
import { env as bindings } from "cloudflare:workers";
import { vi } from "vitest";
import { BUNDLE_ID, PRO_MONTHLY } from "../src/config";
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
  const id = freshTransactionId();
  return {
    transactionId: id,
    originalTransactionId: id,
    bundleId: BUNDLE_ID,
    productId: PRO_MONTHLY,
    type: "Auto-Renewable Subscription",
    inAppOwnershipType: "PURCHASED",
    environment: "Production",
    purchaseDate: now - 2 * DAY,
    expiresDate: now + 28 * DAY,
    signedDate: now - 3_600_000,
    ...overrides,
  };
}

/// A "One Coloring Book" purchase.
export function bookPayload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  const base = payload({ productId: "pt.team.coloringbook.book.single", type: "Consumable" });
  delete base.expiresDate;
  return { ...base, ...overrides };
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
// Photos. Only the marker structure matters: the Worker reads headers and
// never decodes pixels, and the fake model never looks at them.

export interface JpegOptions {
  width?: number;
  height?: number;
  /// Add an APP1 "Exif" segment, as a camera file has.
  exif?: boolean;
  /// Pad the scan data to make the file this many bytes.
  size?: number;
  /// Bytes of a marker that the Worker should treat as harmless.
  extraSegments?: number[][];
}

export function jpeg(options: JpegOptions = {}): Uint8Array {
  const width = options.width ?? 768;
  const height = options.height ?? 1024;
  const segment = (marker: number, data: number[]) => [0xff, marker, (data.length + 2) >> 8, (data.length + 2) & 0xff, ...data];
  const parts: number[] = [0xff, 0xd8];
  parts.push(...segment(0xe0, [0x4a, 0x46, 0x49, 0x46, 0x00, 1, 1, 0, 0, 1, 0, 1, 0, 0]));
  if (options.exif) parts.push(...segment(0xe1, [0x45, 0x78, 0x69, 0x66, 0, 0, 0x4d, 0x4d, 0, 0x2a]));
  for (const extra of options.extraSegments ?? []) parts.push(...extra);
  parts.push(...segment(0xc0, [8, height >> 8, height & 0xff, width >> 8, width & 0xff, 1, 1, 0x11, 0]));
  parts.push(...segment(0xda, [1, 1, 0, 0, 0x3f, 0]));
  const bytes = new Uint8Array(Math.max(parts.length + 2, options.size ?? 0));
  bytes.set(parts);
  bytes.set([0xff, 0xd9], bytes.length - 2);
  return bytes;
}

export const toBase64Bytes = (bytes: Uint8Array) => {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
};

export const photo = (options: JpegOptions = {}) => toBase64Bytes(jpeg(options));

// ---------------------------------------------------------------------------
// A stand-in for BFL. No test ever reaches the real API.

export const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52]);
export const POLLING_URL = "https://api.bfl.ai/v1/get_result?id=task-1";
export const SAMPLE_URL = "https://delivery-us1.bfl.ai/results/task-1/sample.png";

export interface ModelCall {
  url: string;
  method: string;
  headers: Headers;
  /// The JSON body of the submit call; undefined for polls and downloads.
  body?: Record<string, unknown>;
}

export interface FakeModel {
  fetch: typeof fetch;
  calls: ModelCall[];
  /// Only the submit calls: the ones that cost money.
  submits: () => ModelCall[];
}

export interface Script {
  submit?: (call: ModelCall, index: number) => Response;
  /// One answer per poll, in order; the last one repeats.
  polls?: (() => Response)[];
  download?: () => Response;
}

export const ready = () => Response.json({ id: "task-1", status: "Ready", result: { sample: SAMPLE_URL } });
export const pending = () => Response.json({ id: "task-1", status: "Pending" });

export function fakeModel(script: Script = {}): FakeModel {
  const calls: ModelCall[] = [];
  let polls = 0;
  let submits = 0;
  return {
    calls,
    submits: () => calls.filter((c) => c.body !== undefined),
    fetch: (async (input: RequestInfo | URL, init?: RequestInit) => {
      const request = new Request(input, init);
      const call: ModelCall = { url: request.url, method: request.method, headers: request.headers };
      if (request.method === "POST") call.body = (await request.json()) as Record<string, unknown>;
      calls.push(call);
      if (request.method === "POST") {
        const respond =
          script.submit ?? (() => Response.json({ id: "task-1", polling_url: POLLING_URL, cost: 1, input_mp: 0.79 }));
        return respond(call, submits++);
      }
      if (request.url.startsWith(SAMPLE_URL) || request.url.includes("/results/")) {
        return script.download ? script.download() : new Response(PNG, { headers: { "content-type": "image/png" } });
      }
      const answers = script.polls ?? [ready];
      const answer = answers[Math.min(polls++, answers.length - 1)]!;
      return answer();
    }) as typeof fetch,
  };
}

// ---------------------------------------------------------------------------

export function testEnv(chain: Chain, overrides: Partial<Env> = {}): Env {
  return {
    BFL_API_KEY: "test-key-never-sent",
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
  /// A clock that moves, for timeouts.
  clock?: () => Date;
  quota?: Deps["quota"];
  headers?: Record<string, string>;
}

export function post(body: unknown, options: PostOptions): Promise<Response> {
  const request = new Request("https://coloring-api.example/generate", {
    method: "POST",
    headers: { "content-type": "application/json", ...options.headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
  return handle(request, options.env, {
    fetch: options.model.fetch,
    now: options.clock ?? (() => options.now ?? new Date()),
    sleep: async () => {},
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
