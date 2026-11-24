import { env as bindings } from "cloudflare:workers";
import { beforeAll, describe, expect, it } from "vitest";
import { LIMITS, MODEL_ENDPOINT, PROMPTS, PROMPT_VERSION, PRO_YEARLY, SAFETY_TOLERANCE } from "../src/config";
import type { Env } from "../src/env";
import worker from "../src/index";
import {
  PNG,
  type Chain,
  bookPayload,
  fakeModel,
  makeChain,
  payload,
  photo,
  post,
  sign,
  testEnv,
  toBase64Bytes,
} from "./fixtures";

// The path a paying parent takes. adversarial.test.ts is the file that earns
// its keep; this one says what "working" means so that file has something to
// protect.

let chain: Chain;
beforeAll(async () => {
  chain = await makeChain();
});

const request = (jws: string, extra: Record<string, unknown> = {}) => ({
  jws,
  image: photo(),
  style: "cartoon",
  ...extra,
});

const remainingOf = async (response: Response) => ((await response.json()) as { remaining: number }).remaining;

describe("a subscriber makes a coloring page", () => {
  it("returns the page, what is left this month, and the prompt version", async () => {
    const model = fakeModel();
    const response = await post(request(await sign(chain, payload())), { env: testEnv(chain), model });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      image: toBase64Bytes(PNG),
      remaining: LIMITS.monthly - 1,
      style: "cartoon",
      promptVersion: PROMPT_VERSION,
    });
    expect(model.submits()).toHaveLength(1);
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("counts down as the month's pages are used", async () => {
    const jws = await sign(chain, payload());
    const env = testEnv(chain);
    const seen: number[] = [];
    for (let i = 0; i < 3; i++) {
      // A different photo each time, so none is taken for a retry.
      const response = await post(request(jws, { image: photo({ size: 600 + i }) }), { env, model: fakeModel() });
      seen.push(await remainingOf(response));
    }
    expect(seen).toEqual([LIMITS.monthly - 1, LIMITS.monthly - 2, LIMITS.monthly - 3]);
  });

  it("accepts the yearly plan as well as the monthly one", async () => {
    const response = await post(request(await sign(chain, payload({ productId: PRO_YEARLY }))), {
      env: testEnv(chain),
      model: fakeModel(),
    });
    expect(response.status).toBe(200);
  });

  it("accepts a landscape photo", async () => {
    const response = await post(request(await sign(chain, payload()), { image: photo({ width: 1024, height: 768 }) }), {
      env: testEnv(chain),
      model: fakeModel(),
    });
    expect(response.status).toBe(200);
  });

  it("gives a free trial its own ten pages", async () => {
    const response = await post(request(await sign(chain, payload({ productId: PRO_YEARLY, offerType: 1 }))), {
      env: testEnv(chain),
      model: fakeModel(),
    });
    expect(await remainingOf(response)).toBe(LIMITS.trial - 1);
  });

  it("gives a Family Sharing member the family allowance", async () => {
    const response = await post(request(await sign(chain, payload({ inAppOwnershipType: "FAMILY_SHARED" }))), {
      env: testEnv(chain),
      model: fakeModel(),
    });
    expect(await remainingOf(response)).toBe(LIMITS.family - 1);
  });

  it("serves a sandbox purchase when the sandbox allowance is open", async () => {
    // App Review and TestFlight both buy in the sandbox.
    const response = await post(request(await sign(chain, payload({ environment: "Sandbox" }))), {
      env: testEnv(chain, { SANDBOX_DAILY_CAP: "50" }),
      model: fakeModel(),
    });
    expect(response.status).toBe(200);
  });
});

describe("a parent who bought One Coloring Book", () => {
  it("draws on that book's thirty pages", async () => {
    const response = await post(request(await sign(chain, bookPayload())), { env: testEnv(chain), model: fakeModel() });
    expect(response.status).toBe(200);
    expect(await remainingOf(response)).toBe(LIMITS.book - 1);
  });

  it("keeps two books apart", async () => {
    const env = testEnv(chain);
    const first = await sign(chain, bookPayload());
    await post(request(first), { env, model: fakeModel() });
    await post(request(first, { image: photo({ size: 700 }) }), { env, model: fakeModel() });

    const second = await post(request(await sign(chain, bookPayload())), { env, model: fakeModel() });
    expect(await remainingOf(second)).toBe(LIMITS.book - 1);
  });
});

describe("what is sent to the model", () => {
  it("uses the fixed endpoint, prompt, size, format and moderation level", async () => {
    const model = fakeModel();
    const image = photo();
    await post(request(await sign(chain, payload()), { image }), { env: testEnv(chain), model });
    const submit = model.submits()[0]!;

    expect(submit.url).toBe(MODEL_ENDPOINT);
    expect(submit.headers.get("x-key")).toBe("test-key-never-sent");
    expect(submit.body).toEqual({
      prompt: PROMPTS.cartoon,
      input_image: image,
      width: 768,
      height: 1024,
      output_format: "png",
      safety_tolerance: SAFETY_TOLERANCE,
    });
  });

  it("picks the chibi prompt by key", async () => {
    const model = fakeModel();
    const response = await post(request(await sign(chain, payload()), { style: "chibi" }), { env: testEnv(chain), model });
    expect(model.submits()[0]!.body!.prompt).toBe(PROMPTS.chibi);
    expect(((await response.json()) as { style: string }).style).toBe("chibi");
  });

  it("falls back to cartoon for a style it does not know", async () => {
    for (const style of ["watercolor", "", 3, null, "__proto__", "constructor"]) {
      const model = fakeModel();
      await post(request(await sign(chain, payload()), { style }), { env: testEnv(chain), model });
      expect(model.submits()[0]!.body!.prompt, String(style)).toBe(PROMPTS.cartoon);
    }
  });

  it("polls, then downloads the sample with no key attached", async () => {
    const model = fakeModel();
    await post(request(await sign(chain, payload())), { env: testEnv(chain), model });
    const [submit, poll, download] = model.calls;
    expect(submit!.method).toBe("POST");
    expect(poll!.headers.get("x-key")).toBe("test-key-never-sent");
    // The signed delivery URL needs no key, and should not be handed one.
    expect(download!.headers.get("x-key")).toBeNull();
  });
});

describe("the deployed entry point", () => {
  const env = bindings as unknown as Env;

  it("serves POST /generate and nothing else", async () => {
    for (const [method, path] of [
      ["GET", "/generate"],
      ["GET", "/"],
      ["POST", "/"],
      ["POST", "/check"],
      ["POST", "/generate/"],
      ["PUT", "/generate"],
      ["DELETE", "/generate"],
      ["OPTIONS", "/generate"],
    ] as const) {
      const response = await worker.fetch(new Request(`https://coloring-api.example${path}`, { method }), env);
      expect(response.status, `${method} ${path}`).toBe(404);
    }
  });

  it("turns away a request with no transaction", async () => {
    const response = await worker.fetch(
      new Request("https://coloring-api.example/generate", {
        method: "POST",
        body: JSON.stringify({ image: photo(), style: "cartoon" }),
      }),
      env,
    );
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
  });
});
