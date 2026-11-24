import { IMAGE_SIZES, MAX_IMAGE_BYTES } from "./config";

/// Why the upload was turned away, before any money was spent on it.
export class InputError extends Error {
  constructor(
    readonly status: 400 | 413 | 422,
    readonly reason: string,
  ) {
    super(reason);
  }
}

export interface Photo {
  /// The JPEG exactly as received, base64, for the model call.
  base64: string;
  width: number;
  height: number;
}

/// The upload, checked, or an `InputError`.
///
/// The app sends what PhotoPrep.swift draws: a 768×1024 or 1024×768 baseline
/// JPEG with no metadata. Anything else did not come from the app, and is
/// refused here for free rather than sent to the model for money.
///
/// EXIF is refused, not stripped: the app never sends it, so its presence
/// means a client that might also be sending a child's GPS position, and the
/// Worker does not want to hold that even for a moment (docs/privacy.md).
export function checkPhoto(raw: unknown): Photo {
  if (typeof raw !== "string" || raw.length === 0) throw new InputError(400, "image");
  // Bound the work before decoding anything.
  if (raw.length > Math.ceil((MAX_IMAGE_BYTES * 4) / 3) + 4) throw new InputError(413, "image-size");
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(raw)) throw new InputError(400, "image-base64");

  let bytes: Uint8Array;
  try {
    const binary = atob(raw);
    bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  } catch {
    throw new InputError(400, "image-base64");
  }
  if (bytes.length > MAX_IMAGE_BYTES) throw new InputError(413, "image-size");

  const { width, height } = readJpeg(bytes);
  if (!IMAGE_SIZES.some(([w, h]) => w === width && h === height)) {
    throw new InputError(422, "image-dimensions");
  }
  return { base64: raw, width, height };
}

/// Walks the JPEG markers up to the frame header. Reads dimensions and
/// refuses metadata segments; it does not decode pixels.
function readJpeg(bytes: Uint8Array): { width: number; height: number } {
  const fail = (reason: string): never => {
    throw new InputError(422, reason);
  };
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) fail("image-format");

  let i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] !== 0xff) fail("image-format");
    const marker = bytes[i + 1]!;
    // Fill bytes before a marker are allowed.
    if (marker === 0xff) {
      i += 1;
      continue;
    }
    // Standalone markers carry no length.
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      i += 2;
      continue;
    }
    if (marker === 0xd9 || marker === 0xda) break; // end, or scan data before any frame
    const length = (bytes[i + 2]! << 8) | bytes[i + 3]!;
    if (length < 2 || i + 2 + length > bytes.length) fail("image-format");

    // APP1 is EXIF and XMP; APP13 is IPTC. Either can hold location, names
    // and capture dates. ICC profiles (APP2) and JFIF (APP0) are harmless.
    if (marker === 0xe1 || marker === 0xed) fail("image-metadata");

    // Start of frame: baseline, extended, progressive. Not the DHT/JPG/DAC
    // markers that share the range.
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      if (length < 7) fail("image-format");
      const height = (bytes[i + 5]! << 8) | bytes[i + 6]!;
      const width = (bytes[i + 7]! << 8) | bytes[i + 8]!;
      return { width, height };
    }
    i += 2 + length;
  }
  return fail("image-format");
}

/// A style key from the allow-list, or the default. An unknown key is not an
/// error: an app may ship a style before the Worker learns of it.
export function pickStyle(raw: unknown, styles: Readonly<Record<string, string>>, fallback: string): string {
  return typeof raw === "string" && Object.hasOwn(styles, raw) ? raw : fallback;
}
