import {
  MAX_RESULT_BYTES,
  MODEL_ENDPOINT,
  POLL_INTERVAL_MS,
  POLL_TIMEOUT_MS,
  SAFETY_TOLERANCE,
  UPSTREAM_HOST_SUFFIX,
} from "./config";
import type { Photo } from "./image";

/// The provider looked at the request and declined to draw it. Charged,
/// unlike an outage: it was a real call, and making refusals free would make
/// probing free.
export class Moderated extends Error {}
/// The call failed, timed out or came back unusable. Not charged. The message
/// is a short code of this module's own, never upstream text: an upstream
/// error body can echo the request.
export class UpstreamError extends Error {}

export interface GenerateDeps {
  fetch: typeof fetch;
  /// Injected so tests do not wait out real polling intervals.
  sleep: (ms: number) => Promise<void>;
  now: () => number;
}

export interface Page {
  /// PNG bytes as the model returned them.
  png: Uint8Array;
}

function upstreamUrl(value: unknown): URL {
  if (typeof value !== "string") throw new UpstreamError("unusable");
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new UpstreamError("unusable");
  }
  if (url.protocol !== "https:" || !url.hostname.endsWith(UPSTREAM_HOST_SUFFIX)) {
    throw new UpstreamError("unusable");
  }
  return url;
}

async function readCapped(response: Response, limit: number): Promise<Uint8Array> {
  const declared = Number(response.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > limit) throw new UpstreamError("unusable");
  if (!response.body) throw new UpstreamError("unusable");
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > limit) {
      await reader.cancel();
      throw new UpstreamError("unusable");
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return out;
}

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/// Draws one coloring page from a prepared photo.
///
/// The endpoint, prompt, size, format and moderation level are all fixed
/// here or passed from config; the request body chooses none of them
/// (SCOPE.md 5B.0, I3). The photo is held in memory for the length of this
/// call and nowhere else (docs/privacy.md).
export async function generatePage(
  photo: Photo,
  prompt: string,
  apiKey: string,
  deps: GenerateDeps,
): Promise<Page> {
  const headers = { "x-key": apiKey, accept: "application/json", "content-type": "application/json" };

  let submitted: Response;
  try {
    submitted = await deps.fetch(MODEL_ENDPOINT, {
      method: "POST",
      headers,
      body: JSON.stringify({
        prompt,
        input_image: photo.base64,
        // Always set: once the API answered 656×875 for a 768×1024 photo,
        // and a page above ~4 MP is billed at the 4K rate (brief 4.0).
        width: photo.width,
        height: photo.height,
        // JPEG adds grey noise around the lines and throws the quality check.
        output_format: "png",
        safety_tolerance: SAFETY_TOLERANCE,
      }),
    });
  } catch {
    throw new UpstreamError("upstream network");
  }
  if (submitted.status === 422) throw new Moderated(); // includes refused moderation levels
  if (!submitted.ok) throw new UpstreamError(`upstream ${submitted.status}`);

  let pollingUrl: URL;
  try {
    const task = (await submitted.json()) as { polling_url?: unknown };
    pollingUrl = upstreamUrl(task.polling_url);
  } catch (error) {
    if (error instanceof UpstreamError) throw error;
    throw new UpstreamError("unusable");
  }

  const deadline = deps.now() + POLL_TIMEOUT_MS;
  for (;;) {
    if (deps.now() > deadline) throw new UpstreamError("timeout");
    await deps.sleep(POLL_INTERVAL_MS);

    let poll: { status?: unknown; result?: { sample?: unknown } };
    try {
      const response = await deps.fetch(pollingUrl, { headers: { "x-key": apiKey, accept: "application/json" } });
      if (!response.ok) throw new UpstreamError(`poll ${response.status}`);
      poll = (await response.json()) as typeof poll;
    } catch (error) {
      if (error instanceof UpstreamError) throw error;
      throw new UpstreamError("poll network");
    }

    const status = typeof poll.status === "string" ? poll.status : "";
    if (status === "Ready") {
      const sampleUrl = upstreamUrl(poll.result?.sample);
      let download: Response;
      try {
        download = await deps.fetch(sampleUrl);
      } catch {
        throw new UpstreamError("download network");
      }
      if (!download.ok) throw new UpstreamError(`download ${download.status}`);
      const png = await readCapped(download, MAX_RESULT_BYTES);
      if (png.length < 8 || PNG_SIGNATURE.some((b, i) => png[i] !== b)) throw new UpstreamError("unusable");
      return { png };
    }
    if (/moderated/i.test(status)) throw new Moderated();
    if (status === "Error" || status === "Failed" || status === "Task not found") {
      throw new UpstreamError("failed");
    }
    // Pending, Queued, Processing...: keep waiting.
  }
}
