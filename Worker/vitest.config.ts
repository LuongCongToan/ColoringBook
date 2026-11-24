import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.toml" },
      miniflare: {
        bindings: {
          ENVIRONMENT: "test",
          // Not a key. Every test injects its own fetch, so nothing here is
          // ever sent anywhere - and a test asserts this value never appears
          // in a response.
          BFL_API_KEY: "test-key-never-sent",
        },
      },
    }),
  ],
  test: {
    include: ["test/**/*.test.ts"],
  },
});
