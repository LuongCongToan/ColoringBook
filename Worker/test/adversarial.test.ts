import { beforeAll, describe, expect, it } from "vitest";
import {
  APPLE_ROOT_CA_G3,
  APPLE_ROOT_CA_G3_SHA256,
  LIMITS,
  MAX_BODY_BYTES,
  MAX_IMAGE_BYTES,
  MODEL_ENDPOINT,
  PROMPTS,
} from "../src/config";
import type { QuotaPort } from "../src/handler";
import { base64ToBytes } from "../src/jws";
import {
  type Chain,
  type FakeModel,
  type Script,
  PNG,
  bookPayload,
  captureLogs,
  fakeModel,
  freshTransactionId,
  jpeg,
  makeChain,
  payload,
  pending,
  photo,
  post,
  ready,
  sign,
  testEnv,
  toBase64Bytes,
} from "./fixtures";

// docs/worker-security.md (SCOPE.md 5B of Haru), one test per line of it.
// This endpoint is the only public thing in the project that spends real
// money, so every way of being wrong here arrives as an invoice rather than
// as a bug report.
//
// The recurring assertion is that nothing was submitted to the model: a
// refusal that still reached BFL has already cost what it was meant to save
// (5B.0, I1).

let apple: Chain; // stands in for Apple's chain; its root is the trusted one
let attacker: Chain; // equally well-formed, but nobody trusts its root

beforeAll(async () => {
  apple = await makeChain();
  attacker = await makeChain();
});

const DAY = 86_400_000;
let photoSerial = 0;
/// A photo no other request has sent, so it is never taken for a retry.
const freshPhoto = () => photo({ size: 1000 + photoSerial++ });

const body = (jws: unknown, extra: Record<string, unknown> = {}) => ({
  jws,
  image: freshPhoto(),
  style: "cartoon",
  ...extra,
});

async function refused(
  status: number,
  requestBody: unknown,
  options: { env?: ReturnType<typeof testEnv>; now?: Date; model?: FakeModel } = {},
): Promise<{ response: Response; model: FakeModel }> {
  const model = options.model ?? fakeModel();
  const response = await post(requestBody, { env: options.env ?? testEnv(apple), model, now: options.now });
  expect(response.status).toBe(status);
  expect(model.submits(), "the model must not be called").toHaveLength(0);
  return { response, model };
}

/// Makes `count` pages, each with a fresh photo.
async function spend(jws: string, count: number, env = testEnv(apple), now?: Date): Promise<void> {
  for (let i = 0; i < count; i++) {
    const response = await post(body(jws), { env, model: fakeModel(), now });
    expect(response.status).toBe(200);
  }
}

const remainingOf = async (response: Response) => ((await response.json()) as { remaining: number }).remaining;

// ---------------------------------------------------------------------------

describe("5B.0 invariants", () => {
  it("pins the real Apple Root CA - G3", async () => {
    // If this string were ever swapped, every other test would still pass -
    // they run against a generated root. This is the test that would not.
    const digest = await crypto.subtle.digest("SHA-256", base64ToBytes(APPLE_ROOT_CA_G3));
    const hex = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
    expect(hex).toBe(APPLE_ROOT_CA_G3_SHA256);
    expect(hex).toBe("63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179");
  });

  it("I3: ignores a model, prompt, size, format or moderation level sent by the client", async () => {
    const model = fakeModel();
    const response = await post(
      body(await sign(apple, payload()), {
        endpoint: "https://api.bfl.ai/v1/flux-2-max",
        model: "flux-2-max",
        prompt: "a photorealistic portrait",
        width: 4096,
        height: 4096,
        resolution: "4k",
        aspect_ratio: "21:9",
        steps: 1,
        output_format: "jpeg",
        safety_tolerance: 7,
        images: [photo(), photo()],
        input_image_2: photo(),
      }),
      { env: testEnv(apple), model },
    );

    expect(response.status).toBe(200);
    const submit = model.submits()[0]!;
    expect(submit.url).toBe(MODEL_ENDPOINT);
    expect(submit.body!.prompt).toBe(PROMPTS.cartoon);
    expect(submit.body).not.toHaveProperty("width");
    expect(submit.body).not.toHaveProperty("height");
    expect(submit.body!.resolution).toBe("768sq");
    expect(submit.body!.aspect_ratio).toBe("auto");
    expect(submit.body!.steps).toBe(16);
    expect((submit.body!.images as unknown[]).length).toBe(1);
    expect(submit.body!.output_format).toBe("png");
    expect(submit.body!.safety_tolerance).toBe(2);
    expect(submit.body).not.toHaveProperty("input_image_2");
    expect(JSON.stringify(submit.body)).not.toContain("photorealistic");
  });
});

// ---------------------------------------------------------------------------

