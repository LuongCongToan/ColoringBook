/// Everything the server fixes and the client cannot influence (SCOPE.md 5B.0, I3).

/// Must match PRODUCT_BUNDLE_IDENTIFIER and ProductID in Shared/Store/ProAccess.swift.
/// Tools/check_identifiers.py keeps the two sides in step.
export const BUNDLE_ID = "pt.team.haru";
export const PRODUCT_IDS: ReadonlySet<string> = new Set([
  "pt.team.haru.pro.monthly",
  "pt.team.haru.pro.yearly",
]);

/// ProAccess.dailyChecks in the app shows the same number; this one enforces it.
export const DAILY_CHECKS = 20;

export const MODEL = "claude-haiku-5-5";
/// Thinking counts toward this cap, so it is sized for a short think plus the
/// ~250-token answer rather than for the answer alone.
export const MAX_TOKENS = 2048;

/// Same as SentenceCheckClient.maxSentenceLength. The client's check is
/// politeness; this one is the limit.
export const MAX_SENTENCE = 280;
/// A StoreKit JWS runs 5-7 KB with its certificate chain. Anything far beyond
/// that is not a request this endpoint serves, and is refused before it is read.
export const MAX_BODY_BYTES = 32 * 1024;

/// A second identical request inside this window is taken to be a retry of
/// one whose answer was lost, and is not charged again - once.
export const REPLAY_WINDOW_MS = 120_000;

/// The eleven languages of ContentLanguage.swift. The client sends a code and
/// the server looks the name up here; nothing the client writes reaches the
/// prompt as an instruction (SCOPE.md 5B.3).
export const LANGUAGES: Readonly<Record<string, string>> = {
  en: "English",
  ja: "Japanese",
  zh: "Simplified Chinese",
  vi: "Vietnamese",
  th: "Thai",
  id: "Indonesian",
  ru: "Russian",
  mn: "Mongolian",
  es: "Spanish",
  fr: "French",
  ar: "Arabic",
};
export const FALLBACK_LANGUAGE = "en";

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
