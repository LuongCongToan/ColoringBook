import { FALLBACK_LANGUAGE, LANGUAGES, MAX_SENTENCE } from "./config";

/// Why the input was turned away, before any money was spent on it.
export class InputError extends Error {
  constructor(
    readonly status: 400 | 422,
    readonly reason: string,
  ) {
    super(reason);
  }
}

/// Characters that take up no space on screen: zero-width spaces and joiners,
/// bidirectional controls, variation selectors, tag characters, the Hangul
/// fillers, C0/C1 controls. None of them belongs in a learner's sentence, and
/// all of them are ways to hide text from a human while showing it to a model
/// (SCOPE.md 5B.3).
const INVISIBLE =
  /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F­͏؜ᅟᅠ឴឵᠋-᠏​-‏‪-‮⁠-⁯ㅤ︀-️﻿ﾠ￹-￻\u{E0000}-\u{E007F}\u{E0100}-\u{E01EF}]/gu;

const HANGUL = /[가-힣]/gu;
const LETTER = /\p{L}/gu;

/// Makes the text one thing rather than several things that look alike.
///
/// NFKC folds full-width and other compatibility forms onto their ordinary
/// counterparts, so a rule written against ASCII or Hangul sees what a reader
/// sees. Line breaks become spaces: the sentence is quoted inside a prompt,
/// and a newline is how quoted text pretends to be a new section.
export function normalise(text: string): string {
  return text.normalize("NFKC").replace(INVISIBLE, "").replace(/\s+/gu, " ").trim();
}

/// The learner's sentence, cleaned, or an `InputError`.
///
/// The Hangul rule is a cost control as much as a guard. A sentence that is
/// mostly another script is not Korean writing practice, whatever else it is,
/// and it is refused here for free rather than sent to the model to be
/// refused there for money. It also happens to stop the commonest injection
/// shape - a Korean word followed by a paragraph of English instructions.
export function cleanSentence(raw: unknown): string {
  if (typeof raw !== "string") throw new InputError(400, "sentence");
  // Bound the work before doing any: normalising megabytes is itself a cost.
  if (raw.length > MAX_SENTENCE * 8) throw new InputError(422, "too-long");

  const sentence = normalise(raw);
  if (sentence.length === 0) throw new InputError(400, "empty");
  if ([...sentence].length > MAX_SENTENCE) throw new InputError(422, "too-long");

  const letters = sentence.match(LETTER)?.length ?? 0;
  const hangul = sentence.match(HANGUL)?.length ?? 0;
  if (hangul === 0 || hangul * 2 < letters) throw new InputError(422, "not-korean");
  return sentence;
}

/// The word the sentence is supposed to use.
///
/// Only the first run of Hangul survives. Deck entries carry homograph
/// numbers and separators (`가격02`, `-하다`), and a client could send
/// anything at all in this field - so nothing but Hangul reaches the prompt.
export function cleanWord(raw: unknown): string {
  if (typeof raw !== "string" || raw.length > 64) throw new InputError(400, "word");
  const match = normalise(raw).match(/[가-힣]{1,20}/u);
  if (!match) throw new InputError(400, "word");
  return match[0];
}

/// A code from the allow-list, or English. An unknown code is not an error:
/// the app may ship a language before this table learns of it, and the learner
/// should still get an answer.
export function pickLanguage(raw: unknown): string {
  return typeof raw === "string" && Object.hasOwn(LANGUAGES, raw) ? raw : FALLBACK_LANGUAGE;
}