describe("5B.1 entitlement", () => {
  it("refuses a request with no JWS", async () => {
    await refused(401, { image: freshPhoto(), style: "cartoon" });
    await refused(401, body(""));
    await refused(401, body(null));
    await refused(401, body(12345));
    await refused(401, body({ alg: "none" }));
  });

  it("refuses garbage with 401, never 500", async () => {
    const real = await sign(apple, payload());
    const [head, claims, signature] = real.split(".") as [string, string, string];
    const junk = [
      "garbage",
      "a.b",
      "a.b.c",
      "a.b.c.d",
      "..",
      "!!!.???.###",
      `${head}.${claims}`,
      `${head}.${claims}.`,
      `${head}..${signature}`,
      `.${claims}.${signature}`,
      `${btoa("not json")}.${claims}.${signature}`,
      `${btoa("[1,2,3]")}.${claims}.${signature}`,
      `${btoa('{"alg":"ES256"}')}.${claims}.${signature}`,
      `${btoa('{"alg":"ES256","x5c":"nope"}')}.${claims}.${signature}`,
      `${btoa('{"alg":"ES256","x5c":["AAAA","AAAA","AAAA"]}')}.${claims}.${signature}`,
      `${head}.${btoa("not json")}.${signature}`,
      "x".repeat(20_000),
    ];
    for (const jws of junk) {
      const { response } = await refused(401, body(jws));
      expect(await response.json()).toEqual({ error: "unauthorized" });
    }
  });

  it('refuses `alg: "none"` and every algorithm that is not ES256', async () => {
    for (const alg of ["none", "None", "NONE", "HS256", "RS256", "ES384", "PS256", ""]) {
      const jws = await sign(apple, payload(), { alg });
      await refused(401, body(jws));
      const [head, claims] = jws.split(".") as [string, string];
      await refused(401, body(`${head}.${claims}.`));
    }
  });

  it("refuses a valid signature from a self-made certificate chain", async () => {
    // The main attack: a chain as internally consistent as the trusted one,
    // with a payload that says everything the Worker wants to hear.
    await refused(401, body(await sign(attacker, payload())));
  });

  it("refuses a self-made chain that claims Apple's root as its own", async () => {
    const grafted: Chain = { ...attacker, x5c: [attacker.x5c[0], attacker.x5c[1], apple.x5c[2]] };
    await refused(401, body(await sign(grafted, payload())));
    const deeper: Chain = { ...attacker, x5c: [attacker.x5c[0], apple.x5c[1], apple.x5c[2]] };
    await refused(401, body(await sign(deeper, payload())));
  });

  it("ignores a stray TEST_TRUST_ROOT outside the test environment", async () => {
    const jws = await sign(apple, payload());
    for (const ENVIRONMENT of ["production", "staging"] as const) {
      await refused(401, body(jws), { env: testEnv(apple, { ENVIRONMENT }) });
    }
  });

  it("refuses a chain whose links do not sign each other", async () => {
    await refused(401, body(await sign(await makeChain({ brokenLink: true }), payload())));
  });

  it("refuses a chain with an expired link, unless it was valid when Apple signed", async () => {
    const lapsed = await makeChain({
      leafNotBefore: new Date(Date.now() - 400 * DAY),
      leafNotAfter: new Date(Date.now() - 30 * DAY),
    });
    const env = testEnv(lapsed);
    await refused(401, body(await sign(lapsed, payload())), { env });

    const then = await sign(lapsed, payload({ signedDate: Date.now() - 60 * DAY }));
    const response = await post(body(then), { env, model: fakeModel() });
    expect(response.status).toBe(200);
  });

  it("refuses a transaction dated in the future", async () => {
    await refused(401, body(await sign(apple, payload({ signedDate: Date.now() + 3_600_000 }))));
  });

  it("refuses certificates without Apple's receipt-signing markers", async () => {
    for (const options of [{ withoutLeafMarker: true }, { withoutIntermediateMarker: true }]) {
      const plain = await makeChain(options);
      await refused(401, body(await sign(plain, payload())), { env: testEnv(plain) });
    }
  });

  it("refuses an intermediate that is not a certificate authority", async () => {
    const flat = await makeChain({ intermediateIsCa: false });
    await refused(401, body(await sign(flat, payload())), { env: testEnv(flat) });
  });

  it("refuses a payload edited after signing", async () => {
    const jws = await sign(apple, payload({ expiresDate: Date.now() - 1000 }));
    const [head, , signature] = jws.split(".") as [string, string, string];
    const forged = btoa(JSON.stringify(payload())).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    await refused(401, body(`${head}.${forged}.${signature}`));
  });

  it("refuses a transaction with no usable ids", async () => {
    await refused(401, body(await sign(apple, payload({ transactionId: undefined }))));
    await refused(401, body(await sign(apple, payload({ originalTransactionId: "../../etc" }))));
  });

  it("refuses a genuine transaction that belongs to another app", async () => {
    // Buy anything for 99 cents in any app and present that receipt here.
    for (const bundleId of ["com.example.other", "pt.team.haru", "pt.team.ColoringBook", undefined]) {
      await refused(403, body(await sign(apple, payload({ bundleId }))));
    }
  });

  it("refuses a product that is not one of ours", async () => {
    for (const productId of [
      "pt.team.haru.pro.monthly",
      "pt.team.coloringbook.tip",
      "pt.team.coloringbook.pro.monthly.x",
      "",
      undefined,
    ]) {
      await refused(403, body(await sign(apple, payload({ productId }))));
    }
  });

  it("refuses a product id signed with the wrong type", async () => {
    // A subscription id on a consumable record would dodge the expiry check.
    await refused(403, body(await sign(apple, payload({ type: "Consumable", expiresDate: undefined }))));
    await refused(403, body(await sign(apple, bookPayload({ type: "Auto-Renewable Subscription" }))));
    await refused(403, body(await sign(apple, bookPayload({ type: "Non-Consumable" }))));
  });

  it("refuses an expired subscription", async () => {
    await refused(403, body(await sign(apple, payload({ expiresDate: Date.now() - 1000 }))));
    await refused(403, body(await sign(apple, payload({ expiresDate: undefined }))));
    await refused(403, body(await sign(apple, payload({ expiresDate: "2999-01-01" }))));
  });

  it("refuses a refunded or revoked subscription or book", async () => {
    // Without this, a refund leaves the AI switched on for good.
    await refused(403, body(await sign(apple, payload({ revocationDate: Date.now() - DAY, revocationReason: 0 }))));
    await refused(403, body(await sign(apple, payload({ revocationDate: 0 }))));
    await refused(403, body(await sign(apple, bookPayload({ revocationDate: Date.now() - DAY }))));
  });

  it("refuses sandbox transactions when the sandbox allowance is closed", async () => {
    const env = testEnv(apple, { SANDBOX_DAILY_CAP: "0" });
    await refused(403, body(await sign(apple, payload({ environment: "Sandbox" }))), { env });
  });

  it("refuses environments that are neither production nor sandbox", async () => {
    for (const environment of ["Xcode", "LocalTesting", "production", "", undefined]) {
      await refused(403, body(await sign(apple, payload({ environment }))));
    }
  });

  it("judges expiry by the server's clock, not one the client supplies", async () => {
    const jws = await sign(apple, payload({ expiresDate: Date.now() - 60_000 }));
    const past = Date.now() - DAY;
    await refused(403, body(jws, { now: past, timestamp: past, date: new Date(past).toISOString() }));

    const model = fakeModel();
    const response = await post(body(jws), {
      env: testEnv(apple),
      model,
      headers: { date: new Date(past).toUTCString(), "x-timestamp": String(past) },
    });
    expect(response.status).toBe(403);
    expect(model.submits()).toHaveLength(0);
  });

  it("shares one allowance across fifty addresses presenting one transaction", async () => {
    const jws = await sign(apple, payload());
    const env = testEnv(apple);
    let served = 0;
    for (let i = 0; i < 50; i++) {
      const response = await post(body(jws), {
        env,
        model: fakeModel(),
        headers: { "cf-connecting-ip": `203.0.113.${i}`, "x-forwarded-for": `198.51.100.${i}` },
      });
      if (response.status === 200) served++;
      else expect(response.status).toBe(429);
    }
    expect(served).toBe(LIMITS.daily);
  });
});

