import { DurableObject } from "cloudflare:workers";
import { REPLAY_WINDOW_MS } from "./config";

export interface Reservation {
  /// False when the day's allowance is spent.
  ok: boolean;
  /// Pages counted against the current period, after this call.
  used: number;
  /// False for a refused request and for a free retry.
  charged: boolean;
}

interface State {
  /// The period this count belongs to: a UTC day, a month, or a fixed label
  /// ("book", "trial") for allowances that never reset.
  day: string;
  used: number;
  /// Hash of the last charged request, so its retry can be recognised. A hash
  /// only - the photo itself is never stored (docs/privacy.md).
  lastKey?: string;
  lastAt?: number;
  lastReplayed?: boolean;
}

/// One counter per allowance (a subscriber's month, a trial, a book, a
/// person's day), plus one for the whole service and one for the sandbox,
/// each addressed by name.
///
/// A Durable Object rather than Workers KV, and that is the point of the
/// class. KV is eventually consistent: read-then-write lets twenty parallel
/// requests all read 19 and all write 20. A Durable Object runs one event at a
/// time and holds further events while a storage operation is in flight, so
/// the read and the write in `reserve` cannot be interleaved with another
/// request's (SCOPE.md 5B.2).
export class QuotaCounter extends DurableObject {
  private async load(day: string): Promise<State> {
    const state = await this.ctx.storage.get<State>("state");
    // A new period is a new allowance; the old record is simply replaced.
    return state && state.day === day ? state : { day, used: 0 };
  }

  /// Takes one page from the period's allowance if there is one.
  ///
  /// `replayKey` identifies the request. Seeing the same key again inside the
  /// replay window means the client is retrying a call whose answer never
  /// arrived, and it goes through without a second charge - once, so that
  /// resending one photo forever is not a way round the limit.
  async reserve(day: string, limit: number, nowMs: number, replayKey?: string): Promise<Reservation> {
    const state = await this.load(day);

    if (
      replayKey !== undefined &&
      state.lastKey === replayKey &&
      state.lastReplayed !== true &&
      state.lastAt !== undefined &&
      nowMs - state.lastAt < REPLAY_WINDOW_MS
    ) {
      state.lastReplayed = true;
      await this.ctx.storage.put("state", state);
      return { ok: true, used: state.used, charged: false };
    }

    if (state.used >= limit) return { ok: false, used: state.used, charged: false };

    state.used += 1;
    state.lastKey = replayKey;
    state.lastAt = nowMs;
    state.lastReplayed = false;
    await this.ctx.storage.put("state", state);
    return { ok: true, used: state.used, charged: true };
  }

  /// Pages counted against the period so far, without taking one (POST
  /// /quota: what the app shows before a page is made).
  async peek(day: string): Promise<number> {
    return (await this.load(day)).used;
  }

  /// Gives a page back when the model call failed. Charging for an answer
  /// that never came is the quickest route to a one-star review.
  async refund(day: string): Promise<void> {
    const state = await this.load(day);
    if (state.used === 0) return;
    state.used -= 1;
    // The retry of a refunded call is a fresh call, charged normally.
    state.lastKey = undefined;
    await this.ctx.storage.put("state", state);
  }
}
