/// Everything the server fixes and the client cannot influence (SCOPE.md 5B.0, I3).

/// Must match PRODUCT_BUNDLE_IDENTIFIER in ColoringBook.xcodeproj and the
/// product ids in ColoringBook/Products.storekit (docs/app-store-products.md).
export const BUNDLE_ID = "pt.team.coloringbook";
export const PRO_MONTHLY = "pt.team.coloringbook.pro.monthly";
export const PRO_YEARLY = "pt.team.coloringbook.pro.yearly";
export const BOOK = "pt.team.coloringbook.book.single";
/// Three books in one purchase: one counter of three books' pages.
export const BOOK_PACK = "pt.team.coloringbook.book.pack3";
export const SUBSCRIPTIONS: ReadonlySet<string> = new Set([PRO_MONTHLY, PRO_YEARLY]);
export const BOOKS: ReadonlySet<string> = new Set([BOOK, BOOK_PACK]);
export const PRODUCT_IDS: ReadonlySet<string> = new Set([...SUBSCRIPTIONS, ...BOOKS]);

/// Pages per period, docs/app-store-products.md "Hạn mức và ngân sách".
/// The app shows the number the Worker returns; this is the one that counts.
export const LIMITS = {
  /// Calendar month (UTC), the person who bought the plan.
  monthly: 60,
  /// Calendar month (UTC), each Family Sharing member. Every member has their
  /// own originalTransactionId, so a family cannot share one counter.
  family: 20,
  /// The whole 3-day free trial.
  trial: 10,
  /// One "One Coloring Book" purchase: 20 pages and 10 redraws.
  book: 30,
  /// One "Three Coloring Books" purchase: three books' worth, one counter.
  bookPack: 90,
  /// Any plan, per UTC day: a script cannot burn a month in an hour.
  daily: 20,
} as const;

/// The model R&D used: FLUX 3 Image Klein, $0.008 a page at the 768sq tier.
/// Not FLUX.2 [klein] 4B/9B, which is another model billed per megapixel
/// (about $0.017 a page) and never tested with these prompts.
export const MODEL_ENDPOINT = "https://api.bfl.ai/v1/flux-3-image-klein";
/// Output size tier. With aspect_ratio "auto" the page keeps the photo's
/// 3:4 or 4:3 shape at about 0.6 MP (e.g. 656×875), which stays in the
/// cheapest tier. Asking for 768×1024 exactly would bill the 1k tier.
export const OUTPUT_RESOLUTION = "768sq";
/// Denoising steps, 1..16. 16 is the API default and what R&D used; set
/// explicitly so a change of default upstream does not change the pages.
export const STEPS = 16;
/// Only hosts BFL answers from. A polling or download URL anywhere else is
/// refused, so a strange upstream reply cannot point the Worker at an
/// arbitrary address.
export const UPSTREAM_HOST_SUFFIX = ".bfl.ai";
/// BFL's moderation, 0 strictest .. 7. The default; photos of children.
export const SAFETY_TOLERANCE = 2;
/// Poll every second, give up after 40 s. The app waits 60 s. At most about
/// 42 subrequests (submit, polls, download), under the Workers Free limit of 50.
export const POLL_INTERVAL_MS = 1_000;
export const POLL_TIMEOUT_MS = 40_000;
/// A generated page at about 0.6 MP as PNG is a few hundred KB.
export const MAX_RESULT_BYTES = 4 * 1024 * 1024;

/// What PhotoPrep.swift produces: 768×1024 or 1024×768 JPEG, no metadata,
/// 85–210 KB in tests. Anything else is not from the app.
export const IMAGE_SIZES: readonly (readonly [number, number])[] = [
  [768, 1024],
  [1024, 768],
];
export const MAX_IMAGE_BYTES = 300 * 1024;
/// Image as base64 (×4/3) plus a 5–7 KB JWS plus a little JSON.
export const MAX_BODY_BYTES = 450 * 1024;

/// A second identical request inside this window is taken to be a retry of
/// one whose answer was lost, and is not charged again - once.
export const REPLAY_WINDOW_MS = 120_000;

/// Prompts are configuration with a version number (CLAUDE.md). When a prompt
/// changes, bump PROMPT_VERSION and record the test results in docs/brief.md.
/// The client sends a style key; nothing it writes reaches the prompt.
export const PROMPT_VERSION = "2026-11-24.1";
export const PROMPTS: Readonly<Record<string, string>> = {
  // docs/brief.md 4.0, "Prompt cuối cùng" (Cartoon, chế độ Đơn giản).
  cartoon: `Uncolored coloring book page, clean outline line art only, like a printed kids'
coloring book. Every area is empty white inside its outline - including hair,
eyebrows and clothes. Hair is just an outline with a few thin strand lines.
Pupils are small solid black dots.

Redraw this photo in a cute, friendly cartoon style. Keep the same people and animals,
their poses, hairstyles or fur markings, glasses shapes and clothing shapes.
Keep each person's age, gender and ethnicity. Keep each facial expression from the
photo, including smiles with teeth; a closed mouth is a short line curving slightly upward.
Keep each animal's own coat pattern as large outlined patches (for example calico or
spotted patches), drawn as closed shapes to color - not generic stripes.

Simple features, nose as one small curved line without nostrils. Smooth, even black
outlines on a white page. Plain white background without furniture or walls.
Add a simple ground line or cushion under animals that are lying or sitting.
Plain clothes: no logos, text or printed pictures, and no fabric patterns.
Finish outlines neatly where the photo edge cuts a body.`,
  // docs/brief.md 4.0, "Prompt Chibi – đã chọn".
  chibi: `Uncolored coloring book page, clean outline line art only, like a printed kids'
coloring book. Every area is empty white inside its outline - including hair,
eyebrows and clothes. Hair is just an outline with a few thin strand lines.

Redraw this photo in a cute chibi style: very large round head, small body about two
heads tall, big round eyes with solid black pupils, tiny simple hands and feet.
Keep the same people and animals in the same left-to-right order, with their hairstyles
or fur markings, glasses shapes, clothing shapes and facial expressions, so each one is
recognizable. Keep each person's age, gender and ethnicity. Simplify poses to fit the
chibi proportions; arms around shoulders stay simple.

Simple features, nose as one small curved line without nostrils, mouth as in the photo.
Smooth, even black outlines on a white page. Plain white background without furniture
or walls. Plain clothes: no logos, text or printed pictures, and no fabric patterns.
Phone screens are blank. Finish outlines neatly where the photo edge cuts a body.`,
};
export const DEFAULT_STYLE = "cartoon";

/// Apple Root CA - G3, DER, base64. Downloaded from
/// https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
/// A test pins the fingerprint below, so an edit to this string cannot go
/// unnoticed.
export const APPLE_ROOT_CA_G3 =
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==";
/// SHA-256 of the DER above, as Apple publishes it:
/// 63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79
export const APPLE_ROOT_CA_G3_SHA256 =
  "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";