// ---------------------------------------------------------------------------

describe("5B.2 quota", () => {
  it("I2: keys the allowance on the verified transaction, ignoring ids in the body", async () => {
    const jws = await sign(apple, payload());
    const env = testEnv(apple);
    await spend(jws, LIMITS.daily, env);

    for (const extra of [
      { userId: "someone-else" },
      { deviceId: crypto.randomUUID() },
      { originalTransactionId: freshTransactionId() },
      { transactionId: "1" },
    ]) {
      await refused(429, body(jws, extra), { env });
    }
  });

  it("lets exactly one of twenty simultaneous requests take the last page of the day", async () => {
    // Read-then-write on an eventually consistent store would let all twenty
    // through. The counter is a Durable Object so that this number is exact.
    const jws = await sign(apple, payload());
    const env = testEnv(apple);
    await spend(jws, LIMITS.daily - 1, env);

    const model = fakeModel();
    const responses = await Promise.all(Array.from({ length: 20 }, () => post(body(jws), { env, model })));
    const statuses = responses.map((r) => r.status);
    expect(statuses.filter((s) => s === 200)).toHaveLength(1);
    expect(statuses.filter((s) => s === 429)).toHaveLength(19);
    expect(model.submits()).toHaveLength(1);
  });

  it("caps a month at sixty pages for the buyer, with the reset at the next month", async () => {
    const start = new Date("2030-03-10T12:00:00Z");
    const dated = { signedDate: start.getTime() - 3_600_000, expiresDate: start.getTime() + 30 * DAY };
    const jws = await sign(apple, payload(dated));
    const env = testEnv(apple);
    for (let d = 0; d < 3; d++) await spend(jws, LIMITS.daily, env, new Date(start.getTime() + d * DAY));

    const fourth = new Date(start.getTime() + 3 * DAY);
    const { response } = await refused(429, body(jws), { env, now: fourth });
    expect(await response.json()).toEqual({ error: "quota", resetAt: "2030-04-01T00:00:00.000Z" });
  });

  it("caps a Family Sharing member at twenty pages a month", async () => {
    const start = new Date("2030-05-10T12:00:00Z");
    const dated = {
      inAppOwnershipType: "FAMILY_SHARED",
      signedDate: start.getTime() - 3_600_000,
      expiresDate: start.getTime() + 30 * DAY,
    };
    const jws = await sign(apple, payload(dated));
    const env = testEnv(apple);
    await spend(jws, 10, env, start);
    await spend(jws, 10, env, new Date(start.getTime() + DAY));
    await refused(429, body(jws), { env, now: new Date(start.getTime() + 2 * DAY) });
  });

  it("caps the free trial at ten pages, with no reset date", async () => {
    const jws = await sign(apple, payload({ offerType: 1 }));
    const env = testEnv(apple);
    await spend(jws, LIMITS.trial, env);
    const { response } = await refused(429, body(jws), { env });
    expect(await response.json()).toEqual({ error: "quota" });
  });

  it("caps a book at thirty pages, across days and reinstalls", async () => {
    const start = new Date("2030-06-01T12:00:00Z");
    const transactionId = freshTransactionId();
    const env = testEnv(apple);
    const fresh = () => sign(apple, bookPayload({ transactionId, signedDate: Date.now() - 1000 }));
    await spend(await fresh(), LIMITS.daily, env, start);
    await spend(await fresh(), LIMITS.book - LIMITS.daily, env, new Date(start.getTime() + DAY));

    const { response } = await refused(429, body(await fresh()), { env, now: new Date(start.getTime() + 2 * DAY) });
    expect(await response.json()).toEqual({ error: "quota" });
  });

  it("does not count a refused daily page against the month or the book", async () => {
    const day = new Date("2030-07-01T12:00:00Z");
    const transactionId = freshTransactionId();
    const jws = await sign(apple, bookPayload({ transactionId }));
    const env = testEnv(apple);
    await spend(jws, LIMITS.daily, env, day);
    await refused(429, body(jws), { env, now: day });
    await refused(429, body(jws), { env, now: day });

    const tomorrow = await post(body(jws), { env, model: fakeModel(), now: new Date(day.getTime() + DAY) });
    expect(await remainingOf(tomorrow)).toBe(LIMITS.book - LIMITS.daily - 1);
  });

  it("resets the daily ceiling at midnight UTC on the server", async () => {
    const day = new Date("2030-06-15T23:59:30Z");
    const dated = { signedDate: day.getTime() - 3_600_000, expiresDate: day.getTime() + 20 * DAY };
    const jws = await sign(apple, payload(dated));
    const env = testEnv(apple);
    await spend(jws, LIMITS.daily, env, day);

    const { response } = await refused(429, body(jws, { timeZone: "Asia/Seoul" }), { env, now: day });
    expect(await response.json()).toEqual({ error: "quota", resetAt: "2030-06-16T00:00:00.000Z" });
    expect(response.headers.get("retry-after")).toBe("30");

    const after = await post(body(jws), { env, model: fakeModel(), now: new Date("2030-06-16T00:00:01Z") });
    expect(after.status).toBe(200);
  });

  it("keeps the count across a reinstall", async () => {
    const originalTransactionId = freshTransactionId();
    const env = testEnv(apple);
    await spend(await sign(apple, payload({ originalTransactionId })), LIMITS.daily, env);

    const reinstalled = await sign(
      apple,
      payload({ originalTransactionId, transactionId: freshTransactionId(), signedDate: Date.now() - 1000 }),
    );
    await refused(429, body(reinstalled), { env });
  });

  it("gives a different Apple ID its own allowance", async () => {
    const env = testEnv(apple);
    await spend(await sign(apple, payload()), LIMITS.daily, env);
    const other = await post(body(await sign(apple, payload())), { env, model: fakeModel() });
    expect(await remainingOf(other)).toBe(LIMITS.monthly - 1);
  });

  it("trips the global fuse without spending the user's own page", async () => {
    const day = new Date("2030-08-01T12:00:00Z");
    const dated = { signedDate: day.getTime() - 3_600_000, expiresDate: day.getTime() + 20 * DAY };
    const env = testEnv(apple, { GLOBAL_DAILY_CAP: "2" });
    for (let i = 0; i < 2; i++) {
      const ok = await post(body(await sign(apple, payload(dated))), { env, model: fakeModel(), now: day });
      expect(ok.status).toBe(200);
    }

    const unlucky = await sign(apple, payload(dated));
    const { response } = await refused(503, body(unlucky), { env, now: day });
    expect(await response.json()).toEqual({ error: "unavailable" });

    const roomy = testEnv(apple, { GLOBAL_DAILY_CAP: "1000" });
    const later = await post(body(unlucky), { env: roomy, model: fakeModel(), now: day });
    expect(await remainingOf(later)).toBe(LIMITS.monthly - 1);
  });

  it("holds every sandbox transaction to one shared allowance", async () => {
    const day = new Date("2030-09-01T12:00:00Z");
    const dated = { environment: "Sandbox", signedDate: day.getTime() - 3_600_000, expiresDate: day.getTime() + DAY };
    const env = testEnv(apple, { SANDBOX_DAILY_CAP: "3" });
    for (let i = 0; i < 3; i++) {
      const ok = await post(body(await sign(apple, payload(dated))), { env, model: fakeModel(), now: day });
      expect(ok.status).toBe(200);
    }
    await refused(429, body(await sign(apple, payload(dated))), { env, now: day });

    const paying = await sign(apple, payload({ ...dated, environment: "Production" }));
    const response = await post(body(paying), { env, model: fakeModel(), now: day });
    expect(response.status).toBe(200);
  });
});

