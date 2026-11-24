import { env as bindings } from "cloudflare:workers";
import { beforeAll, describe, expect, it } from "vitest";
import { DAILY_CHECKS, MAX_TOKENS, MODEL } from "../src/config";
import { SYSTEM_PROMPT } from "../src/checker";
import type { Env } from "../src/env";
import worker from "../src/index";
import { CHECKED, type Chain, fakeModel, makeChain, payload, post, sign, testEnv } from "./fixtures";

// The path a paying learner takes. The other file is the one that earns its
// keep; this one says what "working" means so that file has something to
// protect.

let chain: Chain;
beforeAll(async () => {
  chain = await makeChain();
});

const request = (jws: string, extra: Record<string, unknown> = {}) => ({
  jws,
  word: "학교",
  sentence: "저는 학교를 가요.",
  lang: "vi",
  ...extra,
});

describe("a subscriber checks a sentence", () => {
  it("returns the correction, the notes and what is left today", async () => {
    const model = fakeModel();
    const response = await post(request(await sign(chain, payload())), { env: testEnv(chain), model });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      corrected: CHECKED.corrected,
      notes: CHECKED.notes,
      remaining: DAILY_CHECKS - 1,
    });
    expect(model.calls).toHaveLength(1);
  });

  it("answers in the shape SentenceFeedback decodes in the app", async () => {
    const model = fakeModel();
    const response = await post(request(await sign(chain, payload())), { env: testEnv(chain), model });
    const body = (await response.json()) as Record<string, unknown>;

    // Shared/AI/SentenceCheckClient.swift decodes exactly these three keys.
    expect(Object.keys(body).sort()).toEqual(["corrected", "notes", "remaining"]);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("returns no notes for a sentence that was already right", async () => {
    const model = fakeModel({ verdict: "checked", corrected: "저는 학교에 가요.", notes: [] });
    const response = await post(request(await sign(chain, payload()), { sentence: "저는 학교에 가요." }), {
      env: testEnv(chain),
      model,
    });

    expect(response.status).toBe(200);
    expect(((await response.json()) as { notes: unknown[] }).notes).toEqual([]);
  });

  it("counts down as the day's checks are used", async () => {
    const jws = await sign(chain, payload());
    const env = testEnv(chain);
    const seen: number[] = [];
    for (const sentence of ["저는 학교에 가요.", "학교가 커요.", "학교에서 공부해요."]) {
      const response = await post(request(jws, { sentence }), { env, model: fakeModel() });
      seen.push(((await response.json()) as { remaining: number }).remaining);
    }
    expect(seen).toEqual([DAILY_CHECKS - 1, DAILY_CHECKS - 2, DAILY_CHECKS - 3]);
  });

  it("accepts the yearly product as well as the monthly one", async () => {
    const jws = await sign(chain, payload({ productId: "pt.team.haru.pro.yearly" }));
    const response = await post(request(jws), { env: testEnv(chain), model: fakeModel() });
    expect(response.status).toBe(200);
  });

  it("serves a sandbox purchase when the sandbox allowance is open", async () => {
    // App Review and TestFlight both buy in the sandbox.
    const jws = await sign(chain, payload({ environment: "Sandbox" }));
    const response = await post(request(jws), {
      env: testEnv(chain, { SANDBOX_DAILY_CAP: "50" }),
      model: fakeModel(),
    });
    expect(response.status).toBe(200);
  });
});

describe("what is sent to the model", () => {
  it("uses the fixed model, cap and system prompt", async () => {
    const model = fakeModel();
    await post(request(await sign(chain, payload())), { env: testEnv(chain), model });
    const sent = model.calls[0]!.body;

    expect(model.calls[0]!.url).toBe("https://api.anthropic.com/v1/messages");
    expect(sent.model).toBe(MODEL);
    expect(sent.max_tokens).toBe(MAX_TOKENS);
    expect(sent.system).toBe(SYSTEM_PROMPT);
    expect(sent.output_config).toMatchObject({ effort: "low", format: { type: "json_schema" } });
    // Sampling parameters are rejected by this model family; none may be sent.
    expect(sent).not.toHaveProperty("temperature");
    expect(sent).not.toHaveProperty("top_p");
  });

  it("passes the sentence as data, with the language named by the server", async () => {
    const model = fakeModel();
    await post(request(await sign(chain, payload())), { env: testEnv(chain), model });
    const messages = model.calls[0]!.body.messages as { role: string; content: string }[];

    expect(messages).toHaveLength(1);
    expect(messages[0]!.role).toBe("user");
    expect(JSON.parse(messages[0]!.content)).toEqual({
      target_word: "학교",
      explain_in: "Vietnamese",
      sentence: "저는 학교를 가요.",
    });
  });
});

describe("the deployed entry point", () => {
  const env = bindings as unknown as Env;

  it("serves POST /check and nothing else", async () => {
    for (const [method, path] of [
      ["GET", "/check"],
      ["GET", "/"],
      ["POST", "/"],
      ["POST", "/check/"],
      ["PUT", "/check"],
      ["DELETE", "/check"],
      ["OPTIONS", "/check"],
    ] as const) {
      const response = await worker.fetch(new Request(`https://haru-check.example${path}`, { method }), env);
      expect(response.status, `${method} ${path}`).toBe(404);
    }
  });

  it("turns away a request with no transaction", async () => {
    const response = await worker.fetch(
      new Request("https://haru-check.example/check", {
        method: "POST",
        body: JSON.stringify({ word: "학교", sentence: "저는 학교에 가요.", lang: "vi" }),
      }),
      env,
    );
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
  });
});
