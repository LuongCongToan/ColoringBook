import type { Env } from "./env";
import { handle } from "./handler";

export { QuotaCounter } from "./quota";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handle(request, env, {
        fetch: (input, init) => fetch(input, init),
        now: () => new Date(),
      });
    } catch {
      // Whatever went wrong, the caller learns nothing about it. A stack
      // trace in a response is documentation for an attacker.
      console.log(JSON.stringify({ event: "generate", status: 500, reason: "internal" }));
      return new Response(JSON.stringify({ error: "unavailable" }), {
        status: 500,
        headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
      });
    }
  },
} satisfies ExportedHandler<Env>;