// ---------------------------------------------------------------------------

describe("5B.3 uploads and abuse", () => {
  it("refuses photos that are not the size the app prepares", async () => {
    const jws = await sign(apple, payload());
    for (const [width, height] of [
      [1024, 1024],
      [2048, 2732],
      [768, 1023],
      [64, 64],
      [8192, 8192],
    ] as const) {
      const { response } = await refused(422, body(jws, { image: photo({ width, height }) }));
      expect(await response.json()).toEqual({ error: "rejected" });
    }
  });

  it("refuses a photo that still carries EXIF or IPTC", async () => {
    // The app never sends metadata. A file that has it may carry a child's
    // GPS position, and the Worker does not want to hold that at all.
    const jws = await sign(apple, payload());
    await refused(422, body(jws, { image: photo({ exif: true }) }));
    const iptc = [0xff, 0xed, 0x00, 0x06, 0x50, 0x68, 0x6f, 0x74];
    await refused(422, body(jws, { image: photo({ extraSegments: [iptc] }) }));
  });

  it("accepts an ICC profile segment", async () => {
    const icc = [0xff, 0xe2, 0x00, 0x06, 0x49, 0x43, 0x43, 0x5f];
    const response = await post(body(await sign(apple, payload()), { image: photo({ extraSegments: [icc] }) }), {
      env: testEnv(apple),
      model: fakeModel(),
    });
    expect(response.status).toBe(200);
  });

  it("refuses anything that is not a JPEG", async () => {
    const jws = await sign(apple, payload());
    const notJpeg = [
      toBase64Bytes(PNG),
      btoa("GIF89a......"),
      btoa("<svg xmlns='http://www.w3.org/2000/svg'/>"),
      toBase64Bytes(new Uint8Array([0xff, 0xd8, 0xff, 0xd9])),
      toBase64Bytes(jpeg().subarray(0, 30)),
    ];
    for (const image of notJpeg) await refused(422, body(jws, { image }));
  });

  it("refuses a missing or malformed image field as a bad request", async () => {
    const jws = await sign(apple, payload());
    for (const image of [undefined, null, "", 42, ["x"], { url: "https://example.com/a.jpg" }, "not base64!!", "data:image/jpeg;base64,/9j/"]) {
      await refused(400, body(jws, { image }));
    }
  });

  it("refuses a photo over the size limit before decoding it", async () => {
    const jws = await sign(apple, payload());
    await refused(413, body(jws, { image: photo({ size: MAX_IMAGE_BYTES + 1 }) }));
    const ok = await post(body(jws, { image: photo({ size: MAX_IMAGE_BYTES }) }), { env: testEnv(apple), model: fakeModel() });
    expect(ok.status).toBe(200);
  });

  it("refuses a ten-megabyte body before reading it", async () => {
    const jws = await sign(apple, payload());
    const huge = JSON.stringify(body(jws, { padding: "A".repeat(10 * 1024 * 1024) }));
    const { response } = await refused(413, huge);
    expect(await response.json()).toEqual({ error: "too_large" });

    // When Content-Length understates the body, the stream is counted anyway.
    const model = fakeModel();
    const lying = await post(huge, { env: testEnv(apple), model, headers: { "content-length": "100" } });
    expect(lying.status).toBe(413);
    expect(model.submits()).toHaveLength(0);
    expect(huge.length).toBeGreaterThan(MAX_BODY_BYTES);
  });

  it("refuses bodies that are not a JSON object", async () => {
    for (const raw of ["", "not json", "[]", "null", "42", '"string"', "{", '{"jws":']) {
      const { response } = await refused(400, raw);
      expect(await response.json()).toEqual({ error: "bad_request" });
    }
  });

  it("returns a fixed refusal when the provider moderates the request", async () => {
    const scripts: Script[] = [
      { submit: () => Response.json({ detail: [{ msg: "UPSTREAM DETAIL" }] }, { status: 422 }) },
      { polls: [() => Response.json({ status: "Request Moderated", details: "UPSTREAM DETAIL" })] },
      { polls: [pending, () => Response.json({ status: "Content Moderated", details: "UPSTREAM DETAIL" })] },
    ];
    for (const script of scripts) {
      const response = await post(body(await sign(apple, payload())), { env: testEnv(apple), model: fakeModel(script) });
      expect(response.status).toBe(422);
      const text = await response.text();
      expect(JSON.parse(text)).toEqual({ error: "rejected" });
      expect(text).not.toContain("UPSTREAM");
    }
  });

  it("charges a moderated request, so that probing is not free", async () => {
    const jws = await sign(apple, payload());
    const env = testEnv(apple);
    await post(body(jws), { env, model: fakeModel({ polls: [() => Response.json({ status: "Content Moderated" })] }) });
    const next = await post(body(jws), { env, model: fakeModel() });
    expect(await remainingOf(next)).toBe(LIMITS.monthly - 2);
  });

  it("follows polling and download links only to BFL's own hosts", async () => {
    // A strange upstream reply must not turn the Worker into a proxy.
    const elsewhere = [
      "http://api.bfl.ai/v1/get_result?id=1",
      "https://bfl.ai.evil.example/x",
      "https://evil.example/?u=api.bfl.ai",
      "https://169.254.169.254/latest/meta-data",
      "file:///etc/passwd",
      42,
    ];
    for (const target of elsewhere) {
      for (const script of [
        { submit: () => Response.json({ id: "t", polling_url: target }) },
        { polls: [() => Response.json({ status: "Ready", result: { sample: target } })] },
      ] as Script[]) {
        const model = fakeModel(script);
        const response = await post(body(await sign(apple, payload())), { env: testEnv(apple), model });
        expect(response.status, String(target)).toBe(503);
        expect(model.calls.every((c) => new URL(c.url).hostname.endsWith(".bfl.ai"))).toBe(true);
      }
    }
  });

  it("does not hand back a download that is not a PNG or is too large", async () => {
    for (const download of [
      () => new Response("<html>not an image</html>"),
      () => new Response(new Uint8Array(5 * 1024 * 1024), { headers: { "content-length": String(5 * 1024 * 1024) } }),
    ]) {
      const response = await post(body(await sign(apple, payload())), { env: testEnv(apple), model: fakeModel({ download }) });
      expect(response.status).toBe(503);
    }
  });
});

// ---------------------------------------------------------------------------

describe("5B.4 secrets and configuration", () => {
  it("never puts the API key or an upstream error body in a response", async () => {
    const leaky = () => Response.json({ detail: "UPSTREAM-INTERNAL-DETAIL x-key=test-key-never-sent" }, { status: 500 });
    const model = fakeModel({ submit: leaky });
    const response = await post(body(await sign(apple, payload())), { env: testEnv(apple), model });

    expect(response.status).toBe(503);
    const text = await response.text();
    expect(JSON.parse(text)).toEqual({ error: "unavailable" });
    expect(text).not.toContain("UPSTREAM");
    expect(text).not.toContain("test-key-never-sent");
  });

  it("sends the key only to BFL's API, in the x-key header, never to the download host", async () => {
    const model = fakeModel({ polls: [pending, ready] });
    await post(body(await sign(apple, payload())), { env: testEnv(apple), model });
    for (const call of model.calls) {
      const carriers = [...call.headers].filter(([, value]) => value.includes("test-key-never-sent"));
      if (new URL(call.url).hostname === "api.bfl.ai") {
        expect(carriers.map(([name]) => name)).toEqual(["x-key"]);
      } else {
        expect(carriers).toHaveLength(0);
      }
    }
  });

  it("sends no CORS headers on any response", async () => {
    const jws = await sign(apple, payload());
    const origin = { origin: "https://evil.example" };
    const responses = [
      await post(body(jws), { env: testEnv(apple), model: fakeModel(), headers: origin }),
      await post(body("garbage"), { env: testEnv(apple), model: fakeModel(), headers: origin }),
      await post("not json", { env: testEnv(apple), model: fakeModel(), headers: origin }),
    ];
    for (const response of responses) {
      for (const [name] of response.headers) expect(name.toLowerCase()).not.toMatch(/^access-control-/);
    }
  });
});

// ---------------------------------------------------------------------------

describe("5B.5 operational failures", () => {
  it("does not charge for a page that never arrived", async () => {
    const jws = await sign(apple, payload());
    const env = testEnv(apple);
    const failures: Script[] = [
      { submit: () => new Response("{}", { status: 500 }) },
      { submit: () => new Response("{}", { status: 429 }) },
      { submit: () => new Response("{}", { status: 402 }) }, // out of credits
      { submit: () => new Response("{not json", { status: 200 }) },
      {
        submit: () => {
          throw new TypeError("network down");
        },
      },
      { polls: [() => Response.json({ status: "Error" })] },
      { polls: [() => Response.json({ status: "Failed" })] },
      { polls: [() => Response.json({ status: "Task not found" })] },
      { polls: [() => Response.json({ status: "No Card Generated" })] },
      { polls: [() => new Response("forbidden", { status: 403 })] },
      { polls: [() => Response.json({ status: "Ready", result: {} })] },
      { download: () => new Response("gone", { status: 404 }) },
    ];
    for (const [i, script] of failures.entries()) {
      const response = await post(body(jws), { env, model: fakeModel(script) });
      expect(response.status, `failure ${i}`).toBe(503);
      expect(await response.json()).toEqual({ error: "unavailable" });
    }

    const after = await post(body(jws), { env, model: fakeModel() });
    expect(await remainingOf(after)).toBe(LIMITS.monthly - 1);
  });

  it("gives up on a page that never finishes, and does not charge for it", async () => {
    let t = Date.parse("2030-10-01T12:00:00Z");
    const dated = { signedDate: t - 3_600_000, expiresDate: t + 20 * DAY };
    const jws = await sign(apple, payload(dated));
    const env = testEnv(apple);
    const model = fakeModel({ polls: [pending] });
    const response = await post(body(jws), {
      env,
      model,
      clock: () => new Date((t += 1_000)),
    });
    expect(response.status).toBe(503);
    // Bounded: about 40 polls at one simulated second each, not forever.
    expect(model.calls.length).toBeLessThan(60);

    const after = await post(body(jws), { env, model: fakeModel(), now: new Date(t) });
    expect(await remainingOf(after)).toBe(LIMITS.monthly - 1);
  });

  it("waits out a passing polling hiccup instead of discarding a paid task", async () => {
    const jws = await sign(apple, payload());
    const env = testEnv(apple);
    const hiccups = [
      () => new Response("origin timed out", { status: 522 }),
      () => new Response("busy", { status: 429 }),
      () => {
        throw new TypeError("connection reset");
      },
    ];
    for (const hiccup of hiccups) {
      const response = await post(body(jws), { env, model: fakeModel({ polls: [pending, hiccup, pending, ready] }) });
      expect(response.status).toBe(200);
    }
  });

  it("gives up on a polling URL that keeps failing, within the deadline, and refunds", async () => {
    let t = Date.parse("2030-10-02T12:00:00Z");
    const dated = { signedDate: t - 3_600_000, expiresDate: t + 20 * DAY };
    const jws = await sign(apple, payload(dated));
    const env = testEnv(apple);
    const model = fakeModel({ polls: [() => new Response("bad gateway", { status: 502 })] });
    const response = await post(body(jws), { env, model, clock: () => new Date((t += 1_000)) });
    expect(response.status).toBe(503);
    expect(model.calls.length).toBeLessThan(60);

    const after = await post(body(jws), { env, model: fakeModel(), now: new Date(t) });
    expect(await remainingOf(after)).toBe(LIMITS.monthly - 1);
  });

  it("fails closed when the counter cannot be reached", async () => {
    const broken: QuotaPort = {
      reserve: () => Promise.reject(new Error("storage unavailable")),
      refund: () => Promise.reject(new Error("storage unavailable")),
    };
    const model = fakeModel();
    const response = await post(body(await sign(apple, payload())), { env: testEnv(apple), model, quota: broken });
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "unavailable" });
    expect(model.submits()).toHaveLength(0);
  });

  it("still answers when the refund after an outage fails too", async () => {
    let used = 0;
    const flaky: QuotaPort = {
      reserve: async () => ({ ok: true, used: ++used, charged: true }),
      refund: () => Promise.reject(new Error("storage unavailable")),
    };
    const response = await post(body(await sign(apple, payload())), {
      env: testEnv(apple),
      model: fakeModel({ submit: () => new Response("{}", { status: 500 }) }),
      quota: flaky,
    });
    expect(response.status).toBe(503);
  });

  it("does not charge twice when the app retries a photo whose page was lost", async () => {
    const jws = await sign(apple, payload());
    const env = testEnv(apple);
    const image = freshPhoto();
    const remaining = async () => remainingOf(await post(body(jws, { image }), { env, model: fakeModel() }));

    expect(await remaining()).toBe(LIMITS.monthly - 1);
    expect(await remaining()).toBe(LIMITS.monthly - 1); // the retry is on the house
    expect(await remaining()).toBe(LIMITS.monthly - 2); // once
  });

  it("charges the same photo in a different style", async () => {
    const jws = await sign(apple, payload());
    const env = testEnv(apple);
    const image = freshPhoto();
    await post(body(jws, { image, style: "cartoon" }), { env, model: fakeModel() });
    const chibi = await post(body(jws, { image, style: "chibi" }), { env, model: fakeModel() });
    expect(await remainingOf(chibi)).toBe(LIMITS.monthly - 2);
  });

  it("charges a repeat that arrives after the retry window", async () => {
    const start = new Date("2030-11-01T08:00:00Z");
    const dated = { signedDate: start.getTime() - 3_600_000, expiresDate: start.getTime() + DAY };
    const jws = await sign(apple, payload(dated));
    const env = testEnv(apple);
    const image = freshPhoto();
    await post(body(jws, { image }), { env, model: fakeModel(), now: start });
    const later = await post(body(jws, { image }), { env, model: fakeModel(), now: new Date(start.getTime() + 121_000) });
    expect(await remainingOf(later)).toBe(LIMITS.monthly - 2);
  });
});

// ---------------------------------------------------------------------------

describe("5B.6 privacy", () => {
  async function logsFor(run: (jws: string, image: string) => Promise<unknown>) {
    const id = freshTransactionId();
    const jws = await sign(apple, payload({ transactionId: id, originalTransactionId: id }));
    const image = freshPhoto();
    const logs = await captureLogs(() => run(jws, image));
    return { logs, jws, id, image };
  }

  function expectClean(logs: string, jws: string, id: string, image: string): void {
    expect(logs).not.toContain(image.slice(0, 40));
    expect(logs).not.toContain(toBase64Bytes(PNG).slice(0, 12));
    expect(logs).not.toContain(id);
    expect(logs).not.toContain(jws.split(".")[1]!);
    expect(logs).not.toContain("test-key-never-sent");
    expect(logs).not.toContain("coloring book page"); // the prompt
    expect(logs).not.toContain("UPSTREAM");
  }

  it("logs nothing about the photo or the buyer on success", async () => {
    const { logs, jws, id, image } = await logsFor(async (jws, image) => {
      const response = await post(body(jws, { image }), { env: testEnv(apple), model: fakeModel() });
      expect(response.status).toBe(200);
    });
    expectClean(logs, jws, id, image);
    // It does log that something happened - an endpoint with no logs at all
    // cannot be operated.
    expect(logs).toContain('"status":200');
  });

  it("logs nothing about the photo or the buyer when things go wrong", async () => {
    const { logs, jws, id, image } = await logsFor(async (jws, image) => {
      const env = testEnv(apple);
      const echo = () => Response.json({ detail: `UPSTREAM ${image}` }, { status: 500 });
      await post(body(jws, { image }), { env, model: fakeModel({ submit: echo }) });
      await post(body(jws, { image }), { env, model: fakeModel({ polls: [() => Response.json({ status: "Error", details: `UPSTREAM ${image}` })] }) });
      await post(body(jws, { image }), { env, model: fakeModel({ polls: [() => Response.json({ status: "Content Moderated" })] }) });
      await post(body(jws, { image: `${image}!` }), { env, model: fakeModel() });
      await post(body(`${jws}x`, { image }), { env, model: fakeModel() });
      await post(body(jws, { image }), {
        env,
        model: fakeModel(),
        quota: { reserve: () => Promise.reject(new Error(`UPSTREAM ${image}`)), refund: async () => {} },
      });
    });
    expectClean(logs, jws, id, image);
  });
});

describe("staging Simulator switch (STAGING_SKIP_SIGNATURE)", () => {
  const xcode = () => payload({ environment: "Xcode" });

  it("is ignored in production and under test: a forged chain is still refused", async () => {
    for (const ENVIRONMENT of ["production", "test"] as const) {
      const env = testEnv(apple, { ENVIRONMENT, STAGING_SKIP_SIGNATURE: "true" });
      await refused(401, body(await sign(attacker, payload())), { env });
      await refused(401, body("not-a-jws"), { env });
    }
  });

  it("does not open the Xcode environment outside staging, even with a trusted signature", async () => {
    const env = testEnv(apple, { STAGING_SKIP_SIGNATURE: "true" });
    await refused(403, body(await sign(apple, xcode())), { env });
  });

  it("is off on staging unless set to exactly \"true\"", async () => {
    for (const STAGING_SKIP_SIGNATURE of [undefined, "", "1", "TRUE", "yes"]) {
      const env = testEnv(apple, { ENVIRONMENT: "staging", STAGING_SKIP_SIGNATURE });
      await refused(401, body(await sign(attacker, xcode())), { env });
    }
  });

  it("on staging, accepts an Xcode transaction signed by any root", async () => {
    const env = testEnv(apple, { ENVIRONMENT: "staging", STAGING_SKIP_SIGNATURE: "true" });
    const model = fakeModel();
    const response = await post(body(await sign(attacker, xcode())), { env, model });
    expect(response.status).toBe(200);
    expect(model.submits()).toHaveLength(1);
  });

  it("on staging, still checks bundle, product, expiry and refunds", async () => {
    const env = testEnv(apple, { ENVIRONMENT: "staging", STAGING_SKIP_SIGNATURE: "true" });
    await refused(403, body(await sign(attacker, payload({ environment: "Xcode", bundleId: "com.other.app" }))), { env });
    await refused(403, body(await sign(attacker, payload({ environment: "Xcode", productId: "com.other.pro" }))), { env });
    await refused(403, body(await sign(attacker, payload({ environment: "Xcode", expiresDate: Date.now() - 60_000 }))), { env });
    await refused(403, body(await sign(attacker, payload({ environment: "Xcode", revocationDate: Date.now() - DAY }))), { env });
    await refused(401, body("not-a-jws"), { env });
  });

  it("on staging, the global cap still bounds the day", async () => {
    const env = testEnv(apple, {
      ENVIRONMENT: "staging",
      STAGING_SKIP_SIGNATURE: "true",
      GLOBAL_DAILY_CAP: "1",
      SANDBOX_DAILY_CAP: "100",
    });
    const now = new Date("2031-01-05T12:00:00Z"); // a day no other test counts on
    const first = await post(body(await sign(attacker, payload({ environment: "Xcode", expiresDate: now.getTime() + DAY }))), {
      env,
      model: fakeModel(),
      now,
    });
    expect(first.status).toBe(200);
    await refused(503, body(await sign(attacker, payload({ environment: "Xcode", expiresDate: now.getTime() + DAY }))), {
      env,
      now,
    });
  });
});
